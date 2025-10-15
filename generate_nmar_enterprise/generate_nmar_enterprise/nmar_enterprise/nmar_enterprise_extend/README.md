# NeuroMesh Adaptive Reasoner (NMAR) — Enterprise Prototype
Copyright © 2025 Devin B. Royal. All Rights Reserved.

This repository is a generated enterprise-grade prototype with:
- Java core (dynamic NeuroMesh, modality fusion placeholder, memory, meta-reasoner, adaptive learner)
- Python model-serving microservice (Torch/ONNX adapter + FastAPI)
- Dockerfiles and docker-compose for local integration
- Kubernetes manifests (GPU resource placeholders)
- GitHub Actions CI pipeline
- Benchmark harness (local synthetic benchmark)

IMPORTANT:
- Model weights are NOT included. Place models under python_model_server/models/ (e.g., model.pt or model.onnx).
- Configure GPU drivers and Kubernetes node configuration with NVIDIA device plugin for GPU scheduling.

Quickstart (local):
1. Build Python model server:
   cd python_model_server
   docker build -t nmar-model-server:local .
2. Build Java core:
   cd ../java_nmar
   docker build -t nmar-core:local .
3. Run services:
   docker-compose up --build
4. Run benchmark:
   ./benchmarks/run_local_bench.sh

For production deployment:
- Provide model artifacts in a secure artifact repository (S3, GCS) and mount them via initContainers or volumes.
- Use Triton/TorchServe/ONNX-RT for highly optimized serving. Adapter code includes a lightweight interface to do so.
- Integrate vector DB (e.g., pgvector, Milvus) for MemoryAnchors persistence (not included but easily pluggable).
- Configure CI to push Docker images to your registry and deploy to Kubernetes via manifests/Helm.

This repo is generated programmatically. Modify, extend, and integrate into your infra.

© 2025 Devin B. Royal. All Rights Reserved.
