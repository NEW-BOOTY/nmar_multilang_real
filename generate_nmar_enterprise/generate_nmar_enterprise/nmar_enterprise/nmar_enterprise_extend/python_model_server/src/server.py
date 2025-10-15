"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
import os
import logging
from typing import Optional, Dict, Any
import numpy as np

# Try to import torch and onnxruntime; handle missing gracefully
try:
    import torch
except Exception:
    torch = None

try:
    import onnxruntime as ort
except Exception:
    ort = None

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

LOG = logging.getLogger("nmar_model_server")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="NMAR Model Server")

MODEL_PATH = os.environ.get("NMAR_MODEL_PATH", "/models/model.pt")
MODEL_TYPE = os.environ.get("NMAR_MODEL_TYPE", "torch")  # "torch" or "onnx"

class InferenceRequest(BaseModel):
    modality: str
    payload: Optional[Dict[str,Any]] = None

class InferenceResponse(BaseModel):
    success: bool
    embedding: Optional[list] = None
    message: Optional[str] = None

# lightweight ModelAdapter pattern
class ModelAdapter:
    def __init__(self, model_path: str, model_type: str = "torch"):
        self.model_path = model_path
        self.model_type = model_type
        self.model = None
        self.session = None
        self.dtype = np.float32
        self.load()

    def load(self):
        LOG.info(f"Loading model at {self.model_path} as {self.model_type}")
        if self.model_type == "torch":
            if torch is None:
                raise RuntimeError("torch not available; install PyTorch for torch model support")
            if not os.path.exists(self.model_path):
                raise FileNotFoundError(f"Model file not found: {self.model_path}")
            try:
                self.model = torch.jit.load(self.model_path, map_location="cpu")
                self.model.eval()
                LOG.info("Torch JIT model loaded successfully")
            except Exception as e:
                LOG.exception("Torch load failed")
                raise
        elif self.model_type == "onnx":
            if ort is None:
                raise RuntimeError("onnxruntime not available; install onnxruntime for ONNX support")
            if not os.path.exists(self.model_path):
                raise FileNotFoundError(f"Model file not found: {self.model_path}")
            try:
                self.session = ort.InferenceSession(self.model_path, providers=["CPUExecutionProvider"])
                LOG.info("ONNX Runtime session created")
            except Exception:
                LOG.exception("ONNX load failed")
                raise
        else:
            raise ValueError("Unsupported model_type: " + str(self.model_type))

    def infer(self, modality: str, payload: Dict[str,Any]):
        # This is a generic adapter. Expects preprocessed tensors in payload['input'] as list/ndarray.
        if self.model:
            # Torch pathway
            try:
                inp = torch.tensor(np.array(payload.get("input", []), dtype=np.float32))
                with torch.no_grad():
                    out = self.model(inp)
                if isinstance(out, torch.Tensor):
                    emb = out.cpu().numpy().flatten().tolist()
                else:
                    emb = np.array(out).flatten().tolist()
                return emb
            except Exception:
                LOG.exception("Torch inference failed")
                raise
        elif self.session:
            try:
                inp = np.array(payload.get("input", []), dtype=np.float32)
                # ONNX models expect dict input - adapt based on model signature
                input_name = self.session.get_inputs()[0].name
                res = self.session.run(None, {input_name: inp})
                emb = np.array(res[0]).flatten().tolist()
                return emb
            except Exception:
                LOG.exception("ONNX inference failed")
                raise
        else:
            # Fallback dummy deterministic embedding if no model loaded
            LOG.warning("No model loaded; returning deterministic fallback embedding")
            base = np.array(payload.get("input", [0.0]), dtype=np.float32)
            rng = np.random.RandomState(int(np.sum(base)*1000) & 0xffffffff)
            emb = rng.randn(128).tolist()
            return emb

# instantiate adapter lazily
_adapter = None

def get_adapter():
    global _adapter
    if _adapter is None:
        try:
            _adapter = ModelAdapter(MODEL_PATH, MODEL_TYPE)
        except Exception as e:
            LOG.warning("ModelAdapter failed to initialize: %s", e)
            _adapter = None
    return _adapter

@app.post("/infer", response_model=InferenceResponse)
def infer(req: InferenceRequest):
    try:
        adapter = get_adapter()
        payload = req.payload or {}
        if adapter is None:
            # return fallback deterministic embedding to keep pipeline functional
            base = np.array(payload.get("input", [0.0]), dtype=np.float32)
            rng = np.random.RandomState(int(np.sum(base)*1000) & 0xffffffff)
            emb = rng.randn(128).tolist()
            return InferenceResponse(success=True, embedding=emb, message="fallback embedding (no model)")
        emb = adapter.infer(req.modality, payload)
        return InferenceResponse(success=True, embedding=emb)
    except FileNotFoundError as fe:
        raise HTTPException(status_code=503, detail=str(fe))
    except Exception as ex:
        LOG.exception("inference error")
        raise HTTPException(status_code=500, detail="Inference failed: " + str(ex))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), log_level="info")
