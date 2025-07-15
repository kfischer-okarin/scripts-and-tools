package formatter

import (
	"strings"
	"testing"

	"redmine/internal/api"
)

func TestTableFormatter_Format_EmptyIssues(t *testing.T) {
	formatter := NewTableFormatter()
	result := formatter.Format([]api.Issue{})

	expected := "No issues found"
	if result != expected {
		t.Errorf("Expected '%s', got '%s'", expected, result)
	}
}

func TestTableFormatter_Format_SingleIssue(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      12345,
			Subject: "Fix login validation bug",
			Status:  api.Status{ID: 1, Name: "New"},
		},
	}

	result := formatter.Format(issues)
	lines := strings.Split(result, "\n")

	// Should have 3 lines: header, separator, data row
	if len(lines) != 3 {
		t.Errorf("Expected 3 lines, got %d", len(lines))
	}

	// Check header
	expectedHeader := "ID    | Subject                  | Status"
	if lines[0] != expectedHeader {
		t.Errorf("Expected header '%s', got '%s'", expectedHeader, lines[0])
	}

	// Check separator
	expectedSeparator := "------|--------------------------|-------"
	if lines[1] != expectedSeparator {
		t.Errorf("Expected separator '%s', got '%s'", expectedSeparator, lines[1])
	}

	// Check data row
	expectedRow := "12345 | Fix login validation bug | New   "
	if lines[2] != expectedRow {
		t.Errorf("Expected row '%s', got '%s'", expectedRow, lines[2])
	}
}

func TestTableFormatter_Format_MultipleIssues(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      12345,
			Subject: "Fix login validation bug",
			Status:  api.Status{ID: 1, Name: "New"},
		},
		{
			ID:      12346,
			Subject: "Add user profile feature",
			Status:  api.Status{ID: 2, Name: "In Progress"},
		},
		{
			ID:      12347,
			Subject: "Update API documentation",
			Status:  api.Status{ID: 3, Name: "Closed"},
		},
	}

	result := formatter.Format(issues)
	lines := strings.Split(result, "\n")

	// Should have 5 lines: header, separator, 3 data rows
	if len(lines) != 5 {
		t.Errorf("Expected 5 lines, got %d", len(lines))
	}

	// Check that all issues are present
	if !strings.Contains(result, "12345") || !strings.Contains(result, "Fix login validation bug") {
		t.Error("First issue not found in output")
	}
	if !strings.Contains(result, "12346") || !strings.Contains(result, "Add user profile feature") {
		t.Error("Second issue not found in output")
	}
	if !strings.Contains(result, "12347") || !strings.Contains(result, "Update API documentation") {
		t.Error("Third issue not found in output")
	}
}

func TestTableFormatter_Format_ColumnAlignment(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      1,
			Subject: "Short",
			Status:  api.Status{ID: 1, Name: "New"},
		},
		{
			ID:      123456,
			Subject: "This is a very long subject that should test column width calculation",
			Status:  api.Status{ID: 2, Name: "In Progress"},
		},
	}

	result := formatter.Format(issues)
	lines := strings.Split(result, "\n")

	// Check that columns are properly aligned
	headerParts := strings.Split(lines[0], " | ")
	if len(headerParts) != 3 {
		t.Errorf("Expected 3 columns in header, got %d", len(headerParts))
	}

	// Check that all data rows have the same structure
	for i := 2; i < len(lines); i++ {
		parts := strings.Split(lines[i], " | ")
		if len(parts) != 3 {
			t.Errorf("Expected 3 columns in row %d, got %d", i, len(parts))
		}
	}
}

func TestTableFormatter_Format_LongSubjects(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      1,
			Subject: "This is an extremely long subject line that should test how the formatter handles very long text content in the subject column",
			Status:  api.Status{ID: 1, Name: "New"},
		},
	}

	result := formatter.Format(issues)

	// Should not crash and should contain the full subject
	if !strings.Contains(result, "This is an extremely long subject line") {
		t.Error("Long subject not properly handled")
	}
}

