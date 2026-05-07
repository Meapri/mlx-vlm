# Swift MLX-VLM Ollama Compatibility Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task when parallel implementation becomes useful.

**Goal:** Add a Swift-native compatibility layer that preserves existing MLX VLM model directory compatibility while exposing Ollama-style APIs and a lightweight local UI.

**Architecture:** Keep Python `mlx_vlm` untouched and add a separate `swift/` SwiftPM workspace. The Swift workspace is split into core model/runtime abstractions, MLX-VLM compatibility metadata, Ollama/OpenAI adapter DTOs, a server shell, CLI entrypoint, and static web UI assets. Existing MLX/HuggingFace model files remain the source of truth: `config.json`, `*.safetensors`, tokenizer files, and processor config are never rewritten into a new format.

**Tech Stack:** Swift Package Manager, Foundation/Codable, future MLX Swift dependencies (`mlx-swift`, `mlx-swift-lm`), Ollama JSONL-compatible response types, static HTML/CSS/JS UI.

---

## Non-Negotiable Compatibility Rules

1. Existing MLX model directories must remain valid without conversion.
2. Model aliases must resolve to original model IDs or local paths; aliases must not replace source identity.
3. `model_type` from `config.json` drives architecture selection via a Swift registry/remapping table.
4. Weight keys in safetensors must remain canonical; Swift model parameter paths should adapt to existing keys, not vice versa.
5. Unsupported `model_type` must fail with an explicit compatibility error listing supported types.
6. API/UI layers must call the same core runtime; no divergent generation behavior per API.

## Compatibility Surface

### Existing MLX files to preserve

- `config.json`
- `generation_config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `special_tokens_map.json`
- `preprocessor_config.json`
- `chat_template.jinja`
- `model.safetensors`
- `model-00001-of-000xx.safetensors`
- `model.safetensors.index.json`

### Initial model type targets

- `qwen2_vl`
- `qwen2_5_vl`
- `qwen3_vl`
- `fastvlm`
- `llava_qwen2` remapped to `fastvlm`
- `smolvlm`
- `gemma3`
- `gemma4`

## Phase 1 Tasks: Repository Scaffolding

### Task 1: Add Swift workspace skeleton

**Objective:** Create a SwiftPM workspace under `swift/` without touching Python runtime behavior.

**Files:**
- Create: `swift/Package.swift`
- Create: `swift/Sources/MLXVLMCore/ModelAlias.swift`
- Create: `swift/Sources/MLXVLMCompat/ModelRemapping.swift`
- Create: `swift/Sources/MLXVLMOllama/OllamaDTOs.swift`
- Create: `swift/Sources/MLXVLMServer/ServerShell.swift`
- Create: `swift/Sources/mlx-vlm-swift/main.swift`
- Create: `swift/Tests/MLXVLMCompatTests/ModelRemappingTests.swift`
- Create: `swift/Tests/MLXVLMOllamaTests/OllamaDTOTests.swift`

**Verification:** `swift test` when Swift toolchain is available. In environments without Swift, verify file layout and syntax by review.

### Task 2: Implement model remapping and compatibility errors

**Objective:** Mirror the Python `MODEL_REMAPPING` behavior for initial Swift-supported VLM model types.

**Files:**
- Modify: `swift/Sources/MLXVLMCompat/ModelRemapping.swift`
- Test: `swift/Tests/MLXVLMCompatTests/ModelRemappingTests.swift`

**Behavior:**
- `llava_qwen2` -> `fastvlm`
- `llava-qwen2` -> `llava_bunny` for parity documentation, but mark unsupported initially unless implemented
- `lfm2-vl` -> `lfm2_vl`
- `granite-vision` -> `granite_vision`
- `rf-detr` -> `rfdetr`
- canonical values pass through lowercased

### Task 3: Implement Ollama DTOs

**Objective:** Define Codable request/response structs compatible with core Ollama endpoints.

**Files:**
- Modify: `swift/Sources/MLXVLMOllama/OllamaDTOs.swift`
- Test: `swift/Tests/MLXVLMOllamaTests/OllamaDTOTests.swift`

**Endpoints covered by DTOs:**
- `POST /api/generate`
- `POST /api/chat`
- `GET /api/tags`
- `POST /api/show`
- `GET /api/ps`
- `GET /api/version`

### Task 4: Add model alias store

**Objective:** Provide Ollama-style names while preserving source model IDs/local paths.

**Files:**
- Create/Modify: `swift/Sources/MLXVLMCore/ModelAlias.swift`
- Test: `swift/Tests/MLXVLMCompatTests/ModelAliasTests.swift`

**Example mapping:**
```json
{
  "name": "qwen2.5-vl:3b",
  "source": "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
  "model_type": "qwen2_5_vl"
}
```

### Task 5: Add server shell routes

**Objective:** Add a compile-time-light server abstraction that documents intended routes before binding to Vapor/Hummingbird.

**Files:**
- Modify: `swift/Sources/MLXVLMServer/ServerShell.swift`

**Routes:**
- `/api/generate`
- `/api/chat`
- `/api/tags`
- `/api/show`
- `/api/ps`
- `/api/version`
- `/v1/chat/completions` future OpenAI compatibility
- `/v1/models` future OpenAI compatibility
- `/` static UI

### Task 6: Add static Web UI prototype

**Objective:** Provide a small Ollama-style UI that can later call the Swift server.

**Files:**
- Create: `swift/UI/Web/index.html`
- Create: `swift/UI/Web/app.js`
- Create: `swift/UI/Web/styles.css`

**Initial UI:**
- Model alias input/select
- Prompt textarea
- Image upload field
- Stream checkbox
- Generate button
- Response panel
- API endpoint hints

## Phase 2 Tasks: Runtime Integration

### Task 7: Add MLX Swift dependencies

**Objective:** Wire `mlx-swift-lm` and MLX packages once the Swift toolchain is available locally/CI.

**Files:**
- Modify: `swift/Package.swift`

**Dependencies:**
- `https://github.com/ml-explore/mlx-swift.git`
- `https://github.com/ml-explore/mlx-swift-lm.git`

