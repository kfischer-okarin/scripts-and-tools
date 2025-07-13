# frozen_string_literal: true

require 'aruba/cucumber'

module DocHubFeatureHelpers
  def replace_curl_with_script(script_content)
    step %(an executable named "test-bin/curl" with:), script_content
  end
end

World(DocHubFeatureHelpers)

Before do
  replace_curl_with_script <<~SCRIPT
    #!/bin/bash
    echo '<h1>Test Doc</h1>'
  SCRIPT

  prepend_environment_variable("PATH", expand_path("test-bin:"))
end
