# NPM Workspace Makefile
# Usage: make -f npm-workspace.Makefile [target]
# Default: help

# === Configuration Variables ===
WORKSPACE_NAME ?= my-workspace
NODE_VERSION ?= 20
PKG_MANAGER ?= npm
WORKSPACES_DIR ?= packages
APPS_DIR ?= apps
LIBS_DIR ?= libs
PACKAGE_SCOPE ?= @myorg
BUILD_DIR ?= dist
COVERAGE_DIR ?= coverage

# Package manager commands
ifeq ($(PKG_MANAGER),pnpm)
	PM_INSTALL := pnpm install
	PM_ADD := pnpm add
	PM_REMOVE := pnpm remove
	PM_RUN := pnpm run
	PM_EXEC := pnpm exec
	PM_WORKSPACE := pnpm --filter
else ifeq ($(PKG_MANAGER),yarn)
	PM_INSTALL := yarn install
	PM_ADD := yarn add
	PM_REMOVE := yarn remove
	PM_RUN := yarn run
	PM_EXEC := yarn
	PM_WORKSPACE := yarn workspace
else
	PM_INSTALL := npm install
	PM_ADD := npm install
	PM_REMOVE := npm uninstall
	PM_RUN := npm run
	PM_EXEC := npm exec --
	PM_WORKSPACE := npm --workspace
endif

# Build timestamp
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo "no-git")