func TestTableFormatter_Format_SpecialCharacters(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      1,
			Subject: "Fix issue with special chars: @#$%^&*()",
			Status:  api.Status{ID: 1, Name: "New"},
		},
	}

	result := formatter.Format(issues)

	// Should properly handle special characters
	if !strings.Contains(result, "Fix issue with special chars: @#$%^&*()") {
		t.Error("Special characters not properly handled")
	}
}

func TestTableFormatter_Format_VaryingStatusLengths(t *testing.T) {
	formatter := NewTableFormatter()
	issues := []api.Issue{
		{
			ID:      1,
			Subject: "Issue 1",
			Status:  api.Status{ID: 1, Name: "New"},
		},
		{
			ID:      2,
			Subject: "Issue 2",
			Status:  api.Status{ID: 2, Name: "In Progress"},
		},
		{
			ID:      3,
			Subject: "Issue 3",
			Status:  api.Status{ID: 3, Name: "Closed"},
		},
	}

	result := formatter.Format(issues)
	lines := strings.Split(result, "\n")

	// Check that status column is properly sized for "In Progress"
	if !strings.Contains(lines[0], "Status") {
		t.Error("Status header not found")
	}

	// All status values should be present
	if !strings.Contains(result, "New") || !strings.Contains(result, "In Progress") || !strings.Contains(result, "Closed") {
		t.Error("Not all status values found in output")
	}
}

func TestCalculateMaxWidth(t *testing.T) {
	tests := []struct {
		header   string
		values   []string
		expected int
	}{
		{"ID", []string{"1", "123", "12345"}, 5},
		{"Subject", []string{"Short", "Medium length", "Very long subject line"}, 22},
		{"Status", []string{"New", "In Progress", "Closed"}, 11},
		{"Empty", []string{}, 5},
	}

	for _, test := range tests {
		result := calculateMaxWidth(test.header, test.values)
		if result != test.expected {
			t.Errorf("calculateMaxWidth(%q, %v) = %d, expected %d", test.header, test.values, result, test.expected)
		}
	}
}

func TestGetIDs(t *testing.T) {
	issues := []api.Issue{
		{ID: 1, Subject: "Test 1"},
		{ID: 123, Subject: "Test 2"},
		{ID: 12345, Subject: "Test 3"},
	}

	result := getIDs(issues)
	expected := []string{"1", "123", "12345"}

	if len(result) != len(expected) {
		t.Errorf("Expected %d IDs, got %d", len(expected), len(result))
	}

	for i, id := range result {
		if id != expected[i] {
			t.Errorf("Expected ID %s, got %s", expected[i], id)
		}
	}
}

func TestGetSubjects(t *testing.T) {
	issues := []api.Issue{
		{ID: 1, Subject: "First subject"},
		{ID: 2, Subject: "Second subject"},
		{ID: 3, Subject: "Third subject"},
	}

	result := getSubjects(issues)
	expected := []string{"First subject", "Second subject", "Third subject"}

	if len(result) != len(expected) {
		t.Errorf("Expected %d subjects, got %d", len(expected), len(result))
	}

	for i, subject := range result {
		if subject != expected[i] {
			t.Errorf("Expected subject %s, got %s", expected[i], subject)
		}
	}
}

func TestGetStatuses(t *testing.T) {
	issues := []api.Issue{
		{ID: 1, Status: api.Status{ID: 1, Name: "New"}},
		{ID: 2, Status: api.Status{ID: 2, Name: "In Progress"}},
		{ID: 3, Status: api.Status{ID: 3, Name: "Closed"}},
	}

	result := getStatuses(issues)
	expected := []string{"New", "In Progress", "Closed"}

	if len(result) != len(expected) {
		t.Errorf("Expected %d statuses, got %d", len(expected), len(result))
	}

	for i, status := range result {
		if status != expected[i] {
			t.Errorf("Expected status %s, got %s", expected[i], status)
		}
	}
}
