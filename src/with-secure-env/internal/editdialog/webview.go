//go:build darwin

package editdialog

import (
	"encoding/json"
	"runtime"

	webview "github.com/webview/webview_go"
)

type WebViewEditDialog struct{}

func (d *WebViewEditDialog) EditEnvs(applicationPath string, currentValues map[string]string) (map[string]string, bool) {
	runtime.LockOSThread()

	var result map[string]string
	ok := false

	w := webview.New(false)
	defer w.Destroy()

	w.SetTitle("Edit Environment Variables")
	w.SetSize(500, 400, webview.HintNone)

	w.Bind("save", func(data string) {
		json.Unmarshal([]byte(data), &result)
		ok = true
		w.Terminate()
	})

	w.Bind("cancel", func() {
		ok = false
		w.Terminate()
	})

	initialData, _ := json.Marshal(currentValues)
	html := buildHTML(applicationPath, string(initialData))
	w.SetHtml(html)

	w.Run()

	return result, ok
}

func buildHTML(applicationPath string, initialJSON string) string {
	return `<!DOCTYPE html>
<html>
<head>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
	font-family: -apple-system, BlinkMacSystemFont, sans-serif;
	padding: 20px;
	background: #f5f5f7;
}
h2 { font-size: 14px; color: #666; margin-bottom: 10px; }
.app-path {
	font-size: 12px;
	color: #999;
	margin-bottom: 20px;
	word-break: break-all;
}
.env-list { margin-bottom: 20px; }
.env-entry { margin-bottom: 10px; }
.env-header {
	display: flex;
	gap: 10px;
	align-items: center;
	margin-bottom: 5px;
}
label {
	font-size: 12px;
	color: #666;
}
input.key {
	padding: 6px 10px;
	border: 1px solid #ddd;
	border-radius: 6px;
	font-size: 14px;
	font-weight: 500;
}
textarea.value {
	width: 100%;
	padding: 8px 10px;
	border: 1px solid #ddd;
	border-radius: 6px;
	font-size: 13px;
	font-family: ui-monospace, monospace;
	resize: vertical;
	min-height: 50px;
}
hr {
	border: none;
	border-top: 1px solid #ddd;
	margin: 15px 0;
}
button {
	padding: 8px 16px;
	border: none;
	border-radius: 6px;
	cursor: pointer;
	font-size: 14px;
}
.remove-btn { background: #ff3b30; color: white; padding: 6px 12px; }
.add-btn { background: #34c759; color: white; margin-bottom: 20px; }
.buttons { display: flex; gap: 10px; justify-content: flex-end; }
.cancel-btn { background: #8e8e93; color: white; }
.save-btn { background: #007aff; color: white; }
</style>
</head>
<body>
<h2>Environment Variables</h2>
<div class="app-path">` + applicationPath + `</div>
<div class="env-list" id="envList"></div>
<button class="add-btn" onclick="addRow()">+ Add Variable</button>
<div class="buttons">
	<button class="cancel-btn" onclick="doCancel()">Cancel</button>
	<button class="save-btn" onclick="doSave()">Save</button>
</div>
<script>
let envs = ` + initialJSON + `;

function escapeHtml(str) {
	return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function render() {
	const list = document.getElementById('envList');
	list.innerHTML = '';
	const entries = Object.entries(envs);
	entries.forEach(([key, value], index) => {
		const entry = document.createElement('div');
		entry.className = 'env-entry';
		entry.innerHTML = ` + "`" + `
			<div class="env-header">
				<label>Name</label>
				<input class="key" value="${escapeHtml(key)}" onchange="updateKey(this, '${escapeHtml(key)}')" placeholder="VAR_NAME">
				<button class="remove-btn" onclick="removeRow('${escapeHtml(key)}')">×</button>
			</div>
			<label>Value</label>
			<textarea class="value" oninput="updateValue('${escapeHtml(key)}', this.value)" placeholder="value">${escapeHtml(value)}</textarea>
		` + "`" + `;
		list.appendChild(entry);
		if (index < entries.length - 1) {
			list.appendChild(document.createElement('hr'));
		}
	});
}

function addRow() {
	let i = 1;
	while (envs['NEW_VAR_' + i]) i++;
	envs['NEW_VAR_' + i] = '';
	render();
}

function removeRow(key) {
	delete envs[key];
	render();
}

function updateKey(input, oldKey) {
	const newKey = input.value;
	if (newKey && newKey !== oldKey) {
		envs[newKey] = envs[oldKey];
		delete envs[oldKey];
		render();
	}
}

function updateValue(key, value) {
	envs[key] = value;
}

function doSave() {
	window.save(JSON.stringify(envs)).then(() => {});
}

function doCancel() {
	window.cancel().then(() => {});
}

render();
</script>
</body>
</html>`
}
