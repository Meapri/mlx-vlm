#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-${MODEL:-mlx-community/SmolVLM-256M-Instruct-4bit}}"
IMAGE="${2:-${IMAGE:-Tests/Fixtures/smoke-image.svg}}"
PROMPT="${3:-${PROMPT:-Describe this image in one short sentence.}}"
MAX_TOKENS="${MAX_TOKENS:-32}"
TEMPERATURE="${TEMPERATURE:-0}"
TOP_P="${TOP_P:-1}"

cd "$(dirname "$0")/.."

echo "MODEL=${MODEL}"
echo "IMAGE=${IMAGE}"
echo "PROMPT=${PROMPT}"
echo "MLXVLM_SWIFT_DEVICE=${MLXVLM_SWIFT_DEVICE:-}"

swift build --product mlx-vlm-swift

BIN="$(swift build --show-bin-path)/mlx-vlm-swift"
BIN_DIR="$(dirname "${BIN}")"

METALLIB="$(find .build -name default.metallib -o -name mlx.metallib | head -n 1 || true)"
if [[ -z "${METALLIB}" ]]; then
  MLX_METAL_DIR="$(find .build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal -type d -maxdepth 0 2>/dev/null | head -n 1 || true)"
  if [[ -n "${MLX_METAL_DIR}" ]]; then
    echo "Compiling MLX metallib from ${MLX_METAL_DIR}"
    AIR_DIR="${BIN_DIR}/mlx-air"
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
  cp "${METALLIB}" "${BIN_DIR}/mlx.metallib"
  cp "${METALLIB}" "${BIN_DIR}/default.metallib"
else
  echo "warning: no metallib found or compiled" >&2
fi

"${BIN}" generate \
  --model "${MODEL}" \
  --image "${IMAGE}" \
  --prompt "${PROMPT}" \
  --max-tokens "${MAX_TOKENS}" \
  --temperature "${TEMPERATURE}" \
  --top-p "${TOP_P}"
