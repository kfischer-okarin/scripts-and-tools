Feature: Store docs in XDG data dir
  As a developer
  I want doc-hub to store downloaded docs in the XDG data dir
  So that it's easy to find and manage

  Scenario: AC-1 Respects XDG_DATA_HOME
    Given I set the environment variable "XDG_DATA_HOME" to "custom/data"
    When I successfully run `doc-hub add xdg-spec https://specifications.freedesktop.org/basedir-spec/latest/`
    Then the directory "custom/data/doc-hub/xdg-spec" should exist
    And a file "custom/data/doc-hub/xdg-spec/index.md" should exist

  Scenario: AC-2 Uses default location if XDG_DATA_HOME is not set
    Given I do not set the environment variable "XDG_DATA_HOME"
    When I successfully run `doc-hub add xdg-spec https://specifications.freedesktop.org/basedir-spec/latest/`
    Then the directory "~/.local/share/doc-hub/xdg-spec" should exist
    And a file "~/.local/share/doc-hub/xdg-spec/index.md" should exist
