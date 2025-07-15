package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

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
	url := fmt.Sprintf("%s/issues.json?project_id=%s", c.baseURL, projectID)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("X-Redmine-API-Key", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status %d", resp.StatusCode)
	}

	var issuesResponse IssuesResponse
	if err := json.NewDecoder(resp.Body).Decode(&issuesResponse); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return issuesResponse.Issues, nil
}
