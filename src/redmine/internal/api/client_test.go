package api

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestRedmineClient_ListIssues_Success(t *testing.T) {
	testDataPath := filepath.Join("testdata", "issues_response.json")
	responseData, err := os.ReadFile(testDataPath)
	if err != nil {
		t.Fatalf("Failed to read test data: %v", err)
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/issues.json" {
			t.Errorf("Expected path /issues.json, got %s", r.URL.Path)
		}

		if r.URL.Query().Get("project_id") != "1" {
			t.Errorf("Expected project_id=1, got %s", r.URL.Query().Get("project_id"))
		}

		if r.Header.Get("X-Redmine-API-Key") != "test-api-key" {
			t.Errorf("Expected X-Redmine-API-Key=test-api-key, got %s", r.Header.Get("X-Redmine-API-Key"))
		}

		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("Expected Content-Type=application/json, got %s", r.Header.Get("Content-Type"))
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(responseData)
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("1")

	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	if len(issues) != 3 {
		t.Errorf("Expected 3 issues, got %d", len(issues))
	}

	if issues[0].ID != 12345 {
		t.Errorf("Expected first issue ID 12345, got %d", issues[0].ID)
	}

	if issues[0].Subject != "Fix login validation bug" {
		t.Errorf("Expected first issue subject 'Fix login validation bug', got '%s'", issues[0].Subject)
	}

	if issues[0].Status.Name != "New" {
		t.Errorf("Expected first issue status 'New', got '%s'", issues[0].Status.Name)
	}
}

func TestRedmineClient_ListIssues_EmptyResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"issues": [], "count": 0}`))
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("1")

	if err != nil {
		t.Fatalf("Expected no error, got %v", err)
	}

	if len(issues) != 0 {
		t.Errorf("Expected 0 issues, got %d", len(issues))
	}
}

func TestRedmineClient_ListIssues_HTTPError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("1")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestRedmineClient_ListIssues_NetworkError(t *testing.T) {
	client := NewRedmineClient("http://invalid-url", "test-api-key")
	issues, err := client.ListIssues("1")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestRedmineClient_ListIssues_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`invalid json`))
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("1")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestNewRedmineClient(t *testing.T) {
	client := NewRedmineClient("http://test.com", "test-key")

	if client == nil {
		t.Fatal("Expected client to be created, got nil")
	}

	if client.baseURL != "http://test.com" {
		t.Errorf("Expected baseURL 'http://test.com', got '%s'", client.baseURL)
	}

	if client.apiKey != "test-key" {
		t.Errorf("Expected apiKey 'test-key', got '%s'", client.apiKey)
	}

	if client.httpClient == nil {
		t.Fatal("Expected httpClient to be created, got nil")
	}
}
