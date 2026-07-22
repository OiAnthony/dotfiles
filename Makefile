.PHONY: build lint test test-shell test-idempotent test-piped test-root test-rtk-migration test-all clean

IMAGE_NAME := dotfiles-test

CONTAINER_RUNTIME := $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null)

PROJECT_PATH := /opt/dotfiles

GITHUB_TOKEN ?= $(shell command -v gh >/dev/null 2>&1 && gh auth token 2>/dev/null)
export GITHUB_TOKEN
CONTAINER_ENV := $(if $(strip $(GITHUB_TOKEN)),--env GITHUB_TOKEN,)

build:
	@echo "Building container image with $(CONTAINER_RUNTIME)..."
	@test -n "$(CONTAINER_RUNTIME)" || { echo "Error: Neither docker nor podman found. Install one of them."; exit 1; }
	$(CONTAINER_RUNTIME) build -t $(IMAGE_NAME) .

lint:
	@echo "Running ShellCheck..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: shellcheck not installed. Run: brew install shellcheck"; exit 1; }
	shellcheck install.sh scripts/*.sh dot_local/bin/executable_benchmark-zsh

test: build
	@echo "Running integration test (testuser)..."
	$(CONTAINER_RUNTIME) run --rm $(CONTAINER_ENV) -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-install.sh

test-shell: build
	@echo "Running Zsh and mise integration test..."
	$(CONTAINER_RUNTIME) run --rm $(CONTAINER_ENV) -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-shell.sh

test-rtk-migration:
	@echo "Running RTK migration test..."
	./scripts/test-rtk-migration.sh

test-idempotent: build
	@echo "Running idempotent test..."
	$(CONTAINER_RUNTIME) run --rm $(CONTAINER_ENV) -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-idempotent.sh

test-piped: build
	@echo "Running piped install regression test..."
	$(CONTAINER_RUNTIME) run --rm $(CONTAINER_ENV) -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-piped-install.sh

test-root: build
	@echo "Running integration test (root)..."
	$(CONTAINER_RUNTIME) run --rm $(CONTAINER_ENV) --env HOME=/root --workdir /root -u 0 $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-install.sh

test-all: lint test test-idempotent test-piped test-root test-rtk-migration
	@echo "All tests passed!"

clean:
	@echo "Removing containers using $(IMAGE_NAME)..."
	$(CONTAINER_RUNTIME) rm -f $$($(CONTAINER_RUNTIME) ps -aq --filter ancestor=$(IMAGE_NAME)) 2>/dev/null || true
	@echo "Removing container image..."
	$(CONTAINER_RUNTIME) rmi -f $(IMAGE_NAME) || true
