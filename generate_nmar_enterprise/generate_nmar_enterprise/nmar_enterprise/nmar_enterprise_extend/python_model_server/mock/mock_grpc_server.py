"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
Mock gRPC server for ModelService (simulated). Standing in for Triton/TorchServe for local tests.
This uses pure HTTP as an accessible simulation so users don't need to compile protos.
"""
import os
import time
import random
from flask import Flask, request, jsonify

app = Flask("mock_grpc")

API_KEY = os.environ.get("MODEL_SERVER_API_KEY", "local_dummy_key")

@app.route("/v1/get_embedding", methods=["POST"])
def get_embedding():
    data = request.json or {}
    api_key = data.get("api_key")
    if api_key != API_KEY:
        return jsonify({"error":"unauthorized"}), 401
    modality = data.get("modality","text")
    input_vals = data.get("input", [0.0])
    # deterministic pseudo-embedding
    seed = int(sum([float(x) for x in input_vals]) * 1000) ^ hash(modality)
    r = random.Random(seed)
    emb = [r.gauss(0,0.5) for _ in range(128)]
    time.sleep(0.03)
    return jsonify({"embedding": emb, "message":"simulated embed"}), 200

if __name__ == "__main__":
    port = int(os.environ.get("TRITON_MOCK_PORT", "8001"))
    app.run(host="0.0.0.0", port=port)
