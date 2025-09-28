import argparse, os, json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score, StratifiedKFold
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    roc_auc_score, brier_score_loss, classification_report, 
    RocCurveDisplay, precision_score, recall_score, f1_score,
    confusion_matrix
)
import matplotlib.pyplot as plt

def create_lendee_features():
    """
    Load 4 CSV files and create a clean dataframe with lendee features for ML model.
    Returns: DataFrame with columns [lendee_id, lendee_count, unpaid_amount, unpaid_count]
    """
    
    # Load all 4 CSV files silently
    try:
        investments = pd.read_csv("investments_200.csv")
        profiles = pd.read_csv("profiles_rows.csv")
        loan_requests = pd.read_csv("loan_req_market_200.csv")
        bank_market = pd.read_csv("bank_market_200.csv")
    except FileNotFoundError as e:
        return None
    
    # Map column names to lendee_id equivalent
    lendee_cols = {
        'investments': 'id',
        'profiles': 'id', 
        'loan_requests': 'lendee_id',
        'bank_market': 'lendee_id'
    }
    
    # Collect all unique lendee_ids from all sources
    all_lendee_ids = set()
    
    datasets = [(investments, 'investments'), (profiles, 'profiles'), 
                (loan_requests, 'loan_requests'), (bank_market, 'bank_market')]
    
    for df, name in datasets:
        if lendee_cols[name] in df.columns:
            ids = df[lendee_cols[name]].dropna().unique()
            all_lendee_ids.update(ids)
    
    # Create base dataframe
    lendee_features = pd.DataFrame({
        'lendee_id': list(all_lendee_ids)
    })
    
    # 1. Calculate lendee_count (appearances across all datasets)
    lendee_count = {}
    for lendee_id in all_lendee_ids:
        count = 0
        for df, name in datasets:
            if lendee_cols[name] in df.columns:
                count += (df[lendee_cols[name]] == lendee_id).sum()
        lendee_count[lendee_id] = count
    
    lendee_features['lendee_count'] = lendee_features['lendee_id'].map(lendee_count)
    
    # 2. Initialize metrics
    lendee_features['unpaid_amount'] = 0.0
    lendee_features['unpaid_count'] = 0
    lendee_features['total_loan_amount'] = 0.0
    
    # 3. Calculate unpaid amounts from bank_market (defaulted loans)
    if 'outcome' in bank_market.columns and 'amount' in bank_market.columns:
        unpaid_bank = bank_market[bank_market['outcome'] == 'defaulted']
        if len(unpaid_bank) > 0:
            unpaid_summary = unpaid_bank.groupby('lendee_id').agg({
                'amount': 'sum',
                'lendee_id': 'count'
            }).rename(columns={'amount': 'unpaid_amount_bank', 'lendee_id': 'unpaid_count_bank'})
            
            lendee_features = lendee_features.merge(
                unpaid_summary, left_on='lendee_id', right_index=True, how='left'
            )
            lendee_features['unpaid_amount'] += lendee_features['unpaid_amount_bank'].fillna(0)
            lendee_features['unpaid_count'] += lendee_features['unpaid_count_bank'].fillna(0)
            lendee_features = lendee_features.drop(['unpaid_amount_bank', 'unpaid_count_bank'], axis=1)
    
    # 4. Calculate unpaid amounts from investments (outcome != 'yes')
    if 'outcome' in investments.columns and 'amount' in investments.columns:
        unpaid_inv = investments[investments['outcome'] != 'yes']
        if len(unpaid_inv) > 0:
            unpaid_inv_summary = unpaid_inv.groupby('id').agg({
                'amount': 'sum',
                'id': 'count'
            }).rename(columns={'amount': 'unpaid_amount_inv', 'id': 'unpaid_count_inv'})
            
            lendee_features = lendee_features.merge(
                unpaid_inv_summary, left_on='lendee_id', right_index=True, how='left'
            )
            lendee_features['unpaid_amount'] += lendee_features['unpaid_amount_inv'].fillna(0)
            lendee_features['unpaid_count'] += lendee_features['unpaid_count_inv'].fillna(0)
            lendee_features = lendee_features.drop(['unpaid_amount_inv', 'unpaid_count_inv'], axis=1)
    
    # 5. Calculate total loan amounts from all datasets (for avg_loan_per_lendee)
    # From bank_market - all loans (paid and unpaid)
    if 'amount' in bank_market.columns:
        total_bank_amounts = bank_market.groupby('lendee_id')['amount'].sum()
        lendee_features = lendee_features.merge(
            total_bank_amounts.rename('total_bank_amount'), 
            left_on='lendee_id', right_index=True, how='left'
        )
        lendee_features['total_loan_amount'] += lendee_features['total_bank_amount'].fillna(0)
        lendee_features = lendee_features.drop(['total_bank_amount'], axis=1)
    
    # From investments - all investment amounts
    if 'amount' in investments.columns:
        total_inv_amounts = investments.groupby('id')['amount'].sum()
        lendee_features = lendee_features.merge(
            total_inv_amounts.rename('total_inv_amount'), 
            left_on='lendee_id', right_index=True, how='left'
        )
        lendee_features['total_loan_amount'] += lendee_features['total_inv_amount'].fillna(0)
        lendee_features = lendee_features.drop(['total_inv_amount'], axis=1)
    
    # From loan_requests - requested amounts
    if 'amount' in loan_requests.columns:
        total_req_amounts = loan_requests.groupby('lendee_id')['amount'].sum()
        lendee_features = lendee_features.merge(
            total_req_amounts.rename('total_req_amount'), 
            left_on='lendee_id', right_index=True, how='left'
        )
        lendee_features['total_loan_amount'] += lendee_features['total_req_amount'].fillna(0)
        lendee_features = lendee_features.drop(['total_req_amount'], axis=1)
    
    # Clean up data types and fill NaN values
    lendee_features['unpaid_amount'] = lendee_features['unpaid_amount'].fillna(0)
    lendee_features['unpaid_count'] = lendee_features['unpaid_count'].fillna(0).astype(int)
    lendee_features['total_loan_amount'] = lendee_features['total_loan_amount'].fillna(0)
    
    # Add binary defaulted column (target variable for ML)
    lendee_features['defaulted'] = (lendee_features['unpaid_count'] > 0).astype(int)
    
    # Add derived features
    lendee_features['unpaid_rate'] = np.where(lendee_features['lendee_count'] > 0, 
                                            lendee_features['unpaid_count'] / lendee_features['lendee_count'], 0)
    lendee_features['avg_unpaid_amount_per'] = np.where(lendee_features['unpaid_count'] > 0,
                                                      lendee_features['unpaid_amount'] / lendee_features['unpaid_count'], 0)
    lendee_features['avg_loan_per_lendee'] = np.where(lendee_features['lendee_count'] > 0,
                                                     lendee_features['total_loan_amount'] / lendee_features['lendee_count'], 0)
    
    # Save to CSV for future use
    lendee_features.to_csv("lendee_features.csv", index=False)
    
    return lendee_features

