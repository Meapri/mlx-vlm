const $ = (id) => document.getElementById(id);

async function fileToBase64(file) {
  if (!file) return null;
  const dataUrl = await new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
  return String(dataUrl).split(',', 2)[1] ?? null;
}

async function appendStreamingResponse(response, output) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const chunk = JSON.parse(line);
        if (chunk.response) output.textContent += chunk.response;
        if (chunk.message?.content) output.textContent += chunk.message.content;
      } catch {
        output.textContent += line + '\n';
      }
    }
  }
}

async function generate() {
  const output = $('response');
  output.textContent = '';

  const image = await fileToBase64($('image').files[0]);
  const payload = {
    model: $('model').value.trim(),
    prompt: $('prompt').value,
    images: image ? [image] : undefined,
    stream: $('stream').checked,
    options: {
      temperature: Number($('temperature').value),
      num_predict: Number($('numPredict').value),
    },
  };

  output.textContent = 'Requesting /api/generate...\n';

  const response = await fetch('/api/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  output.textContent = '';
  if (!response.ok) {
    output.textContent = `HTTP ${response.status}: ${await response.text()}`;
    return;
  }

  if (payload.stream && response.body) {
    await appendStreamingResponse(response, output);
  } else {
    const json = await response.json();
    output.textContent = json.response ?? json.message?.content ?? JSON.stringify(json, null, 2);
  }
}

$('generate').addEventListener('click', () => {
  generate().catch((error) => {
    $('response').textContent = error.stack || String(error);
  });
});

$('clear').addEventListener('click', () => {
  $('response').textContent = '';
});
