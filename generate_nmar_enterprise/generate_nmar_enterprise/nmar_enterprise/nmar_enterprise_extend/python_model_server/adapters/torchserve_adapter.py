"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
TorchServe adapter scaffold (REST). In local mode, calls a mock endpoint.
"""
import os, logging, requests

LOG = logging.getLogger("torchserve_adapter")
TORCHSERVE_URL = os.environ.get("TORCHSERVE_URL", f"http://localhost:{os.environ.get('TORCHSERVE_MOCK_PORT',8081)}")

def get_embedding_from_torchserve(modality, input_vector, model_name="nmar_model"):
    url = TORCHSERVE_URL.rstrip("/") + f"/models/{model_name}/predict"
    try:
        r = requests.post(url, json={"data": [input_vector]}, timeout=5)
        if r.status_code != 200:
            LOG.warning("TorchServe call failed status=%s", r.status_code)
            return None
        j = r.json()
        return j.get("data", [None])[0]
    except Exception:
        LOG.exception("TorchServe call exception")
        return None
