# NMAR Extension — Mock Infra, Triton/ONNX/TorchServe Adapters, Helm & pgvector
Copyright © 2025 Devin B. Royal. All Rights Reserved.

This extension script scaffolds production-ready artifacts and local simulation harnesses.
It does NOT provision any real cloud resources. It creates:
 - proto/ (gRPC proto definitions)
 - Java gRPC skeletons (replace with protoc-generated stubs for production)
 - Python adapter scaffolds (triton_adapter, torchserve_adapter, onnx_adapter)
 - docker-compose.mock.yml (Postgres with pgvector extension, model server mock)
 - Helm chart scaffold under infra/helm/nmar
 - Postgres migration SQL (db/migrations)
 - JDBC DAO (java_nmar/src/main/java/com/devin/nmar/persistence/MemoryDAO.java)
 - Local randomized .nmar_local.env with credentials (safe for local use)

How to run (local simulation):
1. Ensure Docker & docker-compose are installed.
2. Run this script to generate scaffolding.
3. From the extension directory:
   cd extend_nmar_enterprise
   ./scripts/run_local_e2e.sh
   # This will build the python model server image, launch postgres + mock server, call the model server, and insert a vector into Postgres.

Production notes:
 - Replace randomized credentials in .nmar_local.env with secure secrets, then store them in your secret manager.
 - Generate gRPC Java stubs from proto/ using protoc and replace ModelServiceGrpcClient with the generated stub.
 - Configure Triton/TorchServe/ONNX runtime endpoints and point the adapter scaffolds at them.
 - For pgvector production tuning, adjust index type (HNSW/IVF) and memory settings.
 - Helm chart is scaffolded; expand templates for ConfigMaps, Secrets, Ingress (TLS), and RBAC.

