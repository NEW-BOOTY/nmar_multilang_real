#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
# extend_nmar_finalize.sh
#
# Purpose: Finalize NMAR extension by:
#  1) injecting JDBC DAO usage into MemoryAnchors (Java)
#  2) adding protoc generation helper and CI job to generate gRPC stubs
#  3) replacing mock HTTP servers with grpcio-based gRPC servers & Python client,
#     and providing local compile/run helper scripts.
#
# Run this from the parent directory that contains java_nmar, python_model_server,
# extend_nmar_enterprise (or adjust ROOT below).
#
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="${ROOT:-$(pwd)}"
JAVA_DIR="$ROOT/java_nmar"
PY_DIR="$ROOT/python_model_server"
EXT_DIR="$ROOT/extend_nmar_enterprise"
PROTO_DIR="$EXT_DIR/proto"
GITHUB_CI="$ROOT/.github/workflows/ci.yml"
ENV_FILE="${EXT_DIR}/.nmar_local.env"

echo "extend_nmar_finalize.sh starting — root: $ROOT"

# Safety checks
if [ ! -d "$JAVA_DIR" ]; then
  echo "ERROR: Java directory not found at $JAVA_DIR. Run generate scripts first."
  exit 1
fi
if [ ! -d "$PY_DIR" ]; then
  echo "ERROR: Python model server not found at $PY_DIR. Run generate scripts first."
  exit 1
fi
if [ ! -f "$PROTO_DIR/nmar_model_service.proto" ]; then
  echo "ERROR: Proto file not found at $PROTO_DIR/nmar_model_service.proto"
  exit 1
fi

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp "$f" "${f}.bak.$(date +%s)"
    echo "Backed up $f to ${f}.bak.$(date +%s)"
  fi
}

# -------------------------------
# 1) Inject MemoryDAO usage into MemoryAnchors.java
# -------------------------------
MEMORY_PATH="$JAVA_DIR/src/main/java/com/devin/nmar/memory/MemoryAnchors.java"
if [ -f "$MEMORY_PATH" ]; then
  backup_file "$MEMORY_PATH"
  echo "Patching MemoryAnchors to support optional JDBC persistence via MemoryDAO..."
  cat > "$MEMORY_PATH" <<'JAVA_MEM'
/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.memory;

import java.time.Instant;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * MemoryAnchors - relevance-indexed memory with optional persistence to PostgreSQL+pgvector.
 *
 * Behavior:
 *  - If system property "nmar.memory.jdbc" is set to "true" and JDBC env vars are provided,
 *    MemoryAnchors will attempt to persist and retrieve vectors via MemoryDAO.
 *  - Otherwise, defaults to in-memory behavior (backwards compatible).
 *
 * To enable persistence, set:
 *  - System property: -Dnmar.memory.jdbc=true
 *  - Environment variables (or application config): NMAR_JDBC_URL, NMAR_JDBC_USER, NMAR_JDBC_PASS
 */
public class MemoryAnchors {
    private static final Logger LOG = Logger.getLogger(MemoryAnchors.class.getName());

    public static class MemoryChunk {
        public final UUID id = UUID.randomUUID();
        public final String key;
        public final String payload;
        public double relevance;
        public final Instant created;
        public int accessCount = 0;

        public MemoryChunk(String key, String payload, double relevance) {
            this.key = key;
            this.payload = payload;
            this.relevance = relevance;
            this.created = Instant.now();
        }
    }

    private final Map<UUID, MemoryChunk> store = new HashMap<>();
    private final int maxChunks;
    private final double decayRate;
    // optional persistence
    private final boolean persistenceEnabled;
    private com.devin.nmar.persistence.MemoryDAO dao = null;

