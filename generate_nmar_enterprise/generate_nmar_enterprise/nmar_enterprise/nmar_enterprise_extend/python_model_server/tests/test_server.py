"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "src"))
from server import app
from fastapi.testclient import TestClient

def test_infer_fallback():
    client = TestClient(app)
    resp = client.post("/infer", json={"modality":"text","payload":{"input":[1.0,2.0,3.0]}})
    assert resp.status_code == 200
    assert resp.json().get("embedding") is not None
