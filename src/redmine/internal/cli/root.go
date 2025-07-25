package cli

import (
	"fmt"
	"os"

	"github.com/kfischer-okarin/redmine/internal/cli/issue"
	"github.com/spf13/cobra"
)

func buildCommand() *cobra.Command {
	rootCmd := &cobra.Command{
		Use:   "redmine",
		Short: "A CLI tool for interacting with Redmine",
		Long: `A command line interface for Redmine that allows you to view and manage
issues from your terminal. This tool provides basic functionality to interact
with Redmine projects.`,
	}

	issueCmd := &cobra.Command{
		Use:   "issue",
		Short: "Issue management commands",
		Long:  "Commands for viewing and managing Redmine issues",
	}

	// Add list command to issue subcommand
	issueCmd.AddCommand(issue.NewListCommand())

	rootCmd.AddCommand(issueCmd)
	return rootCmd
}

var RootCmd = buildCommand()

func Execute() {
	if err := RootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
