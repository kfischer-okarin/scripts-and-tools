package api

type Issue struct {
	ID      int     `json:"id"`
	Subject string  `json:"subject"`
	Status  Status  `json:"status"`
	Project Project `json:"project"`
}

type Status struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type Project struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type IssuesResponse struct {
	Issues []Issue `json:"issues"`
	Count  int     `json:"count"`
}
