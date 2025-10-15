"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
Triton adapter scaffold: demonstrates how to call Triton Inference Server (HTTP/gRPC).
This file contains example implementation details but uses a local simulated endpoint if no Triton server is available.
"""
import os, logging, requests, json

LOG = logging.getLogger("triton_adapter")

TRITON_URL = os.environ.get("TRITON_URL", f"http://localhost:{os.environ.get('TRITON_MOCK_PORT',8001)}")

def get_embedding_from_triton(modality, input_vector, model_name="nmar_model"):
    """
    Example HTTP POST to Triton model endpoint; in local tests this will hit the mock server.
    Triton HTTP API differs; adapt input formatting accordingly.
    """
    url = TRITON_URL.rstrip("/") + "/v1/models/" + model_name + "/infer"
    payload = {
        "inputs": [{"name":"INPUT__0", "shape":[1,len(input_vector)], "datatype":"FP32", "data":[input_vector]}],
        "parameters": {}
    }
    try:
        r = requests.post(url, json=payload, timeout=5)
        if r.status_code != 200:
            LOG.warning("Triton call failed status=%s body=%s", r.status_code, r.text)
            return None
        # parse and return embedding (placeholder parsing)
        j = r.json()
        # adapt to Triton's actual output format
        return j.get("outputs", [{}])[0].get("data", [])[0]
    except Exception as e:
        LOG.exception("Triton call exception")
        return None
