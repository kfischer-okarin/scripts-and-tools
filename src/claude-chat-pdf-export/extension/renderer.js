// Pure renderer: Claude.ai conversation JSON -> standalone HTML string.
// Works in both Node and browser. The caller supplies a markdown function
// (e.g. `marked.parse`) so this file has no module-system assumptions.

(function (root, factory) {
  const mod = factory();
  if (typeof module !== "undefined" && module.exports) module.exports = mod;
  else root.ClaudeChatRenderer = mod;
})(typeof self !== "undefined" ? self : globalThis, function () {
  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function linearChain(conv) {
    const byId = Object.fromEntries(conv.chat_messages.map((m) => [m.uuid, m]));
    const chain = [];
    let cur = byId[conv.current_leaf_message_uuid];
    while (cur) {
      chain.unshift(cur);
      cur = cur.parent_message_uuid ? byId[cur.parent_message_uuid] : null;
    }
    return chain;
  }

  function formatTimestamp(iso) {
    if (!iso) return "";
    const d = new Date(iso);
    return d.toLocaleString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function renderTextBlock(block, mdToHtml) {
    return `<div class="block block-text">${mdToHtml(block.text || "")}</div>`;
  }

  function renderThinkingBlock(block, mdToHtml) {
    return `
      <details class="block block-thinking">
        <summary>Thinking</summary>
        <div class="thinking-body">${mdToHtml(block.thinking || "")}</div>
      </details>`;
  }

  // File-system style tools that get rendered as inline status pills
  // ("Claude updated character_sheet.md") instead of collapsed details.
  const FILE_TOOL_ACTIONS = {
    create_file: { verb: "created", icon: "📄" },
    str_replace: { verb: "updated", icon: "✏️" },
    artifacts: { verb: "updated artifact", icon: "🧩" },
  };

  function basename(path) {
    if (!path) return "";
    return String(path).split("/").filter(Boolean).pop() || "";
  }

  function filenamesFromInput(input) {
    if (!input) return [];
    if (Array.isArray(input.filepaths)) return input.filepaths.map(basename);
    if (input.path) return [basename(input.path)];
    if (input.title) return [String(input.title)];
    return [];
  }

  function renderFileToolStatus(block) {
    const action = FILE_TOOL_ACTIONS[block.name];
    const names = filenamesFromInput(block.input);
    const fileText = names.map((n) => `<code>${escapeHtml(n)}</code>`).join(", ");
    const desc = block.input?.description ? ` — ${escapeHtml(block.input.description)}` : "";
    const time = block.stop_timestamp || block.start_timestamp;
    return `
      <div class="status-pill">
        <span class="status-icon">${action.icon}</span>
        <span class="status-text">${action.verb} ${fileText}${desc}</span>
        ${time ? `<time class="status-time">${escapeHtml(formatTimestamp(time))}</time>` : ""}
      </div>`;
  }

  function renderToolUseBlock(block) {
    if (FILE_TOOL_ACTIONS[block.name]) return renderFileToolStatus(block);
    const name = escapeHtml(block.name || "tool");
    const message = escapeHtml(block.message || "");
    const input = block.input ? JSON.stringify(block.input, null, 2) : "";
    return `
      <details class="block block-tool-use">
        <summary><span class="tool-icon">🔧</span> ${name}${message ? ` — ${message}` : ""}</summary>
        ${input ? `<pre class="tool-input"><code>${escapeHtml(input)}</code></pre>` : ""}
      </details>`;
  }

  function renderToolResultBlock(block, ctx) {
    const isError = !!block.is_error;
    // Successful file-tool results add no information — hide them.
    if (!isError && ctx && ctx.fileToolUseIds.has(block.tool_use_id)) return "";
    const name = escapeHtml(block.name || "tool");
    const parts = (block.content || []).map((c) => {
      if (c.type === "text") return escapeHtml(c.text || "");
      return escapeHtml(JSON.stringify(c, null, 2));
    });
    const body = parts.join("\n");
    return `
      <details class="block block-tool-result${isError ? " is-error" : ""}">
        <summary><span class="tool-icon">↩</span> ${name} result${isError ? " (error)" : ""}</summary>
        <pre class="tool-result-body"><code>${body}</code></pre>
      </details>`;
  }

  function renderContent(content, mdToHtml, ctx) {
    return (content || [])
      .map((block) => {
        switch (block.type) {
          case "text": return renderTextBlock(block, mdToHtml);
          case "thinking": return renderThinkingBlock(block, mdToHtml);
          case "tool_use": return renderToolUseBlock(block);
          case "tool_result": return renderToolResultBlock(block, ctx);
          default: return `<div class="block block-unknown">[${escapeHtml(block.type)}]</div>`;
        }
      })
      .join("\n");
  }

  function formatBytes(n) {
    if (!n && n !== 0) return "";
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${Math.round(n / 102.4) / 10} KB`;
    return `${Math.round(n / (1024 * 102.4)) / 10} MB`;
  }

  function renderAttachments(files) {
    if (!files || files.length === 0) return "";
    const chips = files
      .map((f) => {
        const name = escapeHtml(f.file_name || f.path || "file");
        const size = f.size_bytes ? `<span class="file-size">${formatBytes(f.size_bytes)}</span>` : "";
        return `<span class="file-chip">📎 <span class="file-name">${name}</span> ${size}</span>`;
      })
      .join("");
    return `<div class="attachments">${chips}</div>`;
  }

  function buildCtx(msg) {
    const fileToolUseIds = new Set();
    for (const block of msg.content || []) {
      if (block.type === "tool_use" && FILE_TOOL_ACTIONS[block.name]) {
        fileToolUseIds.add(block.id);
      }
    }
    return { fileToolUseIds };
  }

  function renderMessage(msg, mdToHtml) {
    const role = msg.sender === "human" ? "user" : "assistant";
    const label = role === "user" ? "You" : "Claude";
    const ctx = buildCtx(msg);
    return `
      <article class="turn turn-${role}">
        <header class="turn-header">
          <span class="turn-role">${label}</span>
          <time class="turn-time">${escapeHtml(formatTimestamp(msg.created_at))}</time>
        </header>
        <div class="turn-body">
          ${renderAttachments(msg.files)}
          ${renderContent(msg.content, mdToHtml, ctx)}
        </div>
      </article>`;
  }

  function styles() {
    return `
      @page { size: A4; margin: 18mm 14mm; }
      * { box-sizing: border-box; }
      html, body {
        font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans",
                     "Noto Sans CJK JP", "Yu Gothic", "Segoe UI", sans-serif;
        font-size: 11pt;
        line-height: 1.55;
        color: #1f2024;
        background: #fff;
        margin: 0;
      }
      .doc { max-width: 720px; margin: 0 auto; padding: 24px 0; }
      .doc-header { border-bottom: 1px solid #d8d8db; margin-bottom: 18px; padding-bottom: 10px; }
      .doc-title { font-size: 18pt; font-weight: 700; margin: 0 0 4px; }
      .doc-meta { color: #6b6c70; font-size: 10pt; }
      .turn {
        display: flex; flex-direction: column;
        margin: 14px 0;
      }
      .turn-user { align-items: flex-end; }
      .turn-assistant { align-items: flex-start; }
      .turn-header {
        display: flex; gap: 10px; align-items: baseline;
        font-size: 9.5pt; color: #6b6c70; margin: 0 6px 4px;
        page-break-after: avoid;
      }
      .turn-role { font-weight: 600; color: #1f2024; }
      .turn-user .turn-role { color: #1e64c8; }
      .turn-assistant .turn-role { color: #b35a1a; }
      .turn-time { color: #9b9c9f; font-size: 8.5pt; }
      .turn-body {
        max-width: 90%;
        padding: 10px 14px;
        border-radius: 16px;
        box-sizing: border-box;
      }
      .turn-user .turn-body {
        background: #e3edfb;
        border-bottom-right-radius: 4px;
      }
      .turn-assistant .turn-body {
        background: #f2f2f4;
        border-bottom-left-radius: 4px;
      }
      .turn-body > .block:first-child > :first-child { margin-top: 0; }
      .turn-body > .block:last-child > :last-child { margin-bottom: 0; }
      .attachments {
        display: flex; flex-wrap: wrap; gap: 6px;
        margin-bottom: 8px;
      }
      .file-chip {
        display: inline-flex; align-items: baseline; gap: 6px;
        background: rgba(255,255,255,0.6);
        border: 1px solid rgba(0,0,0,0.08);
        padding: 3px 9px; border-radius: 999px;
        font-size: 9.5pt;
      }
      .turn-assistant .file-chip { background: #fff; }
      .file-name { font-weight: 600; }
      .file-size { color: #6b6c70; font-size: 9pt; }
      .status-pill {
        display: inline-flex; align-items: baseline; gap: 8px;
        margin: 4px 0;
        padding: 4px 10px;
        background: rgba(0,0,0,0.04);
        border: 1px dashed rgba(0,0,0,0.15);
        border-radius: 999px;
        font-size: 9.5pt; color: #4a4b50;
      }
      .status-icon { font-size: 10pt; }
      .status-time { color: #9b9c9f; font-size: 8.5pt; margin-left: auto; }
      .status-pill code {
        background: rgba(0,0,0,0.06); padding: 0 4px; border-radius: 3px;
        font-family: "SF Mono", "Menlo", "Consolas", monospace;
      }
      .block { margin: 6px 0; }
      .block-text p { margin: 0.4em 0; }
      .block-text h1, .block-text h2, .block-text h3, .block-text h4 {
        margin: 1em 0 0.4em; line-height: 1.3;
      }
      .block-text ul, .block-text ol { margin: 0.4em 0; padding-left: 22px; }
      .block-text li { margin: 0.15em 0; }
      .block-text code {
        background: #f1f1f3; padding: 1px 4px; border-radius: 3px;
        font-family: "SF Mono", "Menlo", "Consolas", monospace; font-size: 10pt;
      }
      .block-text pre {
        background: #f6f6f8; padding: 10px 12px; border-radius: 6px;
        overflow-x: auto; font-size: 9.5pt; line-height: 1.45;
        page-break-inside: avoid;
      }
      .block-text pre code { background: transparent; padding: 0; font-size: inherit; }
      .block-text blockquote {
        margin: 0.4em 0; padding: 0.2em 12px; border-left: 3px solid #d0d0d4;
        color: #4a4b50;
      }
      .block-text a { color: #1e64c8; text-decoration: underline; }
      .block-text table { border-collapse: collapse; margin: 0.4em 0; }
      .block-text th, .block-text td { border: 1px solid #d8d8db; padding: 4px 8px; }
      .block-thinking, .block-tool-use, .block-tool-result {
        background: #f7f7fa; border: 1px solid #e3e3e7; border-radius: 5px;
        padding: 6px 10px; font-size: 9.5pt; color: #4a4b50;
      }
      .block-thinking { font-style: italic; }
      .block-thinking summary, .block-tool-use summary, .block-tool-result summary {
        font-weight: 600; cursor: pointer; font-style: normal;
      }
      .block-tool-result.is-error { border-color: #f0c4c0; background: #fcf3f2; }
      .tool-icon { display: inline-block; margin-right: 4px; }
      .tool-input, .tool-result-body {
        background: #fff; padding: 8px 10px; border-radius: 4px;
        border: 1px solid #e6e6ea; overflow-x: auto; margin: 6px 0 0;
        white-space: pre-wrap; word-break: break-word;
      }
      details[open] > summary { margin-bottom: 6px; }
      @media print {
        details:not([open]) { display: none; }
        details[open] > summary { list-style: none; }
        details[open] > summary::-webkit-details-marker { display: none; }
      }
    `;
  }

  function renderConversation(conv, mdToHtml) {
    if (typeof mdToHtml !== "function") {
      throw new Error("renderConversation requires a markdown->HTML function");
    }
    const chain = linearChain(conv);
    const title = escapeHtml(conv.name || "Claude conversation");
    const meta = [
      conv.model && `model: ${conv.model}`,
      conv.created_at && `created: ${formatTimestamp(conv.created_at)}`,
      `${chain.length} messages`,
    ]
      .filter(Boolean)
      .map(escapeHtml)
      .join(" · ");
    const body = chain.map((m) => renderMessage(m, mdToHtml)).join("\n");
    return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>${title}</title>
<style>${styles()}</style>
</head>
<body>
<main class="doc">
<header class="doc-header">
  <h1 class="doc-title">${title}</h1>
  <div class="doc-meta">${meta}</div>
</header>
${body}
</main>
</body>
</html>`;
  }

  return { renderConversation, linearChain };
});
