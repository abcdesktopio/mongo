SHELL := /bin/sh
.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Variables — all overridable at the command line, e.g.: make scan IMAGE_TAG=safe8.0
# ------------------------------------------------------------------------------
IMAGE_NAME        ?= ghcr.io/abcdesktopio/mongo
IMAGE_TAG         ?= safe8.0
IMAGE             := $(IMAGE_NAME):$(IMAGE_TAG)

# Name of the CI tooling image (hadolint + trivy)
TESTS_IMAGE       ?= mongo-ci-tools
# Hadolint version pinned in the CI image
HADOLINT_VERSION  ?= v2.14.0
# Trivy version pinned in the CI image
TRIVY_VERSION     ?= 0.72.0

# Directory containing the CI Dockerfile and scripts
TESTS_DIR         := tests
# Output directory for generated reports
REPORTS_DIR       := reports
# Docker socket — needed for image scanning
DOCKER_SOCK       := /var/run/docker.sock

.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the mongo Docker image from the root Dockerfile
	docker build -t $(IMAGE) .

# Stamp file used to track whether the CI tooling image is up to date.
# Make compares its modification time against the source files listed as
# prerequisites; the image is only rebuilt when a source file is newer.
TESTS_STAMP := .build-tests.stamp

.PHONY: build-tests
build-tests: $(TESTS_STAMP) ## Build the CI tooling image (pinned hadolint + trivy versions)

# The actual build rule depends on the Dockerfile and all scripts in bin/.
# Touch the stamp file on success so subsequent calls are skipped.
$(TESTS_STAMP): $(TESTS_DIR)/Dockerfile $(wildcard $(TESTS_DIR)/bin/*)
	docker build \
		--build-arg HADOLINT_VERSION=$(HADOLINT_VERSION) \
		--build-arg TRIVY_VERSION=$(TRIVY_VERSION) \
		-f $(TESTS_DIR)/Dockerfile \
		-t $(TESTS_IMAGE) \
		$(TESTS_DIR)
	@touch $(TESTS_STAMP)

.PHONY: shell
shell: build-tests ## Open an interactive shell inside the CI tooling image (useful for debugging)
	docker run --rm -it \
		-v $(DOCKER_SOCK):$(DOCKER_SOCK) \
		-v "$(CURDIR):/workspace:rw" \
		-w /workspace \
		$(TESTS_IMAGE) \
		bash

.PHONY: test
test: hadolint trivy-fs trivy-image ## Run all checks: Dockerfile lint + filesystem scan + image scan (used in CI)

.PHONY: clean
clean: ## Remove generated reports, the CI tooling image and the build stamp
	rm -rf $(REPORTS_DIR) $(TESTS_STAMP)
	docker image rm $(TESTS_IMAGE) >/dev/null 2>&1 || true

.PHONY: hadolint
hadolint: build-tests ## Lint the root Dockerfile with hadolint and produce JUnit + HTML reports
	@mkdir -p $(REPORTS_DIR)/hadolint
	docker run --rm \
		-v "$(CURDIR):/workspace:rw" \
		-w /workspace \
		$(TESTS_IMAGE) \
		run-hadolint.sh

.PHONY: trivy-fs
trivy-fs: build-tests ## Scan the repository for secrets, Dockerfile misconfigs, and dependency vulns
	@mkdir -p $(REPORTS_DIR)/trivy
	docker run --rm \
		-v "$(CURDIR):/workspace:rw" \
		$(TESTS_IMAGE) \
		run-trivy-fs.sh

.PHONY: trivy-image
trivy-image: build build-tests ## Scan the mongo image for CVEs and produce console, HTML, and JSON reports
	@mkdir -p $(REPORTS_DIR)/trivy
	docker run --rm \
		-v $(DOCKER_SOCK):$(DOCKER_SOCK) \
		-v "$(CURDIR)/$(REPORTS_DIR):/workspace/reports" \
		$(TESTS_IMAGE) \
		run-trivy-image.sh $(IMAGE)
