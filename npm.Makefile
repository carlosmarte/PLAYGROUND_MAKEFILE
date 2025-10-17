# NPM Makefile for Node.js Projects
# Usage: make -f npm.Makefile [target]
# Default: help

# === Configuration Variables ===
PROJECT_NAME ?= my-app
NODE_VERSION ?= 20
NPM_VERSION ?= 10
PACKAGE_MANAGER ?= npm
BUILD_DIR ?= dist
COVERAGE_DIR ?= coverage
SRC_DIR ?= src
TEST_DIR ?= test
PORT ?= 3000
ENV ?= development

# Package manager commands (supports npm, yarn, pnpm)
ifeq ($(PACKAGE_MANAGER),pnpm)
	PM_INSTALL := pnpm install --frozen-lockfile
	PM_INSTALL_DEV := pnpm install
	PM_ADD := pnpm add
	PM_REMOVE := pnpm remove
	PM_RUN := pnpm run
	PM_EXEC := pnpm exec
	PM_UPDATE := pnpm update
	LOCKFILE := pnpm-lock.yaml
else ifeq ($(PACKAGE_MANAGER),yarn)
	PM_INSTALL := yarn install --frozen-lockfile
	PM_INSTALL_DEV := yarn install
	PM_ADD := yarn add
	PM_REMOVE := yarn remove
	PM_RUN := yarn run
	PM_EXEC := yarn
	PM_UPDATE := yarn upgrade
	LOCKFILE := yarn.lock
else
	PM_INSTALL := npm ci
	PM_INSTALL_DEV := npm install
	PM_ADD := npm install
	PM_REMOVE := npm uninstall
	PM_RUN := npm run
	PM_EXEC := npm exec --
	PM_UPDATE := npm update
	LOCKFILE := package-lock.json
endif

