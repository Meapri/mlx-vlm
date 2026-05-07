import Foundation
import MLXVLMCore
import MLXVLMOllama

public struct OllamaHTTPRouter: Sendable {
    private let runtimeHandler: OllamaRuntimeHandler
    private let aliases: ModelAliasStore
    private let version: String
    private let settingsStore: SettingsStore

    public init(
        runtimeHandler: OllamaRuntimeHandler = OllamaRuntimeHandler(runtime: UnimplementedVLMRuntime()),
        aliases: ModelAliasStore = ModelAliasStore(),
        version: String = "mlx-vlm-swift-compat",
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.runtimeHandler = runtimeHandler
        self.aliases = aliases
        self.version = version
        self.settingsStore = settingsStore
    }

    public func handle(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/api/version"):
            return try HTTPResponse.json(OllamaVersionResponse(version: version), encoder: .ollama)
        case ("GET", "/api/tags"):
            return try HTTPResponse.json(OllamaAdapter.tagsResponse(from: aliases.aliases, createdAt: OllamaRuntimeHandler.iso8601Now()), encoder: .ollama)
        case ("GET", "/api/ps"):
            return try await handleRunningModels()
        case ("POST", "/api/show"):
            return try handleShow(request)
        case ("POST", "/api/generate"):
            return try await handleGenerate(request)
        case ("POST", "/api/chat"):
            return try await handleChat(request)
        case ("GET", "/"):
            return HTTPResponse.text(Self.settingsUIHTML, contentType: "text/html; charset=utf-8")
        case ("GET", "/mlx-vlm/settings"):
            return try handleGetSettings()
        case ("PUT", "/mlx-vlm/settings"), ("POST", "/mlx-vlm/settings"):
            return try handleSaveSettings(request)
        case ("GET", "/mlx-vlm/status"):
            return try await handleStatus()
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

    private func handleRunningModels() async throws -> HTTPResponse {
        let loadedModels = await runtimeHandler.loadedModelSources()
        let tags = loadedModels.map { source in
            OllamaModelTag(
                name: source,
                model: source,
                modifiedAt: OllamaRuntimeHandler.iso8601Now(),
                size: 0,
                digest: source,
                details: OllamaModelDetails(family: "vlm", families: ["vlm"])
            )
        }
        return try HTTPResponse.json(OllamaRunningModelsResponse(models: tags), encoder: .ollama)
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

    private func handleGetSettings() throws -> HTTPResponse {
        try HTTPResponse.json(settingsStore.loadOrCreateDefault(), encoder: .settings)
    }

    private func handleSaveSettings(_ httpRequest: HTTPRequest) throws -> HTTPResponse {
        let settings = try JSONDecoder.settings.decode(RuntimeSettings.self, from: httpRequest.body)
        try settingsStore.save(settings)
        return try HTTPResponse.json(settings, encoder: .settings)
    }

    private func handleStatus() async throws -> HTTPResponse {
        let settings = try settingsStore.loadOrCreateDefault()
        let loadedModels = await runtimeHandler.loadedModelSources()
        return try HTTPResponse.json(
            RuntimeStatus(
                version: version,
                configPath: settingsStore.configURL.path,
                serverRunning: true,
                ollamaAPIEnabled: settings.ollamaAPIEnabled,
                openAIAPIEnabled: settings.openAIAPIEnabled,
                loadedModels: loadedModels
            ),
            encoder: .settings
        )
    }

    private static let settingsUIHTML = """
    <!doctype html>
    <html lang="ko">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>MLX-VLM Swift Settings</title>
      <style>
        :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #080a0f; color: #f7f7fb; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; background: radial-gradient(circle at top left, #21345f, transparent 34rem), #080a0f; }
        main { width: min(1040px, calc(100vw - 32px)); margin: 0 auto; padding: 42px 0; }
        h1 { margin: 0 0 8px; font-size: clamp(2rem, 5vw, 3.8rem); letter-spacing: -0.05em; }
        p { color: #aab3c5; line-height: 1.6; }
        .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; }
        .panel { background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.12); border-radius: 24px; padding: 20px; box-shadow: 0 24px 80px rgba(0,0,0,.35); }
        label { display: block; color: #d7def0; font-weight: 700; margin: 14px 0 8px; }
        input, textarea, button { width: 100%; border: 1px solid rgba(255,255,255,.14); border-radius: 14px; background: rgba(0,0,0,.35); color: #f7f7fb; padding: 12px 14px; font: inherit; }
        input[type="checkbox"] { width: auto; margin-right: 8px; }
        textarea { min-height: 160px; resize: vertical; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
        button { margin-top: 16px; border: 0; background: linear-gradient(135deg, #6ea8ff, #a78bfa); color: #07111f; font-weight: 800; cursor: pointer; }
        .muted { color: #8792a8; font-size: .92rem; }
        .status { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 18px 0; }
        .pill { padding: 12px; border-radius: 16px; background: rgba(0,0,0,.35); border: 1px solid rgba(255,255,255,.1); }
        .pill strong { display: block; margin-bottom: 4px; }
        @media (max-width: 820px) { .grid, .status { grid-template-columns: 1fr; } }
      </style>
    </head>
    <body>
      <main>
        <h1>MLX-VLM Swift Settings</h1>
        <p>런타임, 서버, 모델 alias, 기본 generation 값을 관리하는 로컬 설정 UI야. 설정은 <code>/mlx-vlm/settings</code>에 저장돼.</p>
        <section class="status">
          <div class="pill"><strong>Server</strong><span id="serverState">loading</span></div>
          <div class="pill"><strong>Config</strong><span id="configPath">loading</span></div>
          <div class="pill"><strong>Version</strong><span id="version">loading</span></div>
        </section>
        <section class="grid">
          <div class="panel">
            <h2>Server</h2>
            <label for="host">Host</label>
            <input id="host" value="127.0.0.1">
            <label for="port">Port</label>
            <input id="port" type="number" value="11434">
            <label><input id="ollamaAPIEnabled" type="checkbox"> Ollama API enabled</label>
            <label><input id="openAIAPIEnabled" type="checkbox"> OpenAI API enabled</label>
          </div>
          <div class="panel">
            <h2>Runtime defaults</h2>
            <label for="defaultModel">Default model</label>
            <input id="defaultModel" placeholder="qwen2.5-vl:3b or mlx-community/...">
            <label for="modelCacheDirectory">Model cache directory</label>
            <input id="modelCacheDirectory" placeholder="optional">
            <label><input id="keepModelLoaded" type="checkbox"> Keep model loaded</label>
          </div>
          <div class="panel">
            <h2>Generation</h2>
            <label for="defaultMaxTokens">Max tokens</label>
            <input id="defaultMaxTokens" type="number" value="128">
            <label for="defaultTemperature">Temperature</label>
            <input id="defaultTemperature" type="number" step="0.1" value="0">
            <label for="defaultTopP">Top P</label>
            <input id="defaultTopP" type="number" step="0.05" value="1">
          </div>
          <div class="panel">
            <h2>Model aliases</h2>
            <p class="muted">JSON 배열 형식. 기존 MLX/HF source는 변환하지 않고 alias만 추가해.</p>
            <textarea id="aliases"></textarea>
          </div>
        </section>
        <button id="save">Save settings</button>
        <p id="message" class="muted">Ready.</p>
      </main>
      <script>
        const $ = (id) => document.getElementById(id);
        function setValue(id, value) { const el = $(id); if (el.type === 'checkbox') el.checked = Boolean(value); else el.value = value ?? ''; }
        function readSettings() {
          return {
            host: $('host').value,
            port: Number($('port').value || 11434),
            default_model: $('defaultModel').value || null,
            model_cache_directory: $('modelCacheDirectory').value || null,
            default_max_tokens: Number($('defaultMaxTokens').value || 128),
            default_temperature: Number($('defaultTemperature').value || 0),
            default_top_p: Number($('defaultTopP').value || 1),
            keep_model_loaded: $('keepModelLoaded').checked,
            ollama_api_enabled: $('ollamaAPIEnabled').checked,
            open_ai_api_enabled: $('openAIAPIEnabled').checked,
            aliases: JSON.parse($('aliases').value || '[]')
          };
        }
        function applySettings(settings) {
          setValue('host', settings.host);
          setValue('port', settings.port);
          setValue('defaultModel', settings.default_model);
          setValue('modelCacheDirectory', settings.model_cache_directory);
          setValue('defaultMaxTokens', settings.default_max_tokens);
          setValue('defaultTemperature', settings.default_temperature);
          setValue('defaultTopP', settings.default_top_p);
          setValue('keepModelLoaded', settings.keep_model_loaded);
          setValue('ollamaAPIEnabled', settings.ollama_api_enabled);
          setValue('openAIAPIEnabled', settings.open_ai_api_enabled);
          $('aliases').value = JSON.stringify(settings.aliases || [], null, 2);
        }
        async function load() {
          const [settingsRes, statusRes] = await Promise.all([fetch('/mlx-vlm/settings'), fetch('/mlx-vlm/status')]);
          const settings = await settingsRes.json();
          const status = await statusRes.json();
          applySettings(settings);
          $('serverState').textContent = status.server_running ? 'running' : 'stopped';
          $('configPath').textContent = status.config_path;
          $('version').textContent = status.version;
        }
        async function save() {
          $('message').textContent = 'Saving...';
          const res = await fetch('/mlx-vlm/settings', { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(readSettings()) });
          const text = await res.text();
          if (!res.ok) throw new Error(text);
          applySettings(JSON.parse(text));
          $('message').textContent = 'Saved. Restart server to apply host/port changes.';
        }
        $('save').addEventListener('click', () => save().catch((error) => { $('message').textContent = 'Error: ' + error.message; }));
        load().catch((error) => { $('message').textContent = 'Failed to load /mlx-vlm/settings: ' + error.message; });
      </script>
    </body>
    </html>
    """
}
