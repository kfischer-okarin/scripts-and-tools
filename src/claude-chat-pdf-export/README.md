# `claude-chat-pdf-export`

Exports a Claude.ai conversation as a printable PDF. Contains:

- A **Chrome extension** that adds a floating "PDF" button to any
  `claude.ai/chat/*` page. Clicking it opens a print-ready tab with Chrome's
  print dialog; pick *Save as PDF*.
- A **Node CLI** (`render.mjs`) that turns a conversation JSON into a
  standalone HTML file, intended to be paired with headless Chrome for
  fully unattended PDF export.

Both share the same renderer (`extension/renderer.js`), which converts
Claude.ai's conversation JSON (`text`, `thinking`, `tool_use`,
`tool_result` blocks) into structured HTML with print-friendly CSS.

## Install the Chrome extension

1. `npm install && npm run build` — this copies the bundled `marked` into
   `extension/lib/` (which is gitignored, so the build step is required
   after a fresh checkout).
2. Open `chrome://extensions`
3. Enable *Developer mode* (top right)
4. *Load unpacked* → select this repo's `src/claude-chat-pdf-export/extension`
5. Open any `claude.ai/chat/<id>` page — the dark **PDF** pill appears in
   the bottom-right corner.

The extension calls Claude.ai's internal API (`/api/organizations/.../chat_conversations/<id>`)
from the page context, so it inherits your logged-in session. It does not
send your data anywhere; the rendered HTML is built locally and opened
via a `blob:` URL in a new tab.

## Use the CLI (manual export)

You need a conversation JSON. The easiest way to grab one is from the
DevTools console of an open chat page:

```js
const orgId = (await (await fetch('/api/organizations')).json())[0].uuid;
const convId = location.pathname.split('/').pop();
const data = await (await fetch(
  `/api/organizations/${orgId}/chat_conversations/${convId}?tree=True&rendering_mode=messages&render_all_tools=true`
)).json();
const a = document.createElement('a');
a.href = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
a.download = 'conv.json';
a.click();
```

(If you have multiple Claude organizations, replace `orgs[0]` with the one
that owns the chat.)

Then:

```bash
cd src/claude-chat-pdf-export
npm install
node render.mjs /path/to/conv.json /path/to/out.html

# Convert to PDF via headless Chrome
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=/path/to/out.pdf "file:///path/to/out.html"
```

## How the renderer treats each block type

- **`text`** — passed through `marked` (GFM). Code blocks, lists, tables,
  blockquotes, inline code, links all render.
- **`thinking`** — inside a `<details>` element, italic styling. Collapsed
  by default on screen; hidden in print.
- **`tool_use`** — `<details>` block with the tool name and JSON input.
- **`tool_result`** — `<details>` block with the result text; flagged red
  when `is_error: true`.

A tiny rule in the print stylesheet hides un-opened `<details>` so the
PDF doesn't bloat with collapsed-but-still-printed content. If you want
thinking blocks in the PDF, open them in the print preview before saving.

## Stability caveat

The internal API (`/api/organizations/.../chat_conversations/...`) is the
same surface the official web app uses, so it's usually stable, but it
isn't documented or versioned. If Anthropic changes the shape, the
extension will fail — open an issue or update `renderer.js`.
