# MLX-VLM Swift Compatibility Runtime

This Swift workspace is an additive compatibility layer for `mlx-vlm`.

## Goals

- Preserve existing MLX/HuggingFace model directory compatibility.
- Provide a Swift-native runtime path using MLX Swift / MLXVLM.
- Expose Ollama-compatible API surfaces.
- Keep OpenAI-compatible API support as a first-class adapter target.
- Provide a lightweight local web UI.

## Compatibility rule

Existing model files remain the source of truth:

- `config.json`
- `generation_config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `preprocessor_config.json`
- `chat_template.jinja`
- `*.safetensors`
- `model.safetensors.index.json`

The Swift runtime must not require conversion to a new model format.

## Initial supported model types

- `qwen2_vl`
- `qwen2_5_vl`
- `qwen3_vl`
- `fastvlm`
- `smolvlm`
- `gemma3`
- `gemma4`
- `paligemma`
- `idefics3`
- `pixtral`
- `mistral3`
- `lfm2_vl`
- `glm_ocr`

Unsupported model types should return a clear error while preserving file format compatibility.

## Ollama-compatible endpoints planned

- `POST /api/generate`
- `POST /api/chat`
- `GET /api/tags`
- `POST /api/show`
- `GET /api/ps`
- `GET /api/version`

## OpenAI-compatible endpoints planned

- `POST /v1/chat/completions`
- `GET /v1/models`

## Development

```bash
cd swift
swift test
swift run mlx-vlm-swift routes
swift run mlx-vlm-swift aliases
```

> Note: the current Oracle build environment used by Hermes does not have the Swift toolchain installed, so Swift test execution must run on a Mac or CI image with Swift 5.10+.
