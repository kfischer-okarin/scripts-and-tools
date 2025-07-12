Given (/^I do not set the environment variable "(.+)"$/) do |var|
  delete_environment_variable(var)
end

When (/^I add documentation with id "([^"]*)"$/) do |doc_id|
  fixture_url = "https://specifications.freedesktop.org/basedir-spec/latest/"
  step %(I successfully run `doc-hub add #{doc_id} #{fixture_url}`)
end
