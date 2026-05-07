import Foundation
import MLXVLMCore
import MLXVLMOllama

public struct OllamaHTTPRouter: Sendable {
    private let runtimeHandler: OllamaRuntimeHandler
    private let aliases: ModelAliasStore
    private let version: String

    public init(
        runtimeHandler: OllamaRuntimeHandler = OllamaRuntimeHandler(runtime: UnimplementedVLMRuntime()),
        aliases: ModelAliasStore = ModelAliasStore(),
        version: String = "mlx-vlm-swift-compat"
    ) {
        self.runtimeHandler = runtimeHandler
        self.aliases = aliases
        self.version = version
    }

    public func handle(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/api/version"):
            return try HTTPResponse.json(OllamaVersionResponse(version: version), encoder: .ollama)
        case ("GET", "/api/tags"):
            return try HTTPResponse.json(OllamaAdapter.tagsResponse(from: aliases.aliases, createdAt: OllamaRuntimeHandler.iso8601Now()), encoder: .ollama)
        case ("GET", "/api/ps"):
            return try HTTPResponse.json(OllamaRunningModelsResponse(models: []), encoder: .ollama)
        case ("POST", "/api/show"):
            return try handleShow(request)
        case ("POST", "/api/generate"):
            return try await handleGenerate(request)
        case ("POST", "/api/chat"):
            return try await handleChat(request)
        case ("GET", "/"):
            return HTTPResponse.text(Self.webUIHTML, contentType: "text/html; charset=utf-8")
        default:
            return HTTPResponse.notFound()
        }
    }

    private func handleGenerate(_ httpRequest: HTTPRequest) async throws -> HTTPResponse {
        let request = try JSONDecoder.ollama.decode(OllamaGenerateRequest.self, from: httpRequest.body)
        if request.stream == true {
            var lines: [String] = []
            for try await chunk in runtimeHandler.generateStream(request) {
                let encoded = try JSONEncoder.ollama.encode(chunk)
                lines.append(String(decoding: encoded, as: UTF8.self))
            }
            return HTTPResponse(
                statusCode: 200,
                headers: ["content-type": "application/x-ndjson"],
                body: Data((lines.joined(separator: "\n") + "\n").utf8)
            )
        }

        return try await HTTPResponse.json(runtimeHandler.generate(request), encoder: .ollama)
    }

    private func handleChat(_ httpRequest: HTTPRequest) async throws -> HTTPResponse {
        let request = try JSONDecoder.ollama.decode(OllamaChatRequest.self, from: httpRequest.body)
        if request.stream == true {
            var lines: [String] = []
            for try await chunk in runtimeHandler.chatStream(request) {
                let encoded = try JSONEncoder.ollama.encode(chunk)
                lines.append(String(decoding: encoded, as: UTF8.self))
            }
            return HTTPResponse(
                statusCode: 200,
                headers: ["content-type": "application/x-ndjson"],
                body: Data((lines.joined(separator: "\n") + "\n").utf8)
            )
        }

        return try await HTTPResponse.json(runtimeHandler.chat(request), encoder: .ollama)
    }

    private func handleShow(_ httpRequest: HTTPRequest) throws -> HTTPResponse {
        let request = try JSONDecoder.ollama.decode(OllamaShowRequest.self, from: httpRequest.body)
        let tags = OllamaAdapter.tagsResponse(from: aliases.aliases, createdAt: OllamaRuntimeHandler.iso8601Now()).models
        if let tag = tags.first(where: { $0.name == request.model || $0.digest == request.model }) {
            return try HTTPResponse.json(tag, encoder: .ollama)
        }

        let source = aliases.resolveSourceOrIdentity(request.model)
        let fallback = OllamaModelTag(
            name: request.model,
            model: request.model,
            modifiedAt: OllamaRuntimeHandler.iso8601Now(),
            size: 0,
            digest: source,
            details: OllamaModelDetails(family: "unknown", families: ["unknown"])
        )
        return try HTTPResponse.json(fallback, encoder: .ollama)
    }

    private static let webUIHTML = """
    <!doctype html>
    <html lang="ko">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>MLX-VLM Swift</title>
      <style>
        :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #080a0f; color: #f7f7fb; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; background: radial-gradient(circle at top left, #1c2a4a, transparent 36rem), #080a0f; }
        main { width: min(980px, calc(100vw - 32px)); margin: 0 auto; padding: 48px 0; }
        .hero { margin-bottom: 24px; }
        h1 { margin: 0 0 8px; font-size: clamp(2rem, 5vw, 4rem); letter-spacing: -0.05em; }
        p { color: #aab3c5; line-height: 1.6; }
        .panel { background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.12); border-radius: 24px; padding: 20px; box-shadow: 0 24px 80px rgba(0,0,0,.35); }
        label { display: block; color: #d7def0; font-weight: 700; margin: 14px 0 8px; }
        input, textarea, select, button { width: 100%; border: 1px solid rgba(255,255,255,.14); border-radius: 14px; background: rgba(0,0,0,.35); color: #f7f7fb; padding: 12px 14px; font: inherit; }
        textarea { min-height: 140px; resize: vertical; }
        button { margin-top: 16px; border: 0; background: linear-gradient(135deg, #6ea8ff, #a78bfa); color: #07111f; font-weight: 800; cursor: pointer; }
        button:disabled { opacity: .55; cursor: wait; }
        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .output { white-space: pre-wrap; min-height: 160px; margin-top: 16px; padding: 16px; border-radius: 16px; background: rgba(0,0,0,.42); border: 1px solid rgba(255,255,255,.1); }
        .muted { color: #8792a8; font-size: .92rem; }
        @media (max-width: 720px) { .grid { grid-template-columns: 1fr; } }
      </style>
    </head>
    <body>
      <main>
        <section class="hero">
          <h1>MLX-VLM Swift</h1>
          <p>기존 MLX/HuggingFace 모델을 그대로 쓰는 Swift VLM runtime + Ollama-compatible local UI.</p>
        </section>
        <section class="panel">
          <label for="model">Model</label>
          <select id="model"></select>
          <p class="muted">모델 목록은 <code>/api/tags</code>에서 불러오고, 요청은 <code>/api/generate</code>로 전송돼.</p>

          <label for="prompt">Prompt</label>
          <textarea id="prompt">Describe this image or answer the question.</textarea>

          <label for="image">Image optional</label>
          <input id="image" type="file" accept="image/*">

          <div class="grid">
            <div><label for="maxTokens">Max tokens</label><input id="maxTokens" type="number" value="128" min="1"></div>
            <div><label for="temperature">Temperature</label><input id="temperature" type="number" value="0" step="0.1"></div>
            <div><label for="topP">Top P</label><input id="topP" type="number" value="1" step="0.05"></div>
          </div>

          <button id="run">Generate</button>
          <div id="output" class="output">Ready.</div>
        </section>
      </main>
      <script>
        const $ = (id) => document.getElementById(id);
        async function fileToBase64(file) {
          if (!file) return null;
          const dataUrl = await new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(file);
          });
          return String(dataUrl).split(',')[1];
        }
        async function loadModels() {
          const res = await fetch('/api/tags');
          const data = await res.json();
          const select = $('model');
          select.innerHTML = '';
          for (const model of data.models || []) {
            const option = document.createElement('option');
            option.value = model.name;
            option.textContent = model.name;
            select.appendChild(option);
          }
          if (!select.children.length) {
            const option = document.createElement('option');
            option.value = 'mlx-community/Qwen2.5-VL-3B-Instruct-4bit';
            option.textContent = option.value;
            select.appendChild(option);
          }
        }
        async function runGenerate() {
          $('run').disabled = true;
          $('output').textContent = 'Running...';
          try {
            const image = await fileToBase64($('image').files[0]);
            const body = {
              model: $('model').value,
              prompt: $('prompt').value,
              stream: false,
              options: {
                num_predict: Number($('maxTokens').value || 128),
                temperature: Number($('temperature').value || 0),
                top_p: Number($('topP').value || 1)
              }
            };
            if (image) body.images = [image];
            const res = await fetch('/api/generate', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
            const text = await res.text();
            if (!res.ok) throw new Error(text);
            const data = JSON.parse(text);
            $('output').textContent = data.response || '';
          } catch (error) {
            $('output').textContent = 'Error: ' + error.message;
          } finally {
            $('run').disabled = false;
          }
        }
        $('run').addEventListener('click', runGenerate);
        loadModels().catch((error) => { $('output').textContent = 'Failed to load /api/tags: ' + error.message; });
      </script>
    </body>
    </html>
    """
}
