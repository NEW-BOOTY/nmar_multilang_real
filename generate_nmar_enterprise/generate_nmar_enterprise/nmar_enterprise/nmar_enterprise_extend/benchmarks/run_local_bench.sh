#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")"/.. && pwd)"
MODEL_SERVER="${MODEL_SERVER:-http://localhost:8080}"
OUT="$ROOT/results/local_bench.jsonl"

echo "{" > "$OUT"
echo "\"meta\": {\"timestamp\":\"$(date -u +%FT%TZ)\"}" >> "$OUT"
echo "}" >> "$OUT"

# Simple synthetic tasks to validate pipeline latency and basic correctness
python - <<'PY'
import requests, time, json
server = "${MODEL_SERVER}"
payload = {"modality":"text","payload":{"input":[0.1,0.2,0.3]}}
t0 = time.time()
r = requests.post(server + "/infer", json=payload, timeout=10)
t1 = time.time()
result = {"latency_ms": (t1-t0)*1000.0, "status_code": r.status_code, "len_embedding": len(r.json().get("embedding",[]))}
print(json.dumps(result, ensure_ascii=False))
PY
