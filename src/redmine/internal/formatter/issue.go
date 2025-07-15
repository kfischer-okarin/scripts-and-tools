package formatter

import (
	"fmt"
	"strings"

	"github.com/kfischer-okarin/redmine/internal/api"
)

type IssueFormatter interface {
	Format(issues []api.Issue) string
}

type TableFormatter struct{}

func NewTableFormatter() IssueFormatter {
	return &TableFormatter{}
}

func (f *TableFormatter) Format(issues []api.Issue) string {
	if len(issues) == 0 {
		return "No issues found"
	}

	// Calculate column widths
	idWidth := calculateMaxWidth("ID", getIDs(issues))
	subjectWidth := calculateMaxWidth("Subject", getSubjects(issues))
	statusWidth := calculateMaxWidth("Status", getStatuses(issues))

	// Build header
	header := fmt.Sprintf("%-*s | %-*s | %-*s",
		idWidth, "ID",
		subjectWidth, "Subject",
		statusWidth, "Status")

	// Build separator
	separator := fmt.Sprintf("%s-|-%s-|-%s",
		strings.Repeat("-", idWidth),
		strings.Repeat("-", subjectWidth),
		strings.Repeat("-", statusWidth))

	// Build rows
	var rows []string
	for _, issue := range issues {
		row := fmt.Sprintf("%-*d | %-*s | %-*s",
			idWidth, issue.ID,
			subjectWidth, issue.Subject,
			statusWidth, issue.Status.Name)
		rows = append(rows, row)
	}

	// Combine all parts
	result := []string{header, separator}
	result = append(result, rows...)

	return strings.Join(result, "\n")
}

func calculateMaxWidth(header string, values []string) int {
	maxWidth := len(header)
	for _, value := range values {
		if len(value) > maxWidth {
			maxWidth = len(value)
		}
	}
	return maxWidth
}

func getIDs(issues []api.Issue) []string {
	var ids []string
	for _, issue := range issues {
		ids = append(ids, fmt.Sprintf("%d", issue.ID))
	}
	return ids
}

func getSubjects(issues []api.Issue) []string {
	var subjects []string
	for _, issue := range issues {
		subjects = append(subjects, issue.Subject)
	}
	return subjects
}

func getStatuses(issues []api.Issue) []string {
	var statuses []string
	for _, issue := range issues {
		statuses = append(statuses, issue.Status.Name)
	}
	return statuses
}
