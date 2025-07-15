# Requirements Document

## Introduction

This document outlines the requirements for a minimal MVP `redmine` CLI tool
that provides basic issue listing functionality. This is a vertical slice
focused on the core feature of retrieving and displaying issues from a
hardcoded Redmine project.

## Requirements

### Requirement 1: Issue List Command

**User Story:** As a developer, I want to list issues from a Redmine project,
so that I can quickly view project status from the command line.

#### Acceptance Criteria

1. WHEN I run `redmine issue list`, THEN the system SHALL display a formatted
   list of issues from the configured project showing issue ID, title, and
   status
2. WHEN there are no issues in the project, THEN the system SHALL display "No
   issues found"

### Requirement 2: Basic Error Handling

**User Story:** As a user, I want clear error messages when something goes
wrong, so that I can understand what needs to be fixed.

#### Acceptance Criteria

1. WHEN the Redmine server is unreachable, THEN the system SHALL display
   "Error: Unable to connect to Redmine server"
2. WHEN I provide invalid command arguments, THEN the system SHALL display
   basic usage information
3. WHEN an API request fails, THEN the system SHALL display a simple error
   message
