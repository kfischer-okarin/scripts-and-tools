package issue

import (
	"fmt"

	"github.com/spf13/cobra"
	"redmine/internal/api"
	"redmine/internal/config"
	"redmine/internal/formatter"
)

// ListCommandDeps holds dependencies for the list command
type ListCommandDeps struct {
	ConfigLoader  func() (*config.Config, error)
	ClientFactory func(baseURL, apiKey string) api.Client
	Formatter     formatter.IssueFormatter
}

// NewListCommand creates a new list command with default dependencies
func NewListCommand() *cobra.Command {
	deps := &ListCommandDeps{
		ConfigLoader: config.LoadConfig,
		ClientFactory: func(baseURL, apiKey string) api.Client {
			return api.NewRedmineClient(baseURL, apiKey)
		},
		Formatter: formatter.NewTableFormatter(),
	}
	return NewListCommandWithDeps(deps)
}

// NewListCommandWithDeps creates a new list command with injected dependencies
func NewListCommandWithDeps(deps *ListCommandDeps) *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List issues from the configured Redmine project",
		Long:  "Retrieves and displays issues from the configured Redmine project in a formatted table",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runListCommandWithDeps(cmd, args, deps)
		},
	}
}

func runListCommandWithDeps(cmd *cobra.Command, args []string, deps *ListCommandDeps) error {
	// Load configuration
	cfg, err := deps.ConfigLoader()
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	// Create API client
	client := deps.ClientFactory(cfg.BaseURL, cfg.APIKey)

	// Fetch issues
	issues, err := client.ListIssues(cfg.ProjectID)
	if err != nil {
		return fmt.Errorf("failed to fetch issues: %w", err)
	}

	// Format and display results
	output := deps.Formatter.Format(issues)

	fmt.Println(output)
	return nil
}
