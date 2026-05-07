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
