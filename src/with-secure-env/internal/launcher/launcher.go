package launcher

import (
	"errors"
	"os"
	"os/exec"
)

var (
	ErrUnknownApp       = errors.New("unknown application")
	ErrPermissionDenied = errors.New("permission denied")
)

type EnvStorage interface {
	Init(key string) (string, error)
	ListApplications() []string
	AvailableKeys(appPath string) []string
	Remove(appPath string)
	Get(appPath string) map[string]string
	Set(appPath string, envs map[string]string)
	AppConfigured(appPath string) bool
}

type EnvEditor interface {
	Edit(currentEnvs map[string]string) map[string]string
}

type AccessPolicy interface {
	Check(appPath string, envKeys []string, processContext any) bool
}

type Config struct {
	EnvStorage   EnvStorage
	EnvEditor    EnvEditor
	AccessPolicy AccessPolicy
}

type Launcher struct {
	storage EnvStorage
	editor  EnvEditor
	policy  AccessPolicy
}

func New(cfg Config) *Launcher {
	return &Launcher{
		storage: cfg.EnvStorage,
		editor:  cfg.EnvEditor,
		policy:  cfg.AccessPolicy,
	}
}

func (l *Launcher) Init(key string) (string, error) {
	return l.storage.Init(key)
}

func (l *Launcher) ListApplications() []string {
	return l.storage.ListApplications()
}

func (l *Launcher) ListEnvKeys(appPath string) []string {
	return l.storage.AvailableKeys(appPath)
}

func (l *Launcher) Remove(appPath string) {
	l.storage.Remove(appPath)
}

func (l *Launcher) EditEnvs(appPath string) {
	currentEnvs := l.storage.Get(appPath)
	newEnvs := l.editor.Edit(currentEnvs)
	if newEnvs != nil {
		l.storage.Set(appPath, newEnvs)
	}
}

func (l *Launcher) Launch(appPath string, args []string, processContext any) error {
	if !l.storage.AppConfigured(appPath) {
		return ErrUnknownApp
	}

	envKeys := l.storage.AvailableKeys(appPath)
	if !l.policy.Check(appPath, envKeys, processContext) {
		return ErrPermissionDenied
	}

	envs := l.storage.Get(appPath)

	cmd := exec.Command(appPath, args...)
	cmd.Env = os.Environ()
	for k, v := range envs {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}
