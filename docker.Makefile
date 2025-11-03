# Docker Makefile for General Projects
# Usage: make -f docker.Makefile [target]
# Default: help

# === Configuration Variables ===
APP_NAME ?= my-app
IMAGE_NAME := $(APP_NAME)
IMAGE_TAG ?= latest
CONTAINER_NAME := $(APP_NAME)-container
DOCKERFILE ?= Dockerfile
DOCKER_REGISTRY ?=
PORT ?= 8080
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
	@echo "$(WHITE)                  Docker Makefile for General Projects$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f docker.Makefile $(GREEN)[target]$(NC)"
	@echo ""
	@echo "$(YELLOW)Build Commands:$(NC)"
	@grep -E '^(build|rebuild|tag|push|pull)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Container Management:$(NC)"
	@grep -E '^(run|up|down|stop|start|restart|rm|ps)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^(shell|exec|logs|stats|inspect)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@grep -E '^clean[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Docker Utils:$(NC)"
	@grep -E '^(images|volumes|network|prune|compose)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f docker.Makefile build"
	@echo "  $$ make -f docker.Makefile run"
	@echo "  $$ make -f docker.Makefile shell"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Build Commands ===
.PHONY: build
build: ## Build Docker image (use BUILD_TARGET=stage to set target)
	@echo "$(YELLOW)Building Docker image...$(NC)"
	docker build \
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
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		--target production \
		-t $(IMAGE_NAME):prod \
		-f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Production image built: $(IMAGE_NAME):prod$(NC)"

.PHONY: rebuild
rebuild: ## Rebuild Docker image without cache
	@echo "$(YELLOW)Rebuilding Docker image (no cache)...$(NC)"
	docker build --no-cache \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		$(TARGET_ARG) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Image rebuilt without cache$(NC)"

.PHONY: tag
tag: ## Tag image for registry (use REGISTRY=host TAG=version)
	@if [ -z "$(REGISTRY)" ]; then \
		echo "$(RED)Error: Please specify REGISTRY=host$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Tagging image for $(REGISTRY)...$(NC)"
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ Image tagged: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)$(NC)"

.PHONY: push
push: ## Push image to registry (use REGISTRY=host)
	@if [ -z "$(REGISTRY)" ]; then \
		echo "$(RED)Error: Please specify REGISTRY=host$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Pushing image to $(REGISTRY)...$(NC)"
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ Image pushed$(NC)"

.PHONY: pull
pull: ## Pull image from registry (use REGISTRY=host)
	@if [ -z "$(REGISTRY)" ]; then \
		echo "$(RED)Error: Please specify REGISTRY=host$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Pulling image from $(REGISTRY)...$(NC)"
	docker pull $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ Image pulled$(NC)"

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
		-p $(HOST_PORT):$(PORT) \
		$(NETWORK) \
		$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: run-detached
up: ## Start container in detached mode
	@echo "$(YELLOW)Starting container in background...$(NC)"
	docker run $(DOCKER_RUN_OPTS_DETACHED) \
		--name $(CONTAINER_NAME) \
		$(VOLUME_MOUNT) \
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

# === Development Commands ===
.PHONY: shell
shell: ## Open shell in container
	@echo "$(CYAN)Opening shell in container...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		-p $(HOST_PORT):$(PORT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/sh

.PHONY: bash
bash: ## Open bash shell in container
	@echo "$(CYAN)Opening bash shell in container...$(NC)"
	@docker run $(DOCKER_RUN_OPTS) \
		$(VOLUME_MOUNT) \
		-p $(HOST_PORT):$(PORT) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash

.PHONY: exec
exec: ## Execute command in running container (use CMD="command")
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify command with CMD=\"command\"$(NC)"; \
		exit 1; \
	fi
	@docker exec -it $(CONTAINER_NAME) $(CMD)

.PHONY: exec-shell
exec-shell: ## Open shell in running container
	@echo "$(CYAN)Opening shell in running container...$(NC)"
	@docker exec -it $(CONTAINER_NAME) /bin/sh

.PHONY: exec-bash
exec-bash: ## Open bash in running container
	@echo "$(CYAN)Opening bash in running container...$(NC)"
	@docker exec -it $(CONTAINER_NAME) /bin/bash

.PHONY: logs
logs: ## Show container logs
	@echo "$(CYAN)Container logs:$(NC)"
	@docker logs $(CONTAINER_NAME)

.PHONY: logs-follow
logs-follow: ## Follow container logs
	@echo "$(CYAN)Following container logs (Ctrl+C to stop)...$(NC)"
	@docker logs -f $(CONTAINER_NAME)

.PHONY: logs-tail
logs-tail: ## Show last N lines of logs (use LINES=number, default 100)
	@echo "$(CYAN)Last $(or $(LINES),100) lines of logs:$(NC)"
	@docker logs --tail $(or $(LINES),100) $(CONTAINER_NAME)

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

.PHONY: clean-all
clean-all: clean ## Full cleanup including all image tags
	@echo "$(YELLOW)Performing full cleanup...$(NC)"
	@docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	@docker rmi $(IMAGE_NAME):prod 2>/dev/null || true
	@docker volume prune -f
	@echo "$(GREEN)✓ Full cleanup completed$(NC)"

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

# === Docker Compose Integration ===
.PHONY: compose-up
compose-up: ## Start services with docker-compose
	@echo "$(YELLOW)Starting services with docker-compose...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"

.PHONY: compose-down
compose-down: ## Stop services with docker-compose
	@echo "$(YELLOW)Stopping services with docker-compose...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

.PHONY: compose-logs
compose-logs: ## Show docker-compose logs
	@docker-compose logs

.PHONY: compose-ps
compose-ps: ## List docker-compose services
	@docker-compose ps

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
	@echo "  Image Name:      $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "  Container Name:  $(CONTAINER_NAME)"
	@echo "  Port Mapping:    $(HOST_PORT):$(PORT)"
	@echo "  Dockerfile:      $(DOCKERFILE)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: validate
validate: ## Validate Dockerfile exists
	@if [ ! -f $(DOCKERFILE) ]; then \
		echo "$(RED)Error: $(DOCKERFILE) not found$(NC)"; \
		echo "$(YELLOW)Please create a Dockerfile first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ $(DOCKERFILE) exists$(NC)"