# Colors for output
RED := \\033[0;31m
GREEN := \\033[0;32m
YELLOW := \\033[1;33m
BLUE := \\033[0;34m
PURPLE := \\033[0;35m
CYAN := \\033[0;36m
WHITE := \\033[1;37m
NC := \\033[0m # No Color

# === Default Target ===
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)              NPM Workspace Makefile for Monorepos$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f npm-workspace.Makefile $(GREEN)[target]$(NC)"
	@echo ""
	@echo "$(YELLOW)Workspace Initialization:$(NC)"
	@grep -E '^(init|add-package|add-app|add-lib)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Package Management:$(NC)"
	@grep -E '^(install|update|add-dep|remove-dep|outdated|dedupe|audit)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Build Commands:$(NC)"
	@grep -E '^(build|rebuild|watch)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@grep -E '^test[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Code Quality:$(NC)"
	@grep -E '^(lint|format|typecheck|quality)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^(dev|run-script|node-repl|exec)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Workspace Management:$(NC)"
	@grep -E '^(list|link|foreach|graph|changed)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@grep -E '^clean[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@grep -E '^(info|check-node|validate|version)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f npm-workspace.Makefile init"
	@echo "  $$ make -f npm-workspace.Makefile add-package NAME=shared-ui"
	@echo "  $$ make -f npm-workspace.Makefile test"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Workspace Initialization ===
.PHONY: init
init: ## Initialize a new npm workspace
	@echo "$(YELLOW)Initializing npm workspace: $(WORKSPACE_NAME)...$(NC)"
	@if [ -f package.json ]; then \
		echo "$(RED)Error: package.json already exists$(NC)"; \
		exit 1; \
	fi
	@mkdir -p $(WORKSPACES_DIR) $(APPS_DIR) $(LIBS_DIR)
	@echo '{\n  "name": "$(WORKSPACE_NAME)",\n  "version": "1.0.0",\n  "private": true,\n  "workspaces": [\n    "$(WORKSPACES_DIR)/*",\n    "$(APPS_DIR)/*",\n    "$(LIBS_DIR)/*"\n  ],\n  "scripts": {\n    "build": "npm run build --workspaces",\n    "test": "npm run test --workspaces",\n    "lint": "npm run lint --workspaces",\n    "dev": "npm run dev --workspaces"\n  },\n  "devDependencies": {}\n}' | sed 's/\\n/\n/g' > package.json
	@echo "$(GREEN)✓ Workspace initialized: $(WORKSPACE_NAME)$(NC)"
	@echo "$(CYAN)Created directories: $(WORKSPACES_DIR), $(APPS_DIR), $(LIBS_DIR)$(NC)"

.PHONY: add-package
add-package: ## Create a new package (use NAME=package-name TYPE=app|lib)
	@if [ -z "$(NAME)" ]; then \
		echo "$(RED)Error: Please specify package name with NAME=package-name$(NC)"; \
		exit 1; \
	fi
	@TYPE_DIR=$(WORKSPACES_DIR); \
	if [ "$(TYPE)" = "app" ]; then TYPE_DIR=$(APPS_DIR); \
	elif [ "$(TYPE)" = "lib" ]; then TYPE_DIR=$(LIBS_DIR); \
	fi; \
	PKG_DIR=$$TYPE_DIR/$(NAME); \
	if [ -d $$PKG_DIR ]; then \
		echo "$(RED)Error: Package already exists: $$PKG_DIR$(NC)"; \
		exit 1; \
	fi; \
	echo "$(YELLOW)Creating package: $$PKG_DIR...$(NC)"; \
	mkdir -p $$PKG_DIR/src; \
	echo '{\n  "name": "$(PACKAGE_SCOPE)/$(NAME)",\n  "version": "1.0.0",\n  "main": "./dist/index.js",\n  "types": "./dist/index.d.ts",\n  "scripts": {\n    "build": "tsc",\n    "test": "jest",\n    "lint": "eslint src",\n    "dev": "tsc --watch"\n  },\n  "dependencies": {},\n  "devDependencies": {}\n}' | sed 's/\\n/\n/g' > $$PKG_DIR/package.json; \
	echo 'export const hello = () => "Hello from $(NAME)";' > $$PKG_DIR/src/index.ts; \
	echo "$(GREEN)✓ Package created: $(PACKAGE_SCOPE)/$(NAME)$(NC)"

.PHONY: add-app
add-app: ## Create a new app package (use NAME=app-name)
	@$(MAKE) -f $(MAKEFILE_LIST) add-package NAME=$(NAME) TYPE=app

.PHONY: add-lib
add-lib: ## Create a new library package (use NAME=lib-name)
	@$(MAKE) -f $(MAKEFILE_LIST) add-package NAME=$(NAME) TYPE=lib

# === Package Management ===
.PHONY: install
install: ## Install all workspace dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@$(PM_INSTALL)
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

.PHONY: install-package
install-package: ## Install dependencies for specific package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Installing dependencies for $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) install
	@echo "$(GREEN)✓ Dependencies installed for $(PKG)$(NC)"

.PHONY: update
update: ## Update all dependencies
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@$(PM_INSTALL) --update-all 2>/dev/null || npm update
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

.PHONY: add-dep
add-dep: ## Add dependency to package (use PKG=package-name DEP=dependency)
	@if [ -z "$(PKG)" ] || [ -z "$(DEP)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name DEP=dependency$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding $(DEP) to $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) $(PM_ADD) $(DEP)
	@echo "$(GREEN)✓ Dependency added$(NC)"

.PHONY: add-dev-dep
add-dev-dep: ## Add dev dependency to package (use PKG=package-name DEP=dependency)
	@if [ -z "$(PKG)" ] || [ -z "$(DEP)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name DEP=dependency$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding $(DEP) to $(PKG) (dev)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) $(PM_ADD) -D $(DEP)
	@echo "$(GREEN)✓ Dev dependency added$(NC)"

.PHONY: remove-dep
remove-dep: ## Remove dependency from package (use PKG=package-name DEP=dependency)
	@if [ -z "$(PKG)" ] || [ -z "$(DEP)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name DEP=dependency$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Removing $(DEP) from $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) $(PM_REMOVE) $(DEP)
	@echo "$(GREEN)✓ Dependency removed$(NC)"

.PHONY: outdated
outdated: ## Check for outdated dependencies
	@echo "$(CYAN)Checking for outdated dependencies...$(NC)"
	@npm outdated || true

.PHONY: dedupe
dedupe: ## Deduplicate dependencies
	@echo "$(YELLOW)Deduplicating dependencies...$(NC)"
	@npm dedupe
	@echo "$(GREEN)✓ Dependencies deduplicated$(NC)"

.PHONY: audit
audit: ## Run security audit
	@echo "$(YELLOW)Running security audit...$(NC)"
	@npm audit
	@echo "$(GREEN)✓ Audit completed$(NC)"

.PHONY: audit-fix
audit-fix: ## Fix security vulnerabilities automatically
	@echo "$(YELLOW)Fixing security vulnerabilities...$(NC)"
	@npm audit fix
	@echo "$(GREEN)✓ Vulnerabilities fixed$(NC)"

# === Build Commands ===
.PHONY: build
build: ## Build all packages in workspace
	@echo "$(YELLOW)Building all packages...$(NC)"
	@npm run build --workspaces --if-present
	@echo "$(GREEN)✓ All packages built$(NC)"

.PHONY: build-package
build-package: ## Build specific package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Building package: $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) run build
	@echo "$(GREEN)✓ Package built: $(PKG)$(NC)"

.PHONY: build-watch
watch: ## Build all packages in watch mode
	@echo "$(YELLOW)Starting build watch mode...$(NC)"
	@npm run dev --workspaces --if-present

.PHONY: rebuild
rebuild: clean-dist build ## Clean and rebuild all packages
	@echo "$(GREEN)✓ Rebuild completed$(NC)"

# === Testing ===
.PHONY: test
test: ## Run all tests in workspace
	@echo "$(YELLOW)Running all tests...$(NC)"
	@npm run test --workspaces --if-present
	@echo "$(GREEN)✓ All tests completed$(NC)"

.PHONY: test-package
test-package: ## Run tests for specific package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Testing package: $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) run test
	@echo "$(GREEN)✓ Tests completed for $(PKG)$(NC)"

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	@echo "$(YELLOW)Running tests with coverage...$(NC)"
	@npm run test:cov --workspaces --if-present || \
		npm run test -- --coverage --workspaces --if-present
	@echo "$(GREEN)✓ Coverage report generated in $(COVERAGE_DIR)$(NC)"

.PHONY: test-watch
test-watch: ## Run tests in watch mode
	@echo "$(YELLOW)Starting test watch mode...$(NC)"
	@npm run test:watch --workspaces --if-present || \
		npm run test -- --watch --workspaces --if-present

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	@echo "$(YELLOW)Running tests (verbose)...$(NC)"
	@npm run test -- --verbose --workspaces --if-present

.PHONY: test-changed
test-changed: ## Run tests only for changed packages
	@echo "$(YELLOW)Testing changed packages...$(NC)"
	@npm run test --workspaces --if-present -- --onlyChanged

# === Code Quality ===
.PHONY: lint
lint: ## Run linting on all packages
	@echo "$(YELLOW)Running linter...$(NC)"
	@npm run lint --workspaces --if-present
	@echo "$(GREEN)✓ Linting completed$(NC)"

.PHONY: lint-fix
lint-fix: ## Fix linting issues automatically
	@echo "$(YELLOW)Fixing linting issues...$(NC)"
	@npm run lint:fix --workspaces --if-present || \
		npm run lint -- --fix --workspaces --if-present
	@echo "$(GREEN)✓ Linting issues fixed$(NC)"

.PHONY: format
format: ## Format code with Prettier
	@echo "$(YELLOW)Formatting code...$(NC)"
	@$(PM_EXEC) prettier --write "**/*.{js,jsx,ts,tsx,json,md,yml,yaml}"
	@echo "$(GREEN)✓ Code formatted$(NC)"

.PHONY: format-check
format-check: ## Check code formatting without changes
	@echo "$(YELLOW)Checking code format...$(NC)"
	@$(PM_EXEC) prettier --check "**/*.{js,jsx,ts,tsx,json,md,yml,yaml}"
	@echo "$(GREEN)✓ Format check completed$(NC)"

.PHONY: typecheck
typecheck: ## Run TypeScript type checking
	@echo "$(YELLOW)Running type checker...$(NC)"
	@npm run typecheck --workspaces --if-present || \
		$(PM_EXEC) tsc --noEmit
	@echo "$(GREEN)✓ Type checking completed$(NC)"

.PHONY: quality
quality: lint format-check typecheck ## Run all code quality checks
	@echo "$(GREEN)✓ All quality checks completed$(NC)"

# === Development ===
.PHONY: dev
dev: ## Start development servers for all packages
	@echo "$(CYAN)Starting development servers...$(NC)"
	@npm run dev --workspaces --if-present

.PHONY: dev-package
dev-package: ## Start dev server for specific package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Starting dev server for $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) run dev

.PHONY: run-script
run-script: ## Run script in package (use PKG=package-name SCRIPT=script-name)
	@if [ -z "$(PKG)" ] || [ -z "$(SCRIPT)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name SCRIPT=script-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running $(SCRIPT) in $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) run $(SCRIPT)

.PHONY: node-repl
node-repl: ## Open Node.js REPL with workspace context
	@echo "$(CYAN)Starting Node.js REPL...$(NC)"
	@node

.PHONY: exec
exec: ## Execute command in package (use PKG=package-name CMD="command")
	@if [ -z "$(PKG)" ] || [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name CMD=\"command\"$(NC)"; \
		exit 1; \
	fi
	@$(PM_WORKSPACE) $(PKG) exec $(CMD)

# === Workspace Management ===
.PHONY: list
list: ## List all packages in workspace
	@echo "$(CYAN)Workspace packages:$(NC)"
	@npm ls --workspaces --depth=0

.PHONY: list-scripts
list-scripts: ## List available scripts across all packages
	@echo "$(CYAN)Available scripts:$(NC)"
	@for dir in $(WORKSPACES_DIR)/* $(APPS_DIR)/* $(LIBS_DIR)/*; do \
		if [ -f "$$dir/package.json" ]; then \
			echo "$(YELLOW)$$dir:$(NC)"; \
			cat "$$dir/package.json" | grep -A 20 '"scripts"' | grep -v '"scripts"' | grep ':' | sed 's/^/  /'; \
		fi \
	done

.PHONY: link
link: ## Link workspace packages together
	@echo "$(YELLOW)Linking workspace packages...$(NC)"
	@npm link --workspaces
	@echo "$(GREEN)✓ Packages linked$(NC)"

.PHONY: foreach
foreach: ## Run command in all packages (use CMD="command")
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: Please specify CMD=\"command\"$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running command in all packages: $(CMD)$(NC)"
	@for dir in $(WORKSPACES_DIR)/* $(APPS_DIR)/* $(LIBS_DIR)/*; do \
		if [ -d "$$dir" ]; then \
			echo "$(CYAN)→ $$dir$(NC)"; \
			cd "$$dir" && $(CMD); \
		fi \
	done
	@echo "$(GREEN)✓ Command executed in all packages$(NC)"

.PHONY: graph
graph: ## Show package dependency graph
	@echo "$(CYAN)Package dependency graph:$(NC)"
	@npm ls --all --workspaces 2>/dev/null || echo "Run 'npm install' first"

.PHONY: changed
changed: ## List packages changed since last commit
	@echo "$(CYAN)Changed packages:$(NC)"
	@git diff --name-only HEAD | grep package.json | xargs dirname | sort -u

# === Cleanup ===
.PHONY: clean
clean: ## Remove all node_modules directories
	@echo "$(YELLOW)Removing node_modules...$(NC)"
	@find . -name "node_modules" -type d -prune -exec rm -rf {} \;
	@echo "$(GREEN)✓ node_modules removed$(NC)"

.PHONY: clean-dist
clean-dist: ## Remove all build artifacts
	@echo "$(YELLOW)Removing build artifacts...$(NC)"
	@find . -name "$(BUILD_DIR)" -type d -prune -exec rm -rf {} \;
	@find . -name "*.tsbuildinfo" -delete
	@echo "$(GREEN)✓ Build artifacts removed$(NC)"

.PHONY: clean-cache
clean-cache: ## Clear npm/yarn/pnpm cache
	@echo "$(YELLOW)Clearing package manager cache...$(NC)"
	@if [ "$(PKG_MANAGER)" = "pnpm" ]; then \
		pnpm store prune; \
	elif [ "$(PKG_MANAGER)" = "yarn" ]; then \
		yarn cache clean; \
	else \
		npm cache clean --force; \
	fi
	@echo "$(GREEN)✓ Cache cleared$(NC)"

.PHONY: clean-coverage
clean-coverage: ## Remove coverage reports
	@echo "$(YELLOW)Removing coverage reports...$(NC)"
	@find . -name "$(COVERAGE_DIR)" -type d -prune -exec rm -rf {} \;
	@find . -name ".nyc_output" -type d -prune -exec rm -rf {} \;
	@echo "$(GREEN)✓ Coverage reports removed$(NC)"

.PHONY: clean-all
clean-all: clean clean-dist clean-cache clean-coverage ## Full cleanup
	@echo "$(GREEN)✓ Full cleanup completed$(NC)"

# === Utilities ===
.PHONY: check-node
check-node: ## Verify Node.js installation
	@command -v node >/dev/null 2>&1 || { echo "$(RED)Node.js is not installed$(NC)"; exit 1; }
	@echo "$(CYAN)Node.js version:$(NC)"
	@node --version
	@echo "$(CYAN)npm version:$(NC)"
	@npm --version
	@echo "$(GREEN)✓ Node.js is installed$(NC)"

.PHONY: info
info: ## Show workspace information
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Workspace Information:$(NC)"
	@echo "  Workspace Name:   $(WORKSPACE_NAME)"
	@echo "  Node Version:     $(NODE_VERSION)"
	@echo "  Package Manager:  $(PKG_MANAGER)"
	@echo "  Workspaces Dir:   $(WORKSPACES_DIR)"
	@echo "  Apps Dir:         $(APPS_DIR)"
	@echo "  Libs Dir:         $(LIBS_DIR)"
	@echo "  Package Scope:    $(PACKAGE_SCOPE)"
	@echo "  Build Dir:        $(BUILD_DIR)"
	@echo "  Git Ref:          $(GIT_REF)"
	@echo "  Build Date:       $(BUILD_DATE)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: validate
validate: ## Validate workspace structure and package.json files
	@echo "$(YELLOW)Validating workspace...$(NC)"
	@if [ ! -f package.json ]; then \
		echo "$(RED)Error: Root package.json not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Root package.json exists$(NC)"
	@for dir in $(WORKSPACES_DIR)/* $(APPS_DIR)/* $(LIBS_DIR)/*; do \
		if [ -d "$$dir" ]; then \
			if [ ! -f "$$dir/package.json" ]; then \
				echo "$(RED)Error: Missing package.json in $$dir$(NC)"; \
				exit 1; \
			fi; \
		fi \
	done
	@echo "$(GREEN)✓ All packages have package.json$(NC)"
	@echo "$(GREEN)✓ Workspace validation completed$(NC)"

.PHONY: version
version: ## Display current version of all packages
	@echo "$(CYAN)Package versions:$(NC)"
	@for dir in $(WORKSPACES_DIR)/* $(APPS_DIR)/* $(LIBS_DIR)/*; do \
		if [ -f "$$dir/package.json" ]; then \
			name=$$(cat "$$dir/package.json" | grep '"name"' | head -1 | cut -d'"' -f4); \
			version=$$(cat "$$dir/package.json" | grep '"version"' | head -1 | cut -d'"' -f4); \
			echo "  $(GREEN)$$name$(NC) → $$version"; \
		fi \
	done

.PHONY: bump-version
bump-version: ## Bump version for package (use PKG=package-name TYPE=major|minor|patch)
	@if [ -z "$(PKG)" ] || [ -z "$(TYPE)" ]; then \
		echo "$(RED)Error: Please specify PKG=package-name TYPE=major|minor|patch$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Bumping $(TYPE) version for $(PKG)...$(NC)"
	@$(PM_WORKSPACE) $(PKG) version $(TYPE)
	@echo "$(GREEN)✓ Version bumped$(NC)"
