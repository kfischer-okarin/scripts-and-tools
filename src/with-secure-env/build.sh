#!/bin/sh
mkdir -p bin
go build -o bin/with-secure-env ./cmd/with-secure-env/
go build -o bin/edit-dialog-test ./cmd/edit-dialog-test/
go build -o bin/permission-dialog-test ./cmd/permission-dialog-test/
