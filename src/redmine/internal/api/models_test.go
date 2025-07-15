package api

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestIssuesResponseUnmarshal(t *testing.T) {
	testDataPath := filepath.Join("testdata", "issues_response.json")
	jsonData, err := os.ReadFile(testDataPath)
	if err != nil {
		t.Fatalf("Failed to read test data file: %v", err)
	}

	var response IssuesResponse
	err = json.Unmarshal(jsonData, &response)
	if err != nil {
		t.Fatalf("Failed to unmarshal JSON: %v", err)
	}

	if response.Count != 3 {
		t.Errorf("Expected count to be 3, got %d", response.Count)
	}

	if len(response.Issues) != 3 {
		t.Errorf("Expected 3 issues, got %d", len(response.Issues))
	}

	firstIssue := response.Issues[0]
	if firstIssue.ID != 12345 {
		t.Errorf("Expected first issue ID to be 12345, got %d", firstIssue.ID)
	}

	if firstIssue.Subject != "Fix login validation bug" {
		t.Errorf("Expected first issue subject to be 'Fix login validation bug', got '%s'", firstIssue.Subject)
	}

	if firstIssue.Status.Name != "New" {
		t.Errorf("Expected first issue status to be 'New', got '%s'", firstIssue.Status.Name)
	}

	if firstIssue.Project.Name != "Test Project" {
		t.Errorf("Expected first issue project to be 'Test Project', got '%s'", firstIssue.Project.Name)
	}
}

func TestIssueStructure(t *testing.T) {
	issue := Issue{
		ID:      12345,
		Subject: "Test Issue",
		Status: Status{
			ID:   1,
			Name: "New",
		},
		Project: Project{
			ID:   1,
			Name: "Test Project",
		},
	}

	jsonData, err := json.Marshal(issue)
	if err != nil {
		t.Fatalf("Failed to marshal issue: %v", err)
	}

	var unmarshaledIssue Issue
	err = json.Unmarshal(jsonData, &unmarshaledIssue)
	if err != nil {
		t.Fatalf("Failed to unmarshal issue: %v", err)
	}

	if unmarshaledIssue.ID != issue.ID {
		t.Errorf("Expected ID %d, got %d", issue.ID, unmarshaledIssue.ID)
	}

	if unmarshaledIssue.Subject != issue.Subject {
		t.Errorf("Expected subject '%s', got '%s'", issue.Subject, unmarshaledIssue.Subject)
	}

	if unmarshaledIssue.Status.Name != issue.Status.Name {
		t.Errorf("Expected status '%s', got '%s'", issue.Status.Name, unmarshaledIssue.Status.Name)
	}

	if unmarshaledIssue.Project.Name != issue.Project.Name {
		t.Errorf("Expected project '%s', got '%s'", issue.Project.Name, unmarshaledIssue.Project.Name)
	}
}

func TestEmptyIssuesResponse(t *testing.T) {
	emptyResponse := IssuesResponse{
		Issues: []Issue{},
		Count:  0,
	}

	jsonData, err := json.Marshal(emptyResponse)
	if err != nil {
		t.Fatalf("Failed to marshal empty response: %v", err)
	}

	var unmarshaledResponse IssuesResponse
	err = json.Unmarshal(jsonData, &unmarshaledResponse)
	if err != nil {
		t.Fatalf("Failed to unmarshal empty response: %v", err)
	}

	if unmarshaledResponse.Count != 0 {
		t.Errorf("Expected count to be 0, got %d", unmarshaledResponse.Count)
	}

	if len(unmarshaledResponse.Issues) != 0 {
		t.Errorf("Expected 0 issues, got %d", len(unmarshaledResponse.Issues))
	}
}