### Task 8: Implement core generate bridge

**Objective:** Bridge Ollama/OpenAI request DTOs to MLXVLM `loadModel` and `ChatSession`.

**Files:**
- Create: `swift/Sources/MLXVLMCore/GenerateEngine.swift`
- Create: `swift/Sources/MLXVLMCore/RuntimeSession.swift`

**Verification:** Compare one image prompt against Python `mlx_vlm.generate` with temperature 0.

## Phase 3 Tasks: Parity and Hardening

### Task 9: Add Python/Swift parity fixtures

**Objective:** Store golden request fixtures, not model weights, for cross-runtime parity.

**Files:**
- Create: `swift/Tests/Fixtures/ollama_generate_image.json`
- Create: `swift/Tests/Fixtures/openai_chat_image.json`

### Task 10: Document support matrix

**Objective:** Make model compatibility explicit.

**Files:**
- Create: `swift/README.md`

**Include:** supported model types, unsupported behavior, CLI examples, Ollama API examples, UI instructions.

---

## Initial Endpoint Mapping

### Ollama `/api/generate`

Input fields:
- `model` -> alias or source model ID
- `prompt` -> user text
- `images` -> base64 image inputs
- `stream` -> JSONL streaming if true
- `options.num_predict` -> `max_tokens`
- `options.temperature` -> `temperature`
- `options.top_p` -> `top_p`

### Ollama `/api/chat`

Input fields:
- `model` -> alias or source model ID
- `messages[].role` -> chat role
- `messages[].content` -> text
- `messages[].images` -> image inputs on message
- `stream` -> JSONL streaming if true

## Verification Commands

When Swift is installed:

```bash
cd swift
swift test
swift run mlx-vlm-swift routes
swift run mlx-vlm-swift generate --model mlx-community/Qwen2.5-VL-3B-Instruct-4bit --prompt "hello"
```

Python parity baseline:

```bash
python -m mlx_vlm.generate \
  --model mlx-community/Qwen2.5-VL-3B-Instruct-4bit \
  --image test.jpg \
  --prompt "Describe this image" \
  --temperature 0.0 \
  --max-tokens 32
```

## Stop Conditions

Do not claim full runtime completion until:

- Swift toolchain is available and `swift test` passes.
- At least one existing MLX VLM model loads through Swift runtime.
- Ollama `/api/generate` works with non-streaming and streaming JSONL.
- UI can call the local server and render output.
