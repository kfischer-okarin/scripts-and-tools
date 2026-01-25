package permissiondialog

// CallerInfo contains information about the process requesting to launch with secure envs.
type CallerInfo struct {
	Name string
	PID  int
}

// PermissionDialog asks the user for permission to inject environment variables.
type PermissionDialog interface {
	// AskPermission shows a dialog asking whether to inject the given env names
	// into the application. Returns true if the user grants permission.
	AskPermission(applicationPath string, args []string, envNames []string, caller CallerInfo) bool
}
