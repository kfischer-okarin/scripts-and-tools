# Coding Guidelines

## Tech Stack

- Uses cucumber with aruba for acceptance tests
- Uses minitest for unit tests
- Uses thor for CLI

## Folder structure

- `features` contains acceptance tests
- `lib` contains the main code
- `test` contains unit tests

## When working on acceptance tests

- Use `bin/list-cucumber-steps` to see available steps
- Use `bin/acceptance-tests` to run acceptance tests. You MUST do this after
  every change unless the user explicitly requests otherwise.
