# Docker Makefile for Python Project with Poetry
# Usage: make -f docker.Makefile [target]
# Default: help

# === Configuration Variables ===
APP_NAME ?= python-app
PYTHON_VERSION ?= 3.11
POETRY_VERSION ?= 1.7.1
IMAGE_NAME := $(APP_NAME)
IMAGE_TAG ?= latest
CONTAINER_NAME := $(APP_NAME)-container
DOCKERFILE ?= Dockerfile
DOCKER_REGISTRY ?=
PORT ?= 8000
HOST_PORT ?= $(PORT)
BUILD_TARGET ?=

# Conditional --target flag (only used if BUILD_TARGET is set)
TARGET_ARG := $(if $(BUILD_TARGET),--target $(BUILD_TARGET),)

# Build args
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo "no-git")

# Docker run options
DOCKER_RUN_OPTS := --rm -it
DOCKER_RUN_OPTS_DETACHED := -d
VOLUME_MOUNT := -v $(PWD):/app
ENV_FILE := --env-file .env
NETWORK := --network bridge

# Poetry specific
POETRY_CACHE := -v poetry-cache:/root/.cache/pypoetry
POETRY_CONFIG := -v poetry-config:/root/.config/pypoetry

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m # No Color

# === Default Target ===
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)       Docker Makefile for Python Project with Poetry & Pytest$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f docker.Makefile $(GREEN)[target]$(NC)"
	@echo ""
	@echo "$(YELLOW)Build Commands:$(NC)"
	@grep -E '^(build|rebuild)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Container Management:$(NC)"
	@grep -E '^(run|up|down|stop|start|restart|rm|ps)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Poetry Commands:$(NC)"
	@grep -E '^poetry[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Testing (Pytest):$(NC)"
	@grep -E '^test[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Code Quality:$(NC)"
	@grep -E '^(lint|format|typecheck|security|quality)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^(shell|python|ipython|exec|logs|stats|inspect)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@grep -E '^clean[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Docker Utils:$(NC)"
	@grep -E '^(images|volumes|network|prune)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f docker.Makefile build"
	@echo "  $$ make -f docker.Makefile test"
	@echo "  $$ make -f docker.Makefile poetry-install"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Build Commands ===
.PHONY: build
build: ## Build Docker image (use BUILD_TARGET=stage to set target)
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--build-arg POETRY_VERSION=$(POETRY_VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		$(TARGET_ARG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):latest \
		-f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Image built successfully: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"

.PHONY: build-prod
build-prod: ## Build optimized production Docker image
	@echo "$(YELLOW)Building production Docker image...$(NC)"
	docker build \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--build-arg POETRY_VERSION=$(POETRY_VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		--target production \
		-t $(IMAGE_NAME):prod \
		-f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Production image built: $(IMAGE_NAME):prod$(NC)"

.PHONY: build-nocache
rebuild: ## Rebuild Docker image without cache
	@echo "$(YELLOW)Rebuilding Docker image (no cache)...$(NC)"
	docker build --no-cache \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
		--build-arg POETRY_VERSION=$(POETRY_VERSION) \
		$(TARGET_ARG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Image rebuilt without cache$(NC)"

# === Container Management ===
.PHONY: run
run: ## Run Docker container with mounted code (handles existing containers)
	@if [ -n "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
		echo "$(YELLOW)Container is running. Stopping and removing...$(NC)"; \
		docker stop $(CONTAINER_NAME) >/dev/null 2>&1; \
		docker rm $(CONTAINER_NAME) >/dev/null 2>&1; \
	elif [ -n "$$(docker ps -aq -f name=$(CONTAINER_NAME))" ]; then \
		echo "$(YELLOW)Container exists but stopped. Removing...$(NC)"; \
		docker rm $(CONTAINER_NAME) >/dev/null 2>&1; \
	fi
	@echo "$(YELLOW)Starting container...$(NC)"
	docker run $(DOCKER_RUN_OPTS) \
		--name $(CONTAINER_NAME) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(POETRY_CONFIG) \
		-p $(HOST_PORT):$(PORT) \
		$(NETWORK) \
		$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: run-detached
up: ## Start container in detached mode
	@echo "$(YELLOW)Starting container in background...$(NC)"
	docker run $(DOCKER_RUN_OPTS_DETACHED) \
		--name $(CONTAINER_NAME) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(POETRY_CONFIG) \
		-p $(HOST_PORT):$(PORT) \
		$(NETWORK) \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ Container started: $(CONTAINER_NAME)$(NC)"

.PHONY: down
down: ## Stop and remove container
	@echo "$(YELLOW)Stopping container...$(NC)"
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "$(GREEN)✓ Container removed$(NC)"

.PHONY: stop
stop: ## Stop running container
	@echo "$(YELLOW)Stopping container...$(NC)"
	@docker stop $(CONTAINER_NAME) 2>/dev/null || echo "Container not running"
	@echo "$(GREEN)✓ Container stopped$(NC)"

.PHONY: start
start: ## Start existing container
	@echo "$(YELLOW)Starting existing container...$(NC)"
	@docker start $(CONTAINER_NAME) 2>/dev/null || echo "Container doesn't exist. Run 'make up' first"

.PHONY: restart
restart: ## Restart container
	@echo "$(YELLOW)Restarting container...$(NC)"
	@docker restart $(CONTAINER_NAME) 2>/dev/null || echo "Container not running"
	@echo "$(GREEN)✓ Container restarted$(NC)"

.PHONY: rm
rm: ## Remove stopped container
	@docker rm $(CONTAINER_NAME) 2>/dev/null || echo "Container doesn't exist"
	@echo "$(GREEN)✓ Container removed$(NC)"

.PHONY: ps
ps: ## List Docker containers for this project
	@echo "$(CYAN)Project containers:$(NC)"
	@docker ps -a --filter "name=$(CONTAINER_NAME)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# === Poetry Commands ===
.PHONY: poetry-install
poetry-install: ## Install dependencies with Poetry
	@echo "$(YELLOW)Installing dependencies with Poetry...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry install --no-interaction --no-ansi
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

.PHONY: poetry-update
poetry-update: ## Update dependencies with Poetry
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry update --no-interaction --no-ansi
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

.PHONY: poetry-add
poetry-add: ## Add a package with Poetry (use PKG=package_name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package_name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding package: $(PKG)...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry add $(PKG)
	@echo "$(GREEN)✓ Package added: $(PKG)$(NC)"

.PHONY: poetry-remove
poetry-remove: ## Remove a package with Poetry (use PKG=package_name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package_name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Removing package: $(PKG)...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry remove $(PKG)
	@echo "$(GREEN)✓ Package removed: $(PKG)$(NC)"

.PHONY: poetry-lock
poetry-lock: ## Update Poetry lock file
	@echo "$(YELLOW)Updating lock file...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry lock --no-update
	@echo "$(GREEN)✓ Lock file updated$(NC)"

.PHONY: poetry-export
poetry-export: ## Export requirements.txt from Poetry
	@echo "$(YELLOW)Exporting requirements.txt...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry export -f requirements.txt --output requirements.txt --without-hashes
	@echo "$(GREEN)✓ requirements.txt exported$(NC)"

.PHONY: pip-install
pip-install: ## Install dependencies from requirements.txt using pip
	@echo "$(YELLOW)Installing dependencies with pip...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		python3 -m pip install -r requirements.txt
	@echo "$(GREEN)✓ Dependencies installed with pip$(NC)"

.PHONY: poetry-shell
poetry-shell: ## Enter Poetry virtual environment shell
	@echo "$(CYAN)Entering Poetry shell...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(POETRY_CONFIG) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry shell

# === Testing with Pytest ===
.PHONY: test
test: ## Run all tests with pytest
	@echo "$(YELLOW)Running tests with pytest...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest
	@echo "$(GREEN)✓ Tests completed$(NC)"

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	@echo "$(YELLOW)Running tests with coverage...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest --cov=. --cov-report=html --cov-report=term
	@echo "$(GREEN)✓ Coverage report generated$(NC)"

.PHONY: test-watch
test-watch: ## Run tests in watch mode (auto-rerun on changes)
	@echo "$(YELLOW)Starting test watch mode...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest-watch

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	@echo "$(YELLOW)Running tests (verbose)...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest -vv

.PHONY: test-failed
test-failed: ## Run only failed tests from last run
	@echo "$(YELLOW)Running failed tests...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest --lf

.PHONY: test-marker
test-marker: ## Run tests by marker (use MARKER=marker_name)
	@if [ -z "$(MARKER)" ]; then \
		echo "$(RED)Error: Please specify marker with MARKER=marker_name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running tests with marker: $(MARKER)...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest -m $(MARKER)

.PHONY: test-file
test-file: ## Run specific test file (use FILE=path/to/test.py)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: Please specify file with FILE=path/to/test.py$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running test file: $(FILE)...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run pytest $(FILE)

# === Code Quality ===
.PHONY: lint
lint: ## Run code linting with ruff
	@echo "$(YELLOW)Running linter...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run ruff check .
	@echo "$(GREEN)✓ Linting completed$(NC)"

.PHONY: format
format: ## Format code with black
	@echo "$(YELLOW)Formatting code with black...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run black .
	@echo "$(GREEN)✓ Code formatted$(NC)"

.PHONY: format-check
format-check: ## Check code formatting without changes
	@echo "$(YELLOW)Checking code format...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run black --check .

.PHONY: typecheck
typecheck: ## Run type checking with mypy
	@echo "$(YELLOW)Running type checker...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run mypy .
	@echo "$(GREEN)✓ Type checking completed$(NC)"

.PHONY: security
security: ## Run security checks with bandit
	@echo "$(YELLOW)Running security scan...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run bandit -r .
	@echo "$(GREEN)✓ Security scan completed$(NC)"

.PHONY: quality
quality: lint format-check typecheck security ## Run all code quality checks
	@echo "$(GREEN)✓ All quality checks completed$(NC)"

# === Development Commands ===
.PHONY: shell
shell: ## Open bash shell in container
	@echo "$(CYAN)Opening shell in container...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(POETRY_CONFIG) \
		-p $(HOST_PORT):$(PORT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash

.PHONY: python
python: ## Open Python REPL in container
	@echo "$(CYAN)Starting Python REPL...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run python

.PHONY: ipython
ipython: ## Open IPython shell in container
	@echo "$(CYAN)Starting IPython...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(POETRY_CACHE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		poetry run ipython

.PHONY: exec
exec: ## Execute command in running container (use CMD="command")
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify command with CMD=\"command\"$(NC)"; \
		exit 1; \
	fi
	@docker exec -it $(CONTAINER_NAME) $(CMD)

.PHONY: logs
logs: ## Show container logs
	@echo "$(CYAN)Container logs:$(NC)"
	@docker logs $(CONTAINER_NAME)

.PHONY: logs-follow
logs-follow: ## Follow container logs
	@echo "$(CYAN)Following container logs (Ctrl+C to stop)...$(NC)"
	@docker logs -f $(CONTAINER_NAME)

.PHONY: stats
stats: ## Show container resource usage
	@echo "$(CYAN)Container statistics:$(NC)"
	@docker stats --no-stream $(CONTAINER_NAME)

.PHONY: inspect
inspect: ## Inspect container details
	@docker inspect $(CONTAINER_NAME) | jq '.[0] | {Name: .Name, State: .State, Mounts: .Mounts, NetworkSettings: .NetworkSettings.Ports}'

# === Cleanup Commands ===
.PHONY: clean
clean: down ## Remove container and image
	@echo "$(YELLOW)Cleaning up container and image...$(NC)"
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

.PHONY: clean-cache
clean-cache: ## Clear Poetry and pip caches
	@echo "$(YELLOW)Clearing caches...$(NC)"
	@docker volume rm poetry-cache 2>/dev/null || true
	@docker volume rm poetry-config 2>/dev/null || true
	@echo "$(GREEN)✓ Caches cleared$(NC)"

.PHONY: clean-all
clean-all: clean clean-cache ## Full cleanup including volumes
	@echo "$(YELLOW)Performing full cleanup...$(NC)"
	@docker rmi $(IMAGE_NAME):prod 2>/dev/null || true
	@docker volume prune -f
	@echo "$(GREEN)✓ Full cleanup completed$(NC)"

.PHONY: clean-pyc
clean-pyc: ## Remove Python cache files
	@echo "$(YELLOW)Removing Python cache files...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		find . -type f -name "*.pyc" -delete
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		find . -type d -name "__pycache__" -delete
	@echo "$(GREEN)✓ Python cache cleaned$(NC)"

# === Docker Utilities ===
.PHONY: images
images: ## List Docker images for this project
	@echo "$(CYAN)Project images:$(NC)"
	@docker images --filter "reference=$(IMAGE_NAME)*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

.PHONY: volumes
volumes: ## List Docker volumes
	@echo "$(CYAN)Docker volumes:$(NC)"
	@docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

.PHONY: network
network: ## Show network information
	@echo "$(CYAN)Network information:$(NC)"
	@docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

.PHONY: prune
prune: ## Clean up Docker system (remove unused data)
	@echo "$(YELLOW)Pruning Docker system...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ System pruned$(NC)"

.PHONY: prune-all
prune-all: ## Aggressive cleanup (includes volumes)
	@echo "$(RED)WARNING: This will remove all unused Docker data including volumes!$(NC)"
	@echo "$(YELLOW)Pruning everything...$(NC)"
	@docker system prune -af --volumes
	@echo "$(GREEN)✓ Everything pruned$(NC)"

# === Utility Functions ===
.PHONY: check-docker
check-docker: ## Verify Docker installation
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Docker is not installed$(NC)"; exit 1; }
	@docker --version
	@echo "$(GREEN)✓ Docker is installed$(NC)"

.PHONY: info
info: ## Show project information
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Project Information:$(NC)"
	@echo "  App Name:        $(APP_NAME)"
	@echo "  Python Version:  $(PYTHON_VERSION)"
	@echo "  Poetry Version:  $(POETRY_VERSION)"
	@echo "  Image Name:      $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  Container Name:  $(CONTAINER_NAME)"
	@echo "  Port Mapping:    $(HOST_PORT):$(PORT)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: validate
validate: ## Validate Dockerfile exists
	@if [ ! -f $(DOCKERFILE) ]; then \
		echo "$(RED)Error: $(DOCKERFILE) not found$(NC)"; \
		echo "$(YELLOW)Please create a Dockerfile first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ $(DOCKERFILE) exists$(NC)"