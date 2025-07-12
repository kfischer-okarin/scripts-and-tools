Given (/^I do not set the environment variable "(.+)"$/) do |var|
  delete_environment_variable(var)
end

When (/^I add documentation with id "([^"]*)"$/) do |doc_id|
  fixture_url = "https://specifications.freedesktop.org/basedir-spec/latest/"
  step %(I successfully run `doc-hub add #{doc_id} #{fixture_url}`)
end

Then (/^the directory "([^"]*)" should contain a downloaded documentation$/) do |dir_path|
  step %(the directory "#{dir_path}" should exist)
  step %(a file "#{dir_path}/index.md" should exist)
end
