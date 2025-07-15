package cli

import (
	"bytes"
	"strings"
	"testing"
)

func TestRootCommand(t *testing.T) {
	tests := []struct {
		name           string
		args           []string
		expectError    bool
		expectInOutput []string
	}{
		{
			name:           "help command",
			args:           []string{"--help"},
			expectError:    false,
			expectInOutput: []string{"A command line interface for Redmine", "Available Commands:", "issue"},
		},
		{
			name:           "invalid command",
			args:           []string{"invalid-command"},
			expectError:    true,
			expectInOutput: []string{"unknown command"},
		},
		{
			name:           "issue help",
			args:           []string{"issue", "--help"},
			expectError:    false,
			expectInOutput: []string{"Commands for viewing and managing Redmine issues"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Use the actual root command with all setup done
			cmd := RootCmd

			// Capture output
			var output bytes.Buffer
			cmd.SetOut(&output)
			cmd.SetErr(&output)
			cmd.SetArgs(tt.args)

			err := cmd.Execute()

			// Check error expectation
			if tt.expectError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tt.expectError && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}

			// Check output contains expected strings
			outputStr := output.String()
			for _, expected := range tt.expectInOutput {
				if !strings.Contains(outputStr, expected) {
					t.Errorf("Expected output to contain %q, but got: %s", expected, outputStr)
				}
			}
		})
	}
}
