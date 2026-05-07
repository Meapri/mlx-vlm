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

swift run mlx-vlm-swift generate \
  --model "${MODEL}" \
  --image "${IMAGE}" \
  --prompt "${PROMPT}" \
  --max-tokens "${MAX_TOKENS}" \
  --temperature "${TEMPERATURE}" \
  --top-p "${TOP_P}"
