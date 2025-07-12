Given (/^I do not set the environment variable "(.+)"$/) do |var|
  delete_environment_variable(var)
end
