package api

import (
	"errors"
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

func TestRedmineClient_ListIssues_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("1")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	var redmineErr *RedmineError
	if !errors.As(err, &redmineErr) {
		t.Fatalf("Expected RedmineError, got %T", err)
	}

	if redmineErr.Type != ServerError {
		t.Errorf("Expected ServerError, got %v", redmineErr.Type)
	}

	if redmineErr.Message != "Error: Redmine server error" {
		t.Errorf("Expected 'Error: Redmine server error', got '%s'", redmineErr.Message)
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

	var redmineErr *RedmineError
	if !errors.As(err, &redmineErr) {
		t.Fatalf("Expected RedmineError, got %T", err)
	}

	if redmineErr.Type != NetworkError {
		t.Errorf("Expected NetworkError, got %v", redmineErr.Type)
	}

	if redmineErr.Message != "Error: Unable to connect to Redmine server" {
		t.Errorf("Expected 'Error: Unable to connect to Redmine server', got '%s'", redmineErr.Message)
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

	var redmineErr *RedmineError
	if !errors.As(err, &redmineErr) {
		t.Fatalf("Expected RedmineError, got %T", err)
	}

	if redmineErr.Type != ServerError {
		t.Errorf("Expected ServerError, got %v", redmineErr.Type)
	}

	if redmineErr.Message != "Error: Redmine server error" {
		t.Errorf("Expected 'Error: Redmine server error', got '%s'", redmineErr.Message)
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestRedmineClient_ListIssues_AuthenticationError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "invalid-api-key")
	issues, err := client.ListIssues("1")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	var redmineErr *RedmineError
	if !errors.As(err, &redmineErr) {
		t.Fatalf("Expected RedmineError, got %T", err)
	}

	if redmineErr.Type != AuthenticationError {
		t.Errorf("Expected AuthenticationError, got %v", redmineErr.Type)
	}

	if redmineErr.Message != "Error: Authentication failed. Please check your API key" {
		t.Errorf("Expected 'Error: Authentication failed. Please check your API key', got '%s'", redmineErr.Message)
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestRedmineClient_ListIssues_NotFoundError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	client := NewRedmineClient(server.URL, "test-api-key")
	issues, err := client.ListIssues("999")

	if err == nil {
		t.Fatal("Expected error, got nil")
	}

	var redmineErr *RedmineError
	if !errors.As(err, &redmineErr) {
		t.Fatalf("Expected RedmineError, got %T", err)
	}

	if redmineErr.Type != NotFoundError {
		t.Errorf("Expected NotFoundError, got %v", redmineErr.Type)
	}

	if redmineErr.Message != "Error: Project not found" {
		t.Errorf("Expected 'Error: Project not found', got '%s'", redmineErr.Message)
	}

	if issues != nil {
		t.Errorf("Expected nil issues, got %v", issues)
	}
}

func TestClassifyNetworkError(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		expected bool
	}{
		{
			name:     "nil error",
			err:      nil,
			expected: false,
		},
		{
			name:     "connection refused",
			err:      errors.New("connection refused"),
			expected: true,
		},
		{
			name:     "no such host",
			err:      errors.New("no such host"),
			expected: true,
		},
		{
			name:     "timeout",
			err:      errors.New("timeout"),
			expected: true,
		},
		{
			name:     "network unreachable",
			err:      errors.New("network is unreachable"),
			expected: true,
		},
		{
			name:     "other error",
			err:      errors.New("some other error"),
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := classifyNetworkError(tt.err)
			if result != tt.expected {
				t.Errorf("Expected %v, got %v", tt.expected, result)
			}
		})
	}
}

func TestClassifyHTTPError(t *testing.T) {
	tests := []struct {
		name       string
		statusCode int
		expected   ErrorType
	}{
		{
			name:       "unauthorized",
			statusCode: http.StatusUnauthorized,
			expected:   AuthenticationError,
		},
		{
			name:       "not found",
			statusCode: http.StatusNotFound,
			expected:   NotFoundError,
		},
		{
			name:       "internal server error",
			statusCode: http.StatusInternalServerError,
			expected:   ServerError,
		},
		{
			name:       "bad gateway",
			statusCode: http.StatusBadGateway,
			expected:   ServerError,
		},
		{
			name:       "bad request",
			statusCode: http.StatusBadRequest,
			expected:   ServerError,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := classifyHTTPError(tt.statusCode)
			if result != tt.expected {
				t.Errorf("Expected %v, got %v", tt.expected, result)
			}
		})
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
