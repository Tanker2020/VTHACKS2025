import math

# Simple example compute module for model scoring.
# Replace compute_score with your actual model math.

def compute_score(features: dict) -> float:
    """Compute a score from a features dict.

    This is a placeholder; adapt to your real model.
    Returns a float score (0..100).
    """
    # Example: weight-based linear score with clipping
    weights = features.get("weights") or {}
    base = features.get("base", 0.0)
    total = base
    for k, v in features.items():
        if k == "weights" or k == "base":
            continue
        w = weights.get(k, 1.0)
        try:
            total += float(v) * float(w)
        except Exception:
            continue
    # Normalize to 0..100
    score = 100.0 * (1 / (1 + math.exp(-0.01 * (total - 50))))
    return max(0.0, min(100.0, score))


def build_payload(loan_id: int, features: dict) -> dict:
    """Build a JSON-serializable payload to send to Rails.

    Contains loan_id, computed score, timestamp, and raw features (optional).
    """
    score = compute_score(features)
    return {
        "event": "score_computed",
        "loan_id": loan_id,
        "score": score,
        "features": features,
    }
