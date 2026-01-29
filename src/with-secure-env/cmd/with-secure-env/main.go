//go:build darwin

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"

	ps "github.com/mitchellh/go-ps"

	"github.com/kfischer-okarin/with-secure-env/internal/editdialog"
	"github.com/kfischer-okarin/with-secure-env/internal/keychain"
	"github.com/kfischer-okarin/with-secure-env/internal/launcher"
	"github.com/kfischer-okarin/with-secure-env/internal/permissiondialog"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]
	switch command {
	case "init":
		runInit()
	case "edit":
		runEdit()
	case "launch":
		runLaunch()
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Fprintln(os.Stderr, `Usage: with-secure-env <command> [arguments]

Commands:
  init                      Generate and store encryption key in keychain
  edit <path/to/app>        Edit environment variables for an application
  launch <path/to/app> ...  Launch application with injected environment variables`)
}

func createLauncher() *launcher.Launcher {
	return &launcher.Launcher{
		Keychain:         &keychain.MacOSKeychain{},
		EditDialog:       &editdialog.WebViewEditDialog{},
		PermissionDialog: &permissiondialog.WebViewPermissionDialog{},
		ConfigDirPath:    configDir(),
		Exec:             execProcess,
	}
}

func runInit() {
	ensureConfigDir()
	l := createLauncher()
	l.Init()
}

func runEdit() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "Error: edit requires an application path")
		printUsage()
		os.Exit(1)
	}

	ensureConfigDir()
	appPath := resolveAbsolutePath(os.Args[2])
	l := createLauncher()
	l.EditEnvs(appPath)
}

func runLaunch() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "Error: launch requires an application path")
		printUsage()
		os.Exit(1)
	}

	appPath := resolveAbsolutePath(os.Args[2])
	args := os.Args[3:]
	caller := getCallerInfo()

	l := createLauncher()
	l.Launch(appPath, args, caller)
}

func configDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "with-secure-env")
}

func ensureConfigDir() {
	os.MkdirAll(configDir(), 0700)
}

func resolveAbsolutePath(path string) string {
	abs, err := filepath.Abs(path)
	if err != nil {
		return path
	}
	return abs
}

func getCallerInfo() permissiondialog.CallerInfo {
	ppid := os.Getppid()
	name := "unknown"

	if proc, err := ps.FindProcess(ppid); err == nil && proc != nil {
		name = proc.Executable()
	}

	return permissiondialog.CallerInfo{
		Name: name,
		PID:  ppid,
	}
}

func execProcess(path string, args []string, env []string) error {
	fullArgs := append([]string{path}, args...)
	fullEnv := append(os.Environ(), env...)
	return syscall.Exec(path, fullArgs, fullEnv)
}
