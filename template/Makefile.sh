#!/bin/bash

cat <<EOF > "${GIT_ROOT}/Makefile"
GO_MODULE := \$(shell git config --get remote.origin.url | grep -o 'github\.com[:/][^.]*' | tr ':' '/')
CMD_NAME := \$(shell basename \${GO_MODULE})
VERSION := \$(shell grep '^const Version =' internal/version/version.go | cut -d\" -f2)

RUN ?= .*
PKG ?= ./...
.PHONY: test
test: ## Run tests in local environment
	golangci-lint run --timeout=5m \$(PKG)
	go test -cover -run=\$(RUN) \$(PKG)

.PHONY: docker
docker: ## Build local development docker image with cached go modules, builds, and tests
	@docker build -f build/Dockerfile-test -t \$(CMD_NAME)-test:latest .

.PHONY: docker-test
docker-test: ## Run tests using local development docker image
	@docker run -v \$(shell pwd):/go/src/\$(GO_MODULE):delegated \$(CMD_NAME)-test make test RUN=\$(RUN) PKG=\$(PKG)

.PHONY: docker-snyk
docker-snyk: ## Run local snyk scan, SNYK_TOKEN environment variable must be set
	@docker run --rm -e SNYK_TOKEN -w /go/src/\$(GO_MODULE) -v \$(shell pwd):/go/src/\$(GO_MODULE):delegated snyk/snyk:golang

.PHONY: docker-run
docker-run: ## Build and run the application in a local docker container
	@docker build -t \$(CMD_NAME):latest .
	@docker run -p ${DEFAULT_APP_PORT}:${DEFAULT_APP_PORT} \$(CMD_NAME):latest

dist: ## Cross compile binaries into ./dist/
	mkdir bin dist
	GOOS=linux GOARCH=amd64 go build -o ./bin/\$(CMD_NAME) .
	tar -zcvf dist/\$(CMD_NAME)-linux-\$(VERSION).tgz ./bin/\$(CMD_NAME) README.md
	GOOS=darwin GOARCH=amd64 go build -o ./bin/\$(CMD_NAME) .
	tar -zcvf dist/\$(CMD_NAME)-macos-\$(VERSION).tgz ./bin/\$(CMD_NAME) README.md

.PHONY: clean
clean: ## Clean up release artifacts
	rm -rf ./bin ./dist

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*\$\$' \$(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", \$\$1, \$\$2}'
EOF
