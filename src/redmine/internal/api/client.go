package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// ErrorType represents different types of errors that can occur
type ErrorType int

const (
	NetworkError ErrorType = iota
	AuthenticationError
	NotFoundError
	ServerError
	ConfigurationError
)

// RedmineError represents a Redmine API error with context
type RedmineError struct {
	Type    ErrorType
	Message string
	Cause   error
}

func (e *RedmineError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Cause)
	}
	return e.Message
}

func (e *RedmineError) Unwrap() error {
	return e.Cause
}

// Error messages mapping
var errorMessages = map[ErrorType]string{
	NetworkError:        "Error: Unable to connect to Redmine server",
	AuthenticationError: "Error: Authentication failed. Please check your API key",
	NotFoundError:       "Error: Project not found",
	ServerError:         "Error: Redmine server error",
	ConfigurationError:  "Error: Invalid configuration",
}

// NewRedmineError creates a new RedmineError with a user-friendly message
func NewRedmineError(errorType ErrorType, cause error) *RedmineError {
	return &RedmineError{
		Type:    errorType,
		Message: errorMessages[errorType],
		Cause:   cause,
	}
}

// classifyHTTPError determines the appropriate error type based on HTTP status code
func classifyHTTPError(statusCode int) ErrorType {
	switch {
	case statusCode == http.StatusUnauthorized:
		return AuthenticationError
	case statusCode == http.StatusNotFound:
		return NotFoundError
	case statusCode >= 500:
		return ServerError
	default:
		return ServerError
	}
}

// classifyNetworkError determines if an error is a network-related error
func classifyNetworkError(err error) bool {
	if err == nil {
		return false
	}

	// Check for URL errors (DNS resolution, connection refused, etc.)
	if _, ok := err.(*url.Error); ok {
		return true
	}

	// Check for network-related error messages
	errStr := strings.ToLower(err.Error())
	networkKeywords := []string{
		"connection refused",
		"no such host",
		"network is unreachable",
		"timeout",
		"connection reset",
		"connection timed out",
	}

	for _, keyword := range networkKeywords {
		if strings.Contains(errStr, keyword) {
			return true
		}
	}

	return false
}

type Client interface {
	ListIssues(projectID string) ([]Issue, error)
}

type RedmineClient struct {
	baseURL    string
	apiKey     string
	httpClient *http.Client
}

func NewRedmineClient(baseURL, apiKey string) *RedmineClient {
	return &RedmineClient{
		baseURL: baseURL,
		apiKey:  apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *RedmineClient) ListIssues(projectID string) ([]Issue, error) {
	u, err := url.Parse(c.baseURL + "/issues.json")
	if err != nil {
		return nil, NewRedmineError(ConfigurationError, err)
	}
	q := u.Query()
	q.Set("project_id", projectID)
	u.RawQuery = q.Encode()
	urlStr := u.String()

	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		return nil, NewRedmineError(ConfigurationError, err)
	}

	req.Header.Set("X-Redmine-API-Key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		if classifyNetworkError(err) {
			return nil, NewRedmineError(NetworkError, err)
		}
		return nil, NewRedmineError(ServerError, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errorType := classifyHTTPError(resp.StatusCode)
		return nil, NewRedmineError(errorType, fmt.Errorf("HTTP %d", resp.StatusCode))
	}

	var issuesResponse IssuesResponse
	if err := json.NewDecoder(resp.Body).Decode(&issuesResponse); err != nil {
		return nil, NewRedmineError(ServerError, err)
	}

	return issuesResponse.Issues, nil
}
