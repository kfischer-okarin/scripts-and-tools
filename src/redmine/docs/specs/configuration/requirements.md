# Requirements Document

## Introduction

This feature enables users to configure the Redmine URL and API key through the
command-line interface. This provides a simple CLI-based approach to set the
connection data needed for the tool to communicate with a Redmine server.

## Requirements

### Requirement 1: Set Configuration Values

**User Story:** As a user, I want to set the Redmine URL and API key through CLI
commands, so that I can quickly configure the tool without manually editing
files.

#### Acceptance Criteria

1. WHEN the user runs `redmine config set url <URL>`, THEN the system SHALL
   store the provided URL as the Redmine server endpoint.
2. WHEN the user runs `redmine config set api-key <KEY>`, THEN the system SHALL
   store the provided API key.
3. WHEN the user sets a configuration value, THEN the system SHALL display a
   confirmation message indicating the value was successfully stored.
4. WHEN the user sets a configuration value that already exists, THEN the system
   SHALL overwrite the existing value.

### Requirement 2: View Configuration Values

**User Story:** As a user, I want to view the current configuration values, so
that I can verify my settings.

#### Acceptance Criteria

1. WHEN the user runs `redmine config show`, THEN the system SHALL display all
   current configuration values (URL and API key).
2. WHEN no configuration values are set, THEN the system SHALL display a message
   indicating no configuration is found.

### Requirement 3: Configuration Storage

**User Story:** As a user, I want my configuration to be stored persistently, so
that I don't need to reconfigure the tool each time I use it.

#### Acceptance Criteria

1. WHEN configuration values are set, THEN the system SHALL store them in a
   user-specific configuration file in the appropriate OS-specific location.
2. WHEN the configuration file is created, THEN the system SHALL set appropriate
   file permissions to restrict access to the current user only.