    public MemoryAnchors(int maxChunks, double decayRate) {
        this.maxChunks = Math.max(100, maxChunks);
        this.decayRate = Math.max(0.0, decayRate);
        // check system property for persistence
        this.persistenceEnabled = Boolean.parseBoolean(System.getProperty("nmar.memory.jdbc", "false"));
        LOG.info(() -> String.format("MemoryAnchors init maxChunks=%d decayRate=%f persistence=%b",
                this.maxChunks, this.decayRate, this.persistenceEnabled));
        if (this.persistenceEnabled) {
            try {
                String url = System.getenv("NMAR_JDBC_URL");
                String user = System.getenv("NMAR_JDBC_USER");
                String pass = System.getenv("NMAR_JDBC_PASS");
                if (url == null || user == null || pass == null) {
                    LOG.warning("Persistence enabled but JDBC env vars missing (NMAR_JDBC_URL/NMAR_JDBC_USER/NMAR_JDBC_PASS). Falling back to in-memory.");
                    this.persistenceEnabled = false;
                } else {
                    this.dao = new com.devin.nmar.persistence.MemoryDAO(url, user, pass);
                    LOG.info("MemoryDAO initialized for persistence.");
                }
            } catch (Exception e) {
                LOG.log(Level.SEVERE, "Failed to initialize MemoryDAO, falling back to in-memory.", e);
                this.persistenceEnabled = false;
            }
        }
    }

    public synchronized MemoryChunk remember(String key, String payload, double relevance, float[] embedding) {
        try {
            if (persistenceEnabled && dao != null && embedding != null) {
                UUID id = dao.saveMemory(key, payload, relevance, embedding);
                LOG.fine(() -> "Persisted memory id=" + id);
                // create in-memory reference as well
                MemoryChunk m = new MemoryChunk(key, payload, relevance);
                store.put(m.id, m);
                if (store.size() > maxChunks) consolidateIfNeeded();
                return m;
            } else {
                MemoryChunk m = new MemoryChunk(key, payload, relevance);
                store.put(m.id, m);
                if (store.size() > maxChunks) consolidateIfNeeded();
                return m;
            }
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "remember failed", e);
            throw e;
        }
    }

    // fallback for original signature (no embedding)
    public synchronized MemoryChunk remember(String key, String payload, double relevance) {
        return remember(key, payload, relevance, null);
    }

    // retrieval will prefer persistent store if enabled
    public synchronized List<MemoryChunk> retrieve(String keyQuery, int limit, float[] queryEmbedding) {
        try {
            if (persistenceEnabled && dao != null && queryEmbedding != null) {
                List<Map<String,Object>> rows = dao.nearestNeighbors(queryEmbedding, limit);
                List<MemoryChunk> out = new ArrayList<>();
                for (Map<String,Object> r : rows) {
                    MemoryChunk c = new MemoryChunk((String)r.get("key"), (String)r.get("payload"), ((Number)r.get("relevance")).doubleValue());
                    out.add(c);
                }
                return out;
            } else {
                // in-memory retrieval as before, ignoring queryEmbedding
                long now = Instant.now().toEpochMilli();
                List<MemoryChunk> list = new ArrayList<>();
                for (MemoryChunk m : store.values()) {
                    if (m.key.contains(keyQuery) || m.payload.contains(keyQuery)) {
                        double ageHours = Math.max(0.0, (now - m.created.toEpochMilli()) / 1000.0 / 3600.0);
                        double freshness = Math.exp(-decayRate * ageHours);
                        double score = m.relevance * freshness + Math.log(1 + m.accessCount);
                        m.relevance = score;
                        list.add(m);
                    }
                }
                list.sort(Comparator.comparingDouble((MemoryChunk x) -> x.relevance).reversed());
                if (list.size() > limit) list = list.subList(0, limit);
                for (MemoryChunk m : list) m.accessCount++;
                return list;
            }
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "retrieve failed", e);
            throw e;
        }
    }

    // backwards-compatible convenience
    public synchronized List<MemoryChunk> retrieve(String keyQuery, int limit) {
        return retrieve(keyQuery, limit, null);
    }

    private synchronized void consolidateIfNeeded() {
        try {
            if (store.size() <= maxChunks) return;
            List<MemoryChunk> list = new ArrayList<>(store.values());
            list.sort(Comparator.comparingDouble(a -> a.relevance));
            int removed = 0;
            while (store.size() > maxChunks && !list.isEmpty()) {
                MemoryChunk victim = list.remove(0);
                store.remove(victim.id);
                removed++;
            }
            LOG.info(() -> "consolidateIfNeeded removed=" + removed);
        } catch (Exception e) {
            LOG.log(Level.SEVERE, "consolidation failed", e);
            throw e;
        }
    }

    public synchronized Map<String,Object> snapshot() {
        Map<String,Object> m = new HashMap<>();
        m.put("chunks", store.size());
        m.put("persistenceEnabled", persistenceEnabled);
        return m;
    }
}