def main():
    """
    Main function to process CSV files and create lendee features
    """
    # Process the CSV files and return clean dataframe
    lendee_data = create_lendee_features()
    
    if lendee_data is not None:
        print(f" Created dataset with {len(lendee_data)} lendees and 4 features")
        print(f" Shape: {lendee_data.shape}")
        return lendee_data
    else:
        print(" Failed to process CSV files")
        return None

if __name__ == "__main__":
    # When run directly, create and return the dataset
    data = main()
    if data is not None:
        print("\nDataset ready for ML model:")
        print(data.head(20))


def nash_score(lendee_count, total_loan_amount, avg_loan_per_lendee, defaulted,
               max_lendee_count=100, max_total_loan_amount=1_000_000, max_avg_loan=50_000):
    # normalize
    norm_lendee_count = min(lendee_count / max_lendee_count, 1)
    norm_total_loan_amount = min(total_loan_amount / max_total_loan_amount, 1)
    norm_avg_loan_per_lendee = min(avg_loan_per_lendee / max_avg_loan, 1)
    
    # weights
    w_defaulted = 0.5
    w_lendee = 0.2
    w_total = 0.15
    w_avg = 0.15
    
    # formula
    score = (w_defaulted * (1 - defaulted) +
             w_lendee * norm_lendee_count +
             w_total * norm_total_loan_amount +
             w_avg * norm_avg_loan_per_lendee) * 100
    
    return round(score, 2)


