//go:build darwin

package permissiondialog

import (
	"encoding/json"
	"runtime"
	"strconv"

	webview "github.com/webview/webview_go"
)

type WebViewPermissionDialog struct{}

func (d *WebViewPermissionDialog) AskPermission(applicationPath string, args []string, envNames []string, caller CallerInfo) bool {
	runtime.LockOSThread()

	allowed := false

	w := webview.New(false)
	defer w.Destroy()

	w.SetTitle("Permission Required")
	w.SetSize(700, 500, webview.HintNone)

	w.Bind("allow", func() {
		allowed = true
		w.Terminate()
	})

	w.Bind("deny", func() {
		allowed = false
		w.Terminate()
	})

	argsJSON, _ := json.Marshal(args)
	envNamesJSON, _ := json.Marshal(envNames)
	html := buildPermissionHTML(applicationPath, string(argsJSON), string(envNamesJSON), caller.Name, strconv.Itoa(caller.PID))
	w.SetHtml(html)

	w.Run()

	return allowed
}

func buildPermissionHTML(applicationPath string, argsJSON string, envNamesJSON string, callerName string, callerPID string) string {
	return `<!DOCTYPE html>
<html>
<head>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body {
	height: 100%;
	overflow: hidden;
}
body {
	font-family: -apple-system, BlinkMacSystemFont, sans-serif;
	background: #f5f5f7;
	display: flex;
	flex-direction: column;
}
.content {
	flex: 1;
	overflow-y: auto;
	padding: 20px;
	padding-bottom: 10px;
}
.header {
	display: flex;
	align-items: center;
	gap: 12px;
	margin-bottom: 16px;
}
.shield {
	width: 40px;
	height: 40px;
	background: #ff9500;
	border-radius: 8px;
	display: flex;
	align-items: center;
	justify-content: center;
	font-size: 24px;
}
h1 {
	font-size: 18px;
	font-weight: 600;
	color: #1d1d1f;
}
.description {
	font-size: 13px;
	color: #666;
	margin-bottom: 20px;
	line-height: 1.4;
}
.section {
	background: white;
	border-radius: 8px;
	padding: 12px;
	margin-bottom: 12px;
}
.section-title {
	font-size: 11px;
	font-weight: 600;
	color: #8e8e93;
	text-transform: uppercase;
	letter-spacing: 0.5px;
	margin-bottom: 6px;
}
.section-content {
	font-size: 13px;
	color: #1d1d1f;
	word-break: break-all;
}
.section-content.mono {
	font-family: ui-monospace, monospace;
	font-size: 12px;
}
.env-list {
	display: flex;
	flex-wrap: wrap;
	gap: 6px;
}
.env-tag {
	background: #e5e5ea;
	padding: 4px 8px;
	border-radius: 4px;
	font-family: ui-monospace, monospace;
	font-size: 12px;
}
.caller-info {
	display: flex;
	gap: 20px;
}
.caller-item {
	display: flex;
	flex-direction: column;
}
.caller-label {
	font-size: 11px;
	color: #8e8e93;
}
.caller-value {
	font-size: 13px;
	color: #1d1d1f;
}
.buttons {
	display: flex;
	gap: 10px;
	justify-content: flex-end;
	padding: 16px 20px;
	background: #f5f5f7;
	border-top: 1px solid #ddd;
}
button {
	padding: 10px 20px;
	border: none;
	border-radius: 8px;
	cursor: pointer;
	font-size: 14px;
	font-weight: 500;
}
.deny-btn {
	background: #8e8e93;
	color: white;
}
.allow-btn {
	background: #34c759;
	color: white;
}
</style>
</head>
<body>
<div class="content">
	<div class="header">
		<div class="shield">🛡️</div>
		<h1>Permission Required</h1>
	</div>
	<p class="description">
		An application is requesting to launch with secure environment variables.
		Review the details below and decide whether to allow this action.
	</p>

	<div class="section">
		<div class="section-title">Requested By</div>
		<div class="caller-info">
			<div class="caller-item">
				<span class="caller-label">Process</span>
				<span class="caller-value">` + callerName + `</span>
			</div>
			<div class="caller-item">
				<span class="caller-label">PID</span>
				<span class="caller-value">` + callerPID + `</span>
			</div>
		</div>
	</div>

	<div class="section">
		<div class="section-title">Command</div>
		<div class="section-content mono" id="commandContent"></div>
	</div>

	<div class="section">
		<div class="section-title">Secrets to Inject</div>
		<div class="env-list" id="envList"></div>
	</div>
</div>

<div class="buttons">
	<button class="deny-btn" onclick="doDeny()">Deny</button>
	<button class="allow-btn" onclick="doAllow()">Allow</button>
</div>

<script>
const applicationPath = ` + "`" + applicationPath + "`" + `;
const args = ` + argsJSON + `;
const envNames = ` + envNamesJSON + `;

const commandParts = [applicationPath, ...args];
document.getElementById('commandContent').textContent = commandParts.join(' ');

const envList = document.getElementById('envList');
envNames.forEach(name => {
	const tag = document.createElement('span');
	tag.className = 'env-tag';
	tag.textContent = name;
	envList.appendChild(tag);
});

function doAllow() {
	window.allow().then(() => {});
}

function doDeny() {
	window.deny().then(() => {});
}
</script>
</body>
</html>`
}
