.PHONY: build lint test test-idempotent test-piped test-root test-all clean

IMAGE_NAME := dotfiles-test

CONTAINER_RUNTIME := $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null)

PROJECT_PATH := /opt/dotfiles

build:
	@echo "Building container image with $(CONTAINER_RUNTIME)..."
	@test -n "$(CONTAINER_RUNTIME)" || { echo "Error: Neither docker nor podman found. Install one of them."; exit 1; }
	$(CONTAINER_RUNTIME) build -t $(IMAGE_NAME) .

lint:
	@echo "Running ShellCheck..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: shellcheck not installed. Run: brew install shellcheck"; exit 1; }
	shellcheck install.sh

test: build
	@echo "Running integration test (testuser)..."
	$(CONTAINER_RUNTIME) run --rm -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-install.sh

test-idempotent: build
	@echo "Running idempotent test..."
	$(CONTAINER_RUNTIME) run --rm -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-idempotent.sh

test-piped: build
	@echo "Running piped install regression test..."
	$(CONTAINER_RUNTIME) run --rm -u testuser $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-piped-install.sh

test-root: build
	@echo "Running integration test (root)..."
	$(CONTAINER_RUNTIME) run --rm -u 0 $(IMAGE_NAME) $(PROJECT_PATH)/scripts/test-install.sh

test-all: lint test test-idempotent test-piped test-root
	@echo "All tests passed!"

clean:
	@echo "Removing containers using $(IMAGE_NAME)..."
	$(CONTAINER_RUNTIME) rm -f $$($(CONTAINER_RUNTIME) ps -aq --filter ancestor=$(IMAGE_NAME)) 2>/dev/null || true
	@echo "Removing container image..."
	$(CONTAINER_RUNTIME) rmi -f $(IMAGE_NAME) || true
