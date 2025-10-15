"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
ONNX adapter scaffold (ONNX Runtime). For local tests it will call the mock server.
"""
import os, logging, requests

LOG = logging.getLogger("onnx_adapter")
ONNX_URL = os.environ.get("ONNX_URL", f"http://localhost:{os.environ.get('ONNX_MOCK_PORT',8082)}")

def get_embedding_from_onnx(modality, input_vector, model_name="nmar_model"):
    # Placeholder for actual onnxruntime inference; here we proxy to mock.
    try:
        r = requests.post(ONNX_URL.rstrip("/") + "/v1/infer", json={"modality": modality, "input": input_vector}, timeout=5)
        if r.status_code != 200:
            LOG.warning("ONNX mock call failed")
            return None
        return r.json().get("embedding")
    except Exception:
        LOG.exception("ONNX call exception")
        return None
