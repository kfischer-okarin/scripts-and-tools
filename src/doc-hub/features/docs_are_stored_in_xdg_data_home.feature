Feature: Docs are stored $XDG_DATA_HOME
  As a developer
  I want doc-hub to store downloaded docs in the XDG data dir
  So that it's easy to find and manage

  # TODO: Write proper documentations
  # TODO: better shorter step definitions

  Scenario: AC-1 Respects $XDG_DATA_HOME
    Given I set the environment variable "XDG_DATA_HOME" to "custom/data"
    When I add documentation with id "xdg-spec"
    Then the directory "custom/data/doc-hub/xdg-spec" should contain a downloaded documentation

  Scenario: AC-2 Uses default location if $XDG_DATA_HOME is not set
    Given I do not set the environment variable "XDG_DATA_HOME"
    When I add documentation with id "xdg-spec"
    Then the directory "~/.local/share/doc-hub/xdg-spec" should contain a downloaded documentation
