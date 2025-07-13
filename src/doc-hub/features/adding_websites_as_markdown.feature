Feature: Adding websites as Markdown
  As a developer
  I want to import any public website into doc-hub with a single CLI command
  so that coding agents can consume the content offline as Markdown.

  Scenario: Downloads and converts a website to markdown
    Given The url "https://example.com" returns:
    """
    <html>
      <head>
        <title>Example</title>
      </head>
      <body>
        <h1>Example</h1>
        <p>This is an example.</p>
      </body>
    </html>
    """
    When I run `doc-hub add example https://example.com`
    And I run `doc-hub show example`
    Then the output from "doc-hub show example" should contain exactly:
    """
    # Example

    This is an example.
    """
