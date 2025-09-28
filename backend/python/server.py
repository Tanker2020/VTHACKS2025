import os
import json
import hmac
import hashlib
import logging
from typing import Any, Dict

from flask import Flask, request, jsonify
import requests
from dotenv import load_dotenv

from fullStackApp.backend.python.main import build_payload
from fullStackApp.backend.python.compute import run_pipeline, run_pipeline_for_uuids

load_dotenv()

# Configuration
RAILS_RECEIVE_URL = os.getenv("RAILS_RECEIVE_URL", "http://localhost:3000/receive")
SHARED_SECRET = os.getenv("SHARED_SECRET", "dev-secret")
PASSWORD = "q7V;{X$og<^);g{&THeaB07u+-4-NPs{Hm4uMn*~6" # optional additional auth header
PORT = int(os.getenv("PORT", "5000"))

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)


def sign_payload(raw: bytes, secret: str) -> str:
    mac = hmac.new(secret.encode("utf-8"), raw, hashlib.sha256)
    return mac.hexdigest()


def post_to_rails(payload: Dict[str, Any]) -> requests.Response:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    signature = sign_payload(raw, SHARED_SECRET)
    headers = {
        "Content-Type": "application/json",
        "X-Signature": f"sha256={signature}",
    }
    if PASSWORD:
        headers["Password"] = PASSWORD
    logging.info("Posting to Rails %s", RAILS_RECEIVE_URL)
    return requests.post(RAILS_RECEIVE_URL, data=raw, headers=headers, timeout=10)


@app.route("/compute_and_send", methods=["POST"])
def compute_and_send():
    """Call compute.build_payload using provided loan_id and features, then POST to Rails.

    Request JSON: {"loan_id": 123, "features": {...}}
    Response: JSON with success status and Rails response.
    """
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"ok": False, "message": "missing json"}), 400

    # Expecting JSON: { "uuids": ["id1", "id2", ...], "oracle_url": "http://..." }
    uuids = data.get("uuids")
    oracle_url = data.get("oracle_url") or os.getenv("ORACLE_URL") or RAILS_RECEIVE_URL

    if not uuids or not isinstance(uuids, (list, tuple)):
        return jsonify({"ok": False, "message": "missing or invalid uuids list"}), 400

    try:
        mapping = run_pipeline_for_uuids(uuids)
    except FileNotFoundError as e:
        logging.exception("Failed to run pipeline: CSV missing")
        return jsonify({"ok": False, "message": str(e)}), 500
    except Exception as e:
        logging.exception("Unexpected error running pipeline")
        return jsonify({"ok": False, "message": str(e)}), 500

    # Post the mapping to oracle_url with Password header
    try:
        raw = json.dumps(mapping, separators=(",", ":"), sort_keys=True).encode("utf-8")
        headers = {"Content-Type": "application/json", "Password": PASSWORD}
        # include signature if shared secret configured
        try:
            signature = sign_payload(raw, SHARED_SECRET)
            headers["X-Signature"] = f"sha256={signature}"
        except Exception:
            logging.debug("Skipping signature creation")

        logging.info("Posting mapping to oracle %s", oracle_url)
        post_resp = requests.post(oracle_url, data=raw, headers=headers, timeout=15)
        post_ok = post_resp.status_code >= 200 and post_resp.status_code < 300
    except Exception as e:
        logging.exception("Failed to POST mapping to oracle")
        post_ok = False
        post_resp = None

    # Return mapping to caller and include Password header on our response
    resp = jsonify({"ok": True, "posted": post_ok, "mapping": mapping})
    resp.headers["Password"] = PASSWORD
    if post_resp is not None:
        resp.headers["oracle_status_code"] = str(post_resp.status_code)
    return resp, 200


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"ok": True, "env": os.getenv("FLASK_ENV", "dev")})


if __name__ == "__main__":
    # bind to 0.0.0.0 so Docker and other hosts can connect
    app.run(host="0.0.0.0", port=PORT, debug=True)