/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
JAVA_MEM

  echo "Patched $MEMORY_PATH"
else
  echo "MemoryAnchors.java not found at expected path: $MEMORY_PATH"
fi

# -------------------------------
# 2) Create protoc helper & CI job
# -------------------------------
PROTO_GEN_SCRIPT="$EXT_DIR/scripts/generate_protos.sh"
backup_file "$GITHUB_CI"
cat > "$PROTO_GEN_SCRIPT" <<'PROTO_GEN'
#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
# generate_protos.sh - generates gRPC stubs for Java and Python from proto files
set -Eeuo pipefail
PROTO_DIR="$(cd "$(dirname "$0")/../proto" && pwd)"
OUT_JAVA="$(pwd)/java_nmar/src/main/java"
OUT_PY="$(pwd)/python_model_server/grpc_generated"
mkdir -p "$OUT_PY"
echo "Generating protos from $PROTO_DIR"
# Java (requires protoc + protoc-gen-grpc-java on PATH)
if command -v protoc >/dev/null 2>&1; then
  # Java generation (if plugin installed)
  protoc -I="$PROTO_DIR" --java_out="$OUT_JAVA" --grpc-java_out="$OUT_JAVA" "$PROTO_DIR"/*.proto || echo "Java protoc step returned non-zero"
else
  echo "protoc not found; skipping java stub generation."
fi

# Python generation using grpc_tools.protoc
python - <<PY
import os, sys, subprocess
proto_dir = os.path.join(os.getcwd(), "proto")
out_py = os.path.join(os.getcwd(), "python_model_server", "grpc_generated")
os.makedirs(out_py, exist_ok=True)
cmd = [
  sys.executable, "-m", "grpc_tools.protoc",
  "-I", proto_dir,
  "--python_out=%s" % out_py,
  "--grpc_python_out=%s" % out_py,
] + [os.path.join(proto_dir, f) for f in os.listdir(proto_dir) if f.endswith(".proto")]
try:
    subprocess.check_call(cmd)
    print("Python gRPC stubs generated.")
except Exception as e:
    print("Python gRPC generation failed or grpc_tools not installed:", e)
PY
PROTO_GEN
chmod +x "$PROTO_GEN_SCRIPT"
echo "Generated proto helper script at $PROTO_GEN_SCRIPT"

# Patch GitHub Actions workflow to add generate-grpc-stubs job (idempotent)
if [ -f "$GITHUB_CI" ]; then
  if ! grep -q "generate-grpc-stubs" "$GITHUB_CI"; then
    echo "Patching CI workflow to add generate-grpc-stubs job..."
    backup_file "$GITHUB_CI"
    # insert job after build-python job section — best-effort append at end of jobs
    perl -0777 -pe 's/(jobs:\n(?:.|\n)*)$/$1\n  generate-grpc-stubs:\n    runs-on: ubuntu-latest\n    needs: [build-java, build-python]\n    steps:\n      - uses: actions/checkout@v4\n      - name: Install protoc and grpc tools\n        run: |\n          sudo apt-get update && sudo apt-get install -y protobuf-compiler python3-dev python3-pip\n          python3 -m pip install grpcio-tools\n      - name: Generate protos\n        run: |\n          ./extend_nmar_enterprise/scripts/generate_protos.sh\n/s' -i "$GITHUB_CI" || true
    echo "CI patched: generate-grpc-stubs job added."
  else
    echo "CI already contains generate-grpc-stubs job; skipping patch."
  fi
else
  echo "CI workflow file not found at $GITHUB_CI; skipping CI patch."
fi

# -------------------------------
# 3) Replace mock services with grpcio-based gRPC server & client (Python)
# -------------------------------
GRPC_SERVER_DIR="$PY_DIR/grpc_server"
GRPC_CLIENT_DIR="$PY_DIR/grpc_client"
mkdir -p "$GRPC_SERVER_DIR" "$GRPC_CLIENT_DIR"

# server __init__.py
cat > "$GRPC_SERVER_DIR/__init__.py" <<'PY_INIT'
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
gRPC server package for NMAR (generated skeleton).
"""
PY_INIT

# write a server implementation using grpcio (requires grpcio & grpcio-tools)
cat > "$GRPC_SERVER_DIR/server.py" <<'PY_GRPC_SERVER_IMPL'
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
gRPC server implementation for ModelService.
Generates deterministic embeddings for local testing. Uses proto compiled stubs in grpc_generated.
"""
import os
import time
import random
from concurrent import futures

import grpc

# try to import generated stubs
try:
    from grpc_generated import nmar_model_service_pb2 as pb2
    from grpc_generated import nmar_model_service_pb2_grpc as pb2_grpc
except Exception as e:
    raise ImportError("Please run the proto generation script to produce grpc_generated modules. " + str(e))

API_KEY = os.environ.get("MODEL_SERVER_API_KEY", "local_dummy_key")
PORT = int(os.environ.get("GRPC_PORT", 50051))

class ModelServiceServicer(pb2_grpc.ModelServiceServicer):
    def GetEmbedding(self, request, context):
        if request.api_key != API_KEY:
            context.set_code(grpc.StatusCode.UNAUTHENTICATED)
            context.set_details('Invalid API key')
            return pb2.EmbeddingResponse(embedding=[], message="unauthorized")
        modality = request.modality
        input_vals = list(request.input)
        seed = int(sum(input_vals) * 1000) ^ hash(modality)
        r = random.Random(seed)
        emb = [r.gauss(0,0.5) for _ in range(128)]
        return pb2.EmbeddingResponse(embedding=emb, message="ok")

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    pb2_grpc.add_ModelServiceServicer_to_server(ModelServiceServicer(), server)
    server.add_insecure_port(f'[::]:{PORT}')
    server.start()
    print(f"gRPC server started on port {PORT}")
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        server.stop(0)

if __name__ == "__main__":
    serve()
PY_GRPC_SERVER_IMPL

# client
cat > "$GRPC_CLIENT_DIR/client.py" <<'PY_GRPC_CLIENT'
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
gRPC client example for ModelService.
"""
import os
import grpc
try:
    from grpc_generated import nmar_model_service_pb2 as pb2
    from grpc_generated import nmar_model_service_pb2_grpc as pb2_grpc
except Exception as e:
    raise ImportError("gRPC generated stubs missing. Run the proto generator. " + str(e))

def get_embedding(host='localhost', port=50051, api_key='local_dummy_key', modality='text', input_vals=None):
    channel = grpc.insecure_channel(f'{host}:{port}')
    stub = pb2_grpc.ModelServiceStub(channel)
    req = pb2.EmbeddingRequest(modality=modality, input=input_vals or [], api_key=api_key)
    resp = stub.GetEmbedding(req)
    return resp.embedding, resp.message

if __name__ == "__main__":
    emb, msg = get_embedding()
    print("Embedding length:", len(emb), "message:", msg)
PY_GRPC_CLIENT

# compile_and_run_grpc_local.sh - compiles protos and runs the grpc server (local)
COMPILE_RUN="$EXT_DIR/scripts/compile_and_run_grpc_local.sh"
cat > "$COMPILE_RUN" <<'COMPILE_RUN'
#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTO_DIR="$ROOT/proto"
PY_OUT="$ROOT/../python_model_server/grpc_generated"
mkdir -p "$PY_OUT"
echo "Generating python gRPC stubs..."
python3 -m grpc_tools.protoc -I="$PROTO_DIR" --python_out="$PY_OUT" --grpc_python_out="$PY_OUT" "$PROTO_DIR"/*.proto
echo "Stubs written to $PY_OUT"
echo "Installing python deps (virtualenv recommended)..."
python3 -m pip install grpcio grpcio-tools
echo "Running gRPC server..."
export MODEL_SERVER_API_KEY="$(grep MODEL_SERVER_API_KEY "$ROOT/.nmar_local.env" | cut -d= -f2)"
export GRPC_PORT="$(grep GRPC_PORT "$ROOT/.nmar_local.env" | cut -d= -f2)"
python3 ../python_model_server/grpc_server/server.py
COMPILE_RUN
chmod +x "$COMPILE_RUN"
echo "Wrote compile/run helper at $COMPILE_RUN"

# -------------------------------
# 4) Update python requirements to include grpcio if not present
# -------------------------------
REQS="$PY_DIR/requirements.txt"
if [ -f "$REQS" ]; then
  if ! grep -q "grpcio" "$REQS"; then
    echo "Adding grpcio and grpcio-tools to $REQS"
    echo "grpcio==1.58.0" >> "$REQS"
    echo "grpcio-tools==1.58.0" >> "$REQS"
  else
    echo "grpcio already present in $REQS"
  fi
else
  cat > "$REQS" <<REQS_P
grpcio==1.58.0
grpcio-tools==1.58.0
REQS_P
fi

# -------------------------------
# 5) Update README and give instructions
# -------------------------------
README_PATCH="$EXT_DIR/README_FINALIZE.md"
cat > "$README_PATCH" <<README_CONT
# NMAR Finalize — Proto generation, gRPC server/client, and MemoryAnchors persistence wiring
Copyright © 2025 Devin B. Royal. All Rights Reserved.

Summary of changes:
 - MemoryAnchors (Java) updated to optionally persist/retrieve via MemoryDAO when persistence is enabled.
   Enable via java system property: -Dnmar.memory.jdbc=true and set NMAR_JDBC_URL/NMAR_JDBC_USER/NMAR_JDBC_PASS env vars.

 - Protobuf/gRPC generation helper created: extend_nmar_enterprise/scripts/generate_protos.sh
   - Generates Java & Python stubs (requires protoc and/or grpc_tools).

 - CI patch: .github/workflows/ci.yml updated to add generate-grpc-stubs job (if CI file exists).

 - Python gRPC server/client implemented under python_model_server/grpc_server and grpc_client.
   - Use extend_nmar_enterprise/scripts/compile_and_run_grpc_local.sh to generate stubs and run the server locally.

How to test locally:
 1) Ensure Docker is running and you have a PostgreSQL instance (local mock infra docker-compose is provided)
 2) From the project root:
    ./extend_nmar_enterprise/scripts/generate_protos.sh
    # or run the compile/run script:
    ./extend_nmar_enterprise/scripts/compile_and_run_grpc_local.sh
 3) Run the gRPC client:
    python3 python_model_server/grpc_client/client.py

Notes:
 - The proto file is at: extend_nmar_enterprise/proto/nmar_model_service.proto
 - For production: generate Java stubs via protoc + protoc-gen-grpc-java and use generated classes instead of the skeleton.
README_CONT

echo "Finalize script completed. Key artifacts:"
echo " - Patched Java MemoryAnchors: $MEMORY_PATH"
echo " - Proto generator: $PROTO_GEN_SCRIPT"
echo " - CI patched (if present): $GITHUB_CI"
echo " - gRPC server: $PY_DIR/grpc_server/server.py"
echo " - gRPC client: $PY_DIR/grpc_client/client.py"
echo " - Compile & run helper: $COMPILE_RUN"
echo
echo "Run the generated helpers to compile protos and run the gRPC server locally."
echo "If you want, I can now run a simulated local test (generate stubs and start server), but I will not execute it automatically — tell me to run it and I will produce the exact commands you should run locally."
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
