// Injects a "PDF" button into Claude.ai chat pages, fetches the
// conversation via the internal API (same-origin, uses your session cookie),
// then opens a print-ready tab and triggers the print dialog.

(function () {
  const BUTTON_ID = "claude-pdf-export-btn";

  function addButton() {
    if (document.getElementById(BUTTON_ID)) return;
    if (!/^\/chat\/[0-9a-f-]+/.test(location.pathname)) return;

    const btn = document.createElement("button");
    btn.id = BUTTON_ID;
    btn.type = "button";
    btn.textContent = "PDF";
    btn.title = "Export this conversation as PDF";
    Object.assign(btn.style, {
      position: "fixed",
      bottom: "16px",
      right: "16px",
      zIndex: "2147483647",
      padding: "8px 14px",
      borderRadius: "999px",
      border: "1px solid rgba(0,0,0,0.15)",
      background: "#1f2024",
      color: "#fff",
      fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
      fontSize: "13px",
      fontWeight: "600",
      cursor: "pointer",
      boxShadow: "0 2px 10px rgba(0,0,0,0.15)",
    });
    btn.addEventListener("click", onClick);
    document.body.appendChild(btn);
  }

  async function onClick() {
    const btn = document.getElementById(BUTTON_ID);
    const original = btn.textContent;
    btn.disabled = true;
    btn.textContent = "Exporting…";
    try {
      const conv = await fetchConversation();
      const html = buildPrintHtml(conv);
      openPrintTab(html);
    } catch (e) {
      console.error("[Claude Chat → PDF]", e);
      alert("Export failed: " + (e && e.message ? e.message : e));
    } finally {
      btn.disabled = false;
      btn.textContent = original;
    }
  }

  async function fetchConversation() {
    const convId = location.pathname.split("/").filter(Boolean).pop();
    const orgs = await fetch("/api/organizations", { credentials: "include" })
      .then((r) => r.json());
    if (!Array.isArray(orgs) || orgs.length === 0) {
      throw new Error("Could not load organizations");
    }
    const params = "tree=True&rendering_mode=messages&render_all_tools=true";
    for (const org of orgs) {
      const url = `/api/organizations/${org.uuid}/chat_conversations/${convId}?${params}`;
      const r = await fetch(url, { credentials: "include" });
      if (r.ok) return r.json();
    }
    throw new Error("Conversation not found in any of your organizations");
  }

  function buildPrintHtml(conv) {
    const html = ClaudeChatRenderer.renderConversation(conv, (md) => marked.parse(md));
    const autoPrint =
      '<script>addEventListener("load", () => setTimeout(() => window.print(), 300));</' + "script>";
    return html.replace("</body>", autoPrint + "\n</body>");
  }

  function openPrintTab(html) {
    const blob = new Blob([html], { type: "text/html" });
    const url = URL.createObjectURL(blob);
    window.open(url, "_blank");
  }

  addButton();
  new MutationObserver(() => addButton()).observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
})();
