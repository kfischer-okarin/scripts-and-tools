package issue

import (
	"bytes"
	"errors"
	"os"
	"strings"
	"testing"

	"redmine/internal/api"
	"redmine/internal/config"
	"redmine/internal/formatter"
)

// mockClient is a mock implementation of the api.Client interface
type mockClient struct {
	issues []api.Issue
	err    error
}

func (m *mockClient) ListIssues(projectID string) ([]api.Issue, error) {
	return m.issues, m.err
}

func TestRunListCommand(t *testing.T) {
	tests := []struct {
		name           string
		mockIssues     []api.Issue
		mockError      error
		configError    error
		expectError    bool
		expectedOutput string
	}{
		{
			name: "successful list with issues",
			mockIssues: []api.Issue{
				{
					ID:      12345,
					Subject: "Fix login validation bug",
					Status:  api.Status{ID: 1, Name: "New"},
					Project: api.Project{ID: 1, Name: "Test Project"},
				},
				{
					ID:      12346,
					Subject: "Add user profile feature",
					Status:  api.Status{ID: 2, Name: "In Progress"},
					Project: api.Project{ID: 1, Name: "Test Project"},
				},
			},
			expectError:    false,
			expectedOutput: "12345 | Fix login validation bug | New",
		},
		{
			name:           "successful list with no issues",
			mockIssues:     []api.Issue{},
			expectError:    false,
			expectedOutput: "No issues found",
		},
		{
			name:        "API client error",
			mockError:   errors.New("server error"),
			expectError: true,
		},
		{
			name:        "configuration error",
			configError: errors.New("invalid config"),
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create mock dependencies
			deps := &ListCommandDeps{
				ConfigLoader: func() (*config.Config, error) {
					if tt.configError != nil {
						return nil, tt.configError
					}
					return &config.Config{
						BaseURL:   "https://test.example.com",
						APIKey:    "test-key",
						ProjectID: "test-project",
					}, nil
				},
				ClientFactory: func(baseURL, apiKey string) api.Client {
					return &mockClient{
						issues: tt.mockIssues,
						err:    tt.mockError,
					}
				},
				Formatter: formatter.NewTableFormatter(),
			}

			// Capture stdout
			oldStdout := os.Stdout
			r, w, _ := os.Pipe()
			os.Stdout = w

			// Create and run command
			cmd := NewListCommandWithDeps(deps)
			err := runListCommandWithDeps(cmd, []string{}, deps)

			// Restore stdout and get output
			w.Close()
			os.Stdout = oldStdout
			var buf bytes.Buffer
			buf.ReadFrom(r)
			output := strings.TrimSpace(buf.String())

			// Check results
			if tt.expectError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tt.expectError && err != nil {
				t.Errorf("Expected no error but got: %v", err)
			}
			if !tt.expectError && !strings.Contains(output, tt.expectedOutput) {
				t.Errorf("Expected output to contain %q, got %q", tt.expectedOutput, output)
			}
		})
	}
}

func TestNewListCommand(t *testing.T) {
	cmd := NewListCommand()

	if cmd.Use != "list" {
		t.Errorf("Expected Use to be 'list', got %q", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("Expected Short description to be set")
	}

	if cmd.Long == "" {
		t.Error("Expected Long description to be set")
	}

	if cmd.RunE == nil {
		t.Error("Expected RunE to be set")
	}
}
