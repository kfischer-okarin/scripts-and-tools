package editdialog

// EditDialog provides a user interface for editing environment variables.
type EditDialog interface {
	// EditEnvs opens an editor for the environment variables of the given application.
	// It receives the current values and returns the updated values.
	// The bool return value is false if the user canceled the edit.
	EditEnvs(applicationPath string, currentValues map[string]string) (map[string]string, bool)
}
