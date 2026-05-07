#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-mlx-community/Qwen2-VL-2B-Instruct-4bit}"
IMAGE="${IMAGE:-Tests/Fixtures/smoke-image.png}"
PROMPT="${PROMPT:-Describe this image in one short sentence.}"
MAX_TOKENS="${MAX_TOKENS:-8}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-11435}"
BASE_URL="http://${HOST}:${PORT}"

swift build --product mlx-vlm-swift
BIN="$(swift build --show-bin-path)/mlx-vlm-swift"
BIN_DIR="$(dirname "${BIN}")"

METALLIB="$(find .build -name default.metallib -o -name mlx.metallib | head -n 1 || true)"
if [[ -z "${METALLIB}" ]]; then
  MLX_METAL_DIR="$(find .build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal -type d -maxdepth 0 2>/dev/null | head -n 1 || true)"
  if [[ -n "${MLX_METAL_DIR}" ]]; then
    echo "Compiling MLX metallib from ${MLX_METAL_DIR}"
    AIR_DIR="${BIN_DIR}/mlx-metal-air"
    rm -rf "${AIR_DIR}"
    mkdir -p "${AIR_DIR}"
    find "${MLX_METAL_DIR}" -name '*.metal' | sort | while IFS= read -r source; do
      rel="${source#${MLX_METAL_DIR}/}"
      out="${AIR_DIR}/${rel//\//_}.air"
      xcrun -sdk macosx metal -I "${MLX_METAL_DIR}" -c "${source}" -o "${out}"
    done
    xcrun -sdk macosx metallib "${AIR_DIR}"/*.air -o "${BIN_DIR}/mlx.metallib"
    METALLIB="${BIN_DIR}/mlx.metallib"
  fi
fi

if [[ -n "${METALLIB}" ]]; then
  echo "METALLIB=${METALLIB}"
  src="$(cd "$(dirname "${METALLIB}")" && pwd)/$(basename "${METALLIB}")"
  mlx_dest="$(cd "${BIN_DIR}" && pwd)/mlx.metallib"
  default_dest="$(cd "${BIN_DIR}" && pwd)/default.metallib"
  if [[ "${src}" != "${mlx_dest}" ]]; then
    cp "${METALLIB}" "${BIN_DIR}/mlx.metallib"
  fi
  if [[ "${src}" != "${default_dest}" ]]; then
    cp "${METALLIB}" "${BIN_DIR}/default.metallib"
  fi
else
  echo "warning: no MLX metallib found or compiled" >&2
fi

SERVER_LOG="${SERVER_LOG:-ollama-smoke-server.log}"
rm -f "${SERVER_LOG}"
"${BIN}" serve --host "${HOST}" --port "${PORT}" >"${SERVER_LOG}" 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "${SERVER_PID}" 2>/dev/null || true
  wait "${SERVER_PID}" 2>/dev/null || true
}
trap cleanup EXIT

for i in $(seq 1 60); do
  if curl -fsS "${BASE_URL}/api/version" >/tmp/mlx-vlm-ollama-version.json; then
    break
  fi
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "server exited early" >&2
    cat "${SERVER_LOG}" >&2 || true
    exit 1
  fi
  sleep 1
done

curl -fsS "${BASE_URL}/api/version"
echo ""
curl -fsS "${BASE_URL}/api/tags" >/tmp/mlx-vlm-ollama-tags.json
python3 - <<'PY'
import json
print('tags_ok', json.load(open('/tmp/mlx-vlm-ollama-tags.json')).get('models') is not None)
PY

python3 - <<'PY' > /tmp/mlx-vlm-ollama-generate.json
import base64, json, os
with open(os.environ.get('IMAGE', 'Tests/Fixtures/smoke-image.png'), 'rb') as f:
    image = base64.b64encode(f.read()).decode()
print(json.dumps({
    'model': os.environ.get('MODEL', 'mlx-community/Qwen2-VL-2B-Instruct-4bit'),
    'prompt': os.environ.get('PROMPT', 'Describe this image in one short sentence.'),
    'images': [image],
    'stream': False,
    'options': {
        'num_predict': int(os.environ.get('MAX_TOKENS', '8')),
        'temperature': 0,
        'top_p': 1,
    },
}))
PY

curl -fsS --max-time 240 \
  -H 'Content-Type: application/json' \
  -d @/tmp/mlx-vlm-ollama-generate.json \
  "${BASE_URL}/api/generate" | tee /tmp/mlx-vlm-ollama-generate-response.json
python3 - <<'PY'
import json
payload=json.load(open('/tmp/mlx-vlm-ollama-generate-response.json'))
assert payload.get('done') is True, payload
assert payload.get('response'), payload
print('\nollama_generate_response=', payload['response'])
PY

curl -fsS "${BASE_URL}/api/ps" | tee /tmp/mlx-vlm-ollama-ps.json
python3 - <<'PY'
import json, os
payload=json.load(open('/tmp/mlx-vlm-ollama-ps.json'))
models=payload.get('models') or []
assert any(m.get('model') == os.environ.get('MODEL') or m.get('name') == os.environ.get('MODEL') for m in models), payload
print('\nollama_ps_models=', [m.get('model') for m in models])
PY

curl -fsS "${BASE_URL}/mlx-vlm/status" | tee /tmp/mlx-vlm-status.json
python3 - <<'PY'
import json, os
payload=json.load(open('/tmp/mlx-vlm-status.json'))
models=payload.get('loaded_models') or []
assert os.environ.get('MODEL') in models, payload
print('\nruntime_loaded_models=', models)
PY

python3 - <<'PY' > /tmp/mlx-vlm-ollama-generate-stream.json
import base64, json, os
with open(os.environ.get('IMAGE', 'Tests/Fixtures/smoke-image.png'), 'rb') as f:
    image = base64.b64encode(f.read()).decode()
print(json.dumps({
    'model': os.environ.get('MODEL', 'mlx-community/Qwen2-VL-2B-Instruct-4bit'),
    'prompt': os.environ.get('PROMPT', 'Describe this image in one short sentence.'),
    'images': [image],
    'stream': True,
    'options': {
        'num_predict': int(os.environ.get('MAX_TOKENS', '8')),
        'temperature': 0,
        'top_p': 1,
    },
}))
PY

curl -fsS --max-time 180 \
  -H 'Content-Type: application/json' \
  -d @/tmp/mlx-vlm-ollama-generate-stream.json \
  "${BASE_URL}/api/generate" | tee /tmp/mlx-vlm-ollama-generate-stream-response.ndjson
python3 - <<'PY'
import json
lines=[line for line in open('/tmp/mlx-vlm-ollama-generate-stream-response.ndjson') if line.strip()]
assert lines, 'empty stream response'
payloads=[json.loads(line) for line in lines]
assert payloads[-1].get('done') is True, payloads[-1]
text=''.join(p.get('response') or '' for p in payloads)
assert text, payloads
print('\nollama_stream_chunks=', len(payloads))
print('ollama_stream_response=', text)
PY