def run_pipeline(items=None):
    """
    Run the full pipeline and return a mapping {lendee_id: nash_score}.

    - If `items` is provided, it should be an iterable of dict-like objects with
      keys: 'lendee_id', 'lendee_count', 'total_loan_amount', 'avg_loan_per_lendee', 'defaulted'
      Any missing numeric field will be coerced to 0.
    - If `items` is None, this will call `create_lendee_features()` to load CSVs
      and compute features for all lendees found there.

    Returns: dict mapping str(lendee_id) -> float(score)
    """
    results = {}

    if items is None:
        df = create_lendee_features()
        if df is None:
            raise FileNotFoundError("CSV files for creating lendee features were not found")

        # iterate dataframe rows
        for _, row in df.iterrows():
            try:
                lid = row.get('lendee_id') if hasattr(row, 'get') else row['lendee_id']
            except Exception:
                lid = row['lendee_id']

            lendee_count = float(row.get('lendee_count', 0) if hasattr(row, 'get') else row['lendee_count'])
            total_loan_amount = float(row.get('total_loan_amount', 0) if hasattr(row, 'get') else row['total_loan_amount'])
            avg_loan_per_lendee = float(row.get('avg_loan_per_lendee', 0) if hasattr(row, 'get') else row['avg_loan_per_lendee'])
            defaulted = int(row.get('defaulted', 0) if hasattr(row, 'get') else row['defaulted'])

            score = nash_score(lendee_count, total_loan_amount, avg_loan_per_lendee, defaulted)
            results[str(lid)] = score

        return results

    # items provided: expect iterable of dicts
    for it in items:
        # support dataclass/row or dict-like
        try:
            lid = it.get('lendee_id') if hasattr(it, 'get') else it['lendee_id']
            lendee_count = float(it.get('lendee_count', 0) if hasattr(it, 'get') else it.get('lendee_count', 0))
            total_loan_amount = float(it.get('total_loan_amount', 0) if hasattr(it, 'get') else it.get('total_loan_amount', 0))
            avg_loan_per_lendee = float(it.get('avg_loan_per_lendee', 0) if hasattr(it, 'get') else it.get('avg_loan_per_lendee', 0))
            defaulted = int(it.get('defaulted', 0) if hasattr(it, 'get') else it.get('defaulted', 0))
        except Exception:
            # try attribute access
            lid = getattr(it, 'lendee_id', None)
            lendee_count = float(getattr(it, 'lendee_count', 0) or 0)
            total_loan_amount = float(getattr(it, 'total_loan_amount', 0) or 0)
            avg_loan_per_lendee = float(getattr(it, 'avg_loan_per_lendee', 0) or 0)
            defaulted = int(getattr(it, 'defaulted', 0) or 0)

        score = nash_score(lendee_count, total_loan_amount, avg_loan_per_lendee, defaulted)
        results[str(lid)] = score

    return results


def run_pipeline_for_uuids(uuids):
    """
    Compute nash scores for a specific list of lendee_ids (uuids).

    uuids: iterable of ids (strings or ints)
    Returns: dict mapping str(id) -> float(score)
    """
    if uuids is None:
        raise ValueError("uuids must be provided")

    df = create_lendee_features()
    if df is None:
        raise FileNotFoundError("CSV files for creating lendee features were not found")

    # Normalize ids to string for matching
    wanted = set([str(u) for u in uuids])

    # Ensure lendee_id present as string for comparison
    df['__lid_str'] = df['lendee_id'].astype(str)
    subset = df[df['__lid_str'].isin(wanted)]

    results = {}
    for _, row in subset.iterrows():
        lid = str(row['lendee_id'])
        lendee_count = float(row.get('lendee_count', 0) if hasattr(row, 'get') else row['lendee_count'])
        total_loan_amount = float(row.get('total_loan_amount', 0) if hasattr(row, 'get') else row['total_loan_amount'])
        avg_loan_per_lendee = float(row.get('avg_loan_per_lendee', 0) if hasattr(row, 'get') else row['avg_loan_per_lendee'])
        defaulted = int(row.get('defaulted', 0) if hasattr(row, 'get') else row['defaulted'])

        score = nash_score(lendee_count, total_loan_amount, avg_loan_per_lendee, defaulted)
        results[lid] = score

    return results