# Build metadata
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "no-git")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-branch")
VERSION := $(shell node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")

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
	@echo "$(WHITE)            NPM Makefile for Node.js Projects$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f npm.Makefile $(GREEN)[target]$(NC)"
	@echo ""
	@echo "$(YELLOW)Installation:$(NC)"
	@grep -E '^(install|ci)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Dependency Management:$(NC)"
	@grep -E '^(add|remove|update|outdated|audit)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Build Commands:$(NC)"
	@grep -E '^(build|rebuild|watch)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Run Commands:$(NC)"
	@grep -E '^(start|dev|serve|run-script)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@grep -E '^test[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Code Quality:$(NC)"
	@grep -E '^(lint|format|typecheck|security|quality)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^(repl|debug|logs|shell)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@grep -E '^clean[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@grep -E '^(info|validate|check|doctor|publish)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f npm.Makefile ci"
	@echo "  $$ make -f npm.Makefile build"
	@echo "  $$ make -f npm.Makefile test"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Installation ===
.PHONY: ci
ci: ## Clean install using lockfile (npm ci / yarn --frozen-lockfile)
	@echo "$(YELLOW)Installing dependencies from lockfile...$(NC)"
	@if [ ! -f $(LOCKFILE) ]; then \
		echo "$(RED)Error: $(LOCKFILE) not found. Run 'make install' first.$(NC)"; \
		exit 1; \
	fi
	@$(PM_INSTALL)
	@echo "$(GREEN)✓ Dependencies installed from lockfile$(NC)"

.PHONY: install
install: ## Install dependencies (allows updates)
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@$(PM_INSTALL_DEV)
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

.PHONY: install-prod
install-prod: ## Install production dependencies only
	@echo "$(YELLOW)Installing production dependencies...$(NC)"
	@if [ "$(PACKAGE_MANAGER)" = "pnpm" ]; then \
		pnpm install --prod --frozen-lockfile; \
	elif [ "$(PACKAGE_MANAGER)" = "yarn" ]; then \
		yarn install --production --frozen-lockfile; \
	else \
		npm ci --omit=dev; \
	fi
	@echo "$(GREEN)✓ Production dependencies installed$(NC)"

.PHONY: reinstall
reinstall: clean-deps install ## Clean reinstall all dependencies
	@echo "$(GREEN)✓ Reinstall completed$(NC)"

# === Dependency Management ===
.PHONY: add
add: ## Add a dependency (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding package: $(PKG)...$(NC)"
	@$(PM_ADD) $(PKG)
	@echo "$(GREEN)✓ Package added: $(PKG)$(NC)"

.PHONY: add-dev
add-dev: ## Add a dev dependency (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding dev package: $(PKG)...$(NC)"
	@$(PM_ADD) -D $(PKG)
	@echo "$(GREEN)✓ Dev package added: $(PKG)$(NC)"

.PHONY: add-global
add-global: ## Add a global package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Adding global package: $(PKG)...$(NC)"
	@npm install -g $(PKG)
	@echo "$(GREEN)✓ Global package added: $(PKG)$(NC)"

.PHONY: remove
remove: ## Remove a dependency (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Removing package: $(PKG)...$(NC)"
	@$(PM_REMOVE) $(PKG)
	@echo "$(GREEN)✓ Package removed: $(PKG)$(NC)"

.PHONY: update
update: ## Update all dependencies
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@$(PM_UPDATE)
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

.PHONY: update-package
update-package: ## Update specific package (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Updating package: $(PKG)...$(NC)"
	@$(PM_UPDATE) $(PKG)
	@echo "$(GREEN)✓ Package updated: $(PKG)$(NC)"

.PHONY: outdated
outdated: ## Check for outdated dependencies
	@echo "$(CYAN)Checking for outdated dependencies...$(NC)"
	@npm outdated || true

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

.PHONY: dedupe
dedupe: ## Deduplicate dependencies
	@echo "$(YELLOW)Deduplicating dependencies...$(NC)"
	@npm dedupe
	@echo "$(GREEN)✓ Dependencies deduplicated$(NC)"

# === Build Commands ===
.PHONY: build
build: ## Build the project
	@echo "$(YELLOW)Building project...$(NC)"
	@$(PM_RUN) build
	@echo "$(GREEN)✓ Build completed: $(BUILD_DIR)$(NC)"

.PHONY: build-prod
build-prod: ## Build for production
	@echo "$(YELLOW)Building for production...$(NC)"
	@NODE_ENV=production $(PM_RUN) build
	@echo "$(GREEN)✓ Production build completed$(NC)"

.PHONY: build-dev
build-dev: ## Build for development
	@echo "$(YELLOW)Building for development...$(NC)"
	@NODE_ENV=development $(PM_RUN) build
	@echo "$(GREEN)✓ Development build completed$(NC)"

.PHONY: watch
watch: ## Build in watch mode
	@echo "$(YELLOW)Starting build watch mode...$(NC)"
	@$(PM_RUN) build -- --watch || $(PM_RUN) watch

.PHONY: rebuild
rebuild: clean-dist build ## Clean and rebuild
	@echo "$(GREEN)✓ Rebuild completed$(NC)"

# === Run Commands ===
.PHONY: start
start: ## Start the application (production mode)
	@echo "$(CYAN)Starting application...$(NC)"
	@$(PM_RUN) start

.PHONY: dev
dev: ## Start development server
	@echo "$(CYAN)Starting development server on port $(PORT)...$(NC)"
	@$(PM_RUN) dev || $(PM_RUN) start:dev

.PHONY: serve
serve: ## Serve built files
	@echo "$(CYAN)Serving application...$(NC)"
	@$(PM_RUN) serve || npx http-server $(BUILD_DIR) -p $(PORT)

.PHONY: run-script
run-script: ## Run custom npm script (use SCRIPT=script-name)
	@if [ -z "$(SCRIPT)" ]; then \
		echo "$(RED)Error: Please specify script with SCRIPT=script-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running script: $(SCRIPT)...$(NC)"
	@$(PM_RUN) $(SCRIPT)

# === Testing ===
.PHONY: test
test: ## Run all tests
	@echo "$(YELLOW)Running tests...$(NC)"
	@$(PM_RUN) test
	@echo "$(GREEN)✓ Tests completed$(NC)"

.PHONY: test-watch
test-watch: ## Run tests in watch mode
	@echo "$(YELLOW)Starting test watch mode...$(NC)"
	@$(PM_RUN) test -- --watch || $(PM_RUN) test:watch

.PHONY: test-cov
test-cov: ## Run tests with coverage
	@echo "$(YELLOW)Running tests with coverage...$(NC)"
	@$(PM_RUN) test -- --coverage || $(PM_RUN) test:cov
	@echo "$(GREEN)✓ Coverage report generated in $(COVERAGE_DIR)$(NC)"

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	@echo "$(YELLOW)Running tests (verbose)...$(NC)"
	@$(PM_RUN) test -- --verbose

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(YELLOW)Running unit tests...$(NC)"
	@$(PM_RUN) test:unit || $(PM_RUN) test -- --testPathPattern=unit

.PHONY: test-integration
test-integration: ## Run integration tests only
	@echo "$(YELLOW)Running integration tests...$(NC)"
	@$(PM_RUN) test:integration || $(PM_RUN) test -- --testPathPattern=integration

.PHONY: test-e2e
test-e2e: ## Run end-to-end tests
	@echo "$(YELLOW)Running E2E tests...$(NC)"
	@$(PM_RUN) test:e2e || $(PM_EXEC) cypress run

.PHONY: test-file
test-file: ## Run specific test file (use FILE=path/to/test.js)
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: Please specify file with FILE=path/to/test.js$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running test file: $(FILE)...$(NC)"
	@$(PM_RUN) test -- $(FILE)

# === Code Quality ===
.PHONY: lint
lint: ## Run code linting
	@echo "$(YELLOW)Running linter...$(NC)"
	@$(PM_RUN) lint || $(PM_EXEC) eslint $(SRC_DIR)
	@echo "$(GREEN)✓ Linting completed$(NC)"

.PHONY: lint-fix
lint-fix: ## Fix linting issues automatically
	@echo "$(YELLOW)Fixing linting issues...$(NC)"
	@$(PM_RUN) lint -- --fix || $(PM_EXEC) eslint $(SRC_DIR) --fix
	@echo "$(GREEN)✓ Linting issues fixed$(NC)"

.PHONY: format
format: ## Format code with Prettier
	@echo "$(YELLOW)Formatting code...$(NC)"
	@$(PM_RUN) format || $(PM_EXEC) prettier --write "**/*.{js,jsx,ts,tsx,json,md,yml,yaml}"
	@echo "$(GREEN)✓ Code formatted$(NC)"

.PHONY: format-check
format-check: ## Check code formatting without changes
	@echo "$(YELLOW)Checking code format...$(NC)"
	@$(PM_RUN) format:check || $(PM_EXEC) prettier --check "**/*.{js,jsx,ts,tsx,json,md,yml,yaml}"
	@echo "$(GREEN)✓ Format check completed$(NC)"

.PHONY: typecheck
typecheck: ## Run TypeScript type checking
	@echo "$(YELLOW)Running type checker...$(NC)"
	@$(PM_RUN) typecheck || $(PM_EXEC) tsc --noEmit
	@echo "$(GREEN)✓ Type checking completed$(NC)"

.PHONY: security
security: ## Run security checks
	@echo "$(YELLOW)Running security scan...$(NC)"
	@npm audit --audit-level=moderate
	@echo "$(GREEN)✓ Security scan completed$(NC)"

.PHONY: quality
quality: lint format-check typecheck security ## Run all code quality checks
	@echo "$(GREEN)✓ All quality checks completed$(NC)"

# === Development ===
.PHONY: repl
repl: ## Open Node.js REPL
	@echo "$(CYAN)Starting Node.js REPL...$(NC)"
	@node

.PHONY: debug
debug: ## Start application in debug mode
	@echo "$(CYAN)Starting application in debug mode...$(NC)"
	@node --inspect-brk $(SRC_DIR)/index.js || $(PM_RUN) debug

.PHONY: logs
logs: ## Show application logs (if applicable)
	@echo "$(CYAN)Application logs:$(NC)"
	@tail -f logs/*.log 2>/dev/null || echo "No log files found in logs/"

.PHONY: shell
shell: ## Open interactive shell with project context
	@echo "$(CYAN)Opening shell...$(NC)"
	@bash

# === Cleanup ===
.PHONY: clean
clean: clean-deps clean-dist clean-cache ## Full cleanup (deps, dist, cache)
	@echo "$(GREEN)✓ Full cleanup completed$(NC)"

.PHONY: clean-deps
clean-deps: ## Remove node_modules
	@echo "$(YELLOW)Removing node_modules...$(NC)"
	@rm -rf node_modules
	@echo "$(GREEN)✓ node_modules removed$(NC)"

.PHONY: clean-dist
clean-dist: ## Remove build artifacts
	@echo "$(YELLOW)Removing build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf build
	@rm -rf out
	@rm -f *.tsbuildinfo
	@echo "$(GREEN)✓ Build artifacts removed$(NC)"

.PHONY: clean-cache
clean-cache: ## Clear package manager cache
	@echo "$(YELLOW)Clearing cache...$(NC)"
	@if [ "$(PACKAGE_MANAGER)" = "pnpm" ]; then \
		pnpm store prune; \
	elif [ "$(PACKAGE_MANAGER)" = "yarn" ]; then \
		yarn cache clean; \
	else \
		npm cache clean --force; \
	fi
	@echo "$(GREEN)✓ Cache cleared$(NC)"

.PHONY: clean-coverage
clean-coverage: ## Remove coverage reports
	@echo "$(YELLOW)Removing coverage reports...$(NC)"
	@rm -rf $(COVERAGE_DIR)
	@rm -rf .nyc_output
	@echo "$(GREEN)✓ Coverage reports removed$(NC)"

.PHONY: clean-logs
clean-logs: ## Remove log files
	@echo "$(YELLOW)Removing log files...$(NC)"
	@rm -rf logs
	@rm -f *.log
	@echo "$(GREEN)✓ Log files removed$(NC)"

.PHONY: clean-all
clean-all: clean clean-coverage clean-logs ## Aggressive cleanup (everything)
	@echo "$(YELLOW)Removing all temporary files...$(NC)"
	@find . -name ".DS_Store" -delete 2>/dev/null || true
	@find . -name "*.swp" -delete 2>/dev/null || true
	@find . -name "*.swo" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ All cleanup completed$(NC)"

# === Utilities ===
.PHONY: check-node
check-node: ## Verify Node.js and npm installation
	@echo "$(CYAN)Checking Node.js installation...$(NC)"
	@command -v node >/dev/null 2>&1 || { echo "$(RED)Node.js is not installed$(NC)"; exit 1; }
	@echo "Node version: $$(node --version)"
	@echo "npm version: $$(npm --version)"
	@echo "$(GREEN)✓ Node.js and npm are installed$(NC)"

.PHONY: info
info: ## Show project information
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Project Information:$(NC)"
	@echo "  Project Name:     $(PROJECT_NAME)"
	@echo "  Version:          $(VERSION)"
	@echo "  Node Version:     $(NODE_VERSION)"
	@echo "  Package Manager:  $(PACKAGE_MANAGER)"
	@echo "  Environment:      $(ENV)"
	@echo "  Port:             $(PORT)"
	@echo "  Build Dir:        $(BUILD_DIR)"
	@echo "  Source Dir:       $(SRC_DIR)"
	@echo "  Git Branch:       $(GIT_BRANCH)"
	@echo "  Git Commit:       $(GIT_COMMIT)"
	@echo "  Build Date:       $(BUILD_DATE)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: validate
validate: ## Validate package.json and lockfile
	@echo "$(YELLOW)Validating project files...$(NC)"
	@if [ ! -f package.json ]; then \
		echo "$(RED)Error: package.json not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ package.json exists$(NC)"
	@if [ ! -f $(LOCKFILE) ]; then \
		echo "$(YELLOW)Warning: $(LOCKFILE) not found$(NC)"; \
	else \
		echo "$(GREEN)✓ $(LOCKFILE) exists$(NC)"; \
	fi
	@node -e "require('./package.json')" && echo "$(GREEN)✓ package.json is valid JSON$(NC)" || { echo "$(RED)Error: package.json is invalid$(NC)"; exit 1; }

.PHONY: doctor
doctor: check-node validate ## Run all health checks
	@echo "$(YELLOW)Running health checks...$(NC)"
	@npm doctor || true
	@echo "$(GREEN)✓ Health checks completed$(NC)"

.PHONY: list-scripts
list-scripts: ## List all available npm scripts
	@echo "$(CYAN)Available npm scripts:$(NC)"
	@node -e "const pkg=require('./package.json'); Object.keys(pkg.scripts||{}).forEach(s=>console.log('  '+s+': '+pkg.scripts[s]))"

.PHONY: version-major
version-major: ## Bump major version
	@echo "$(YELLOW)Bumping major version...$(NC)"
	@npm version major
	@echo "$(GREEN)✓ Version bumped to $$(node -p "require('./package.json').version")$(NC)"

.PHONY: version-minor
version-minor: ## Bump minor version
	@echo "$(YELLOW)Bumping minor version...$(NC)"
	@npm version minor
	@echo "$(GREEN)✓ Version bumped to $$(node -p "require('./package.json').version")$(NC)"

.PHONY: version-patch
version-patch: ## Bump patch version
	@echo "$(YELLOW)Bumping patch version...$(NC)"
	@npm version patch
	@echo "$(GREEN)✓ Version bumped to $$(node -p "require('./package.json').version")$(NC)"

.PHONY: publish
publish: ## Publish package to npm registry
	@echo "$(YELLOW)Publishing package...$(NC)"
	@npm publish
	@echo "$(GREEN)✓ Package published$(NC)"

.PHONY: publish-dry
publish-dry: ## Dry run of package publish
	@echo "$(YELLOW)Running publish dry run...$(NC)"
	@npm publish --dry-run

.PHONY: link
link: ## Link package globally for local development
	@echo "$(YELLOW)Linking package globally...$(NC)"
	@npm link
	@echo "$(GREEN)✓ Package linked$(NC)"

.PHONY: unlink
unlink: ## Unlink package from global
	@echo "$(YELLOW)Unlinking package...$(NC)"
	@npm unlink -g $(PROJECT_NAME)
	@echo "$(GREEN)✓ Package unlinked$(NC)"

.PHONY: init
init: ## Initialize a new npm project
	@echo "$(YELLOW)Initializing npm project...$(NC)"
	@npm init -y
	@echo "$(GREEN)✓ Project initialized$(NC)"

.PHONY: tree
tree: ## Show dependency tree
	@echo "$(CYAN)Dependency tree:$(NC)"
	@npm ls --depth=2 || true

.PHONY: why
why: ## Explain why a package is installed (use PKG=package-name)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Dependency explanation for $(PKG):$(NC)"
	@npm ls $(PKG) || npm explain $(PKG)
