Given(/^I do not set the environment variable "(.+)"$/) do |var|
  delete_environment_variable(var)
end

When(/^I add documentation with id "([^"]*)"$/) do |doc_id|
  fixture_url = "https://specifications.freedesktop.org/basedir-spec/latest/"
  step %(I successfully run `doc-hub add #{doc_id} #{fixture_url}`)
end

Then(/^the directory "([^"]*)" should contain a downloaded documentation$/) do |dir_path|
  step %(the directory "#{dir_path}" should exist)
  step %(a file "#{dir_path}/index.md" should exist)
end

Given(/^The url "([^"]*)" returns:$/) do |url, content|
  replace_curl_with_script <<~SCRIPT
    #!/bin/bash
    if [[ "$@" == *"#{url}"* ]]; then
      cat << 'EOF'
    #{content}
    EOF
    else
      echo "curl: (6) Could not resolve host"
      exit 6
    fi
  SCRIPT
end
