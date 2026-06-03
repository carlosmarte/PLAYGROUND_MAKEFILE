# Semantic-Release Makefile — force & troubleshoot releases
# Usage: make -f semantic-release.Makefile [target]
# Default: help
#
# semantic-release has no --force flag by design: a release is a pure function
# of your commit history. To "force" one you push a commit whose message a
# release decision can be derived from. The empty-commit trick below does that
# without touching code, plus targets that encode the common "why won't it
# release?" troubleshooting checklist.

# === Configuration Variables ===
RELEASE_BRANCH ?= main
REMOTE ?= origin
SR ?= npx semantic-release
MSG ?=
TYPE ?=
SCOPE ?=

# Build metadata
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-branch")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "no-git")
LATEST_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "none")

# Conventional-commit types that trigger a version bump (Angular preset)
RELEASE_PREFIX := ^(feat|fix|perf|revert)(\(.+\))?!?:

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
	@echo "$(WHITE)         Semantic-Release Makefile — force & troubleshoot$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f semantic-release.Makefile $(GREEN)[target]$(NC)"
	@echo ""
	@echo "$(YELLOW)Forced Release Triggers (empty-commit trick):$(NC)"
	@grep -E '^(patch|minor|major|force)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Conventional Commit:$(NC)"
	@grep -E '^commit[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Release Execution (normally CI-only):$(NC)"
	@grep -E '^release[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Diagnostics:$(NC)"
	@grep -E '^(last-commit|latest-tag|tags|tag-sync|troubleshoot)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Branch & Remote:$(NC)"
	@grep -E '^(check-branch|branches|push)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@grep -E '^(info|validate|check-tools|doctor)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f semantic-release.Makefile patch"
	@echo "  $$ make -f semantic-release.Makefile minor MSG=\"add retry logic\""
	@echo "  $$ make -f semantic-release.Makefile troubleshoot"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Internal helper (not shown in help) ===
.PHONY: branch-guard
branch-guard:
	@if [ "$(GIT_BRANCH)" != "$(RELEASE_BRANCH)" ]; then \
		echo "$(YELLOW)⚠ Warning: on '$(GIT_BRANCH)', not release branch '$(RELEASE_BRANCH)'.$(NC)"; \
		echo "$(YELLOW)  The commit will be created, but semantic-release will ignore it unless this branch is configured.$(NC)"; \
	fi

# === Forced Release Triggers ===
# semantic-release reads commit messages only, so an empty commit with a
# trigger prefix is enough to force a release on the next CI run.
.PHONY: patch
patch: branch-guard ## Force a PATCH release via an empty `fix:` commit (override text with MSG="...")
	@echo "$(YELLOW)Creating empty 'fix:' commit to force a PATCH release...$(NC)"
	@git commit --allow-empty -m "fix: $(or $(MSG),force patch release)"
	@echo "$(GREEN)✓ Empty commit created on $(GIT_BRANCH). Run 'make -f semantic-release.Makefile push' to trigger CI.$(NC)"

.PHONY: minor
minor: branch-guard ## Force a MINOR release via an empty `feat:` commit (override text with MSG="...")
	@echo "$(YELLOW)Creating empty 'feat:' commit to force a MINOR release...$(NC)"
	@git commit --allow-empty -m "feat: $(or $(MSG),force minor release)"
	@echo "$(GREEN)✓ Empty commit created on $(GIT_BRANCH). Run 'make -f semantic-release.Makefile push' to trigger CI.$(NC)"

.PHONY: major
major: branch-guard ## Force a MAJOR release via an empty `feat!:` + BREAKING CHANGE commit (override text with MSG="...")
	@echo "$(YELLOW)Creating empty 'feat!:' commit with BREAKING CHANGE to force a MAJOR release...$(NC)"
	@git commit --allow-empty \
		-m "feat!: $(or $(MSG),force major release)" \
		-m "BREAKING CHANGE: $(or $(MSG),force major release)"
	@echo "$(GREEN)✓ Empty commit created on $(GIT_BRANCH). Run 'make -f semantic-release.Makefile push' to trigger CI.$(NC)"

.PHONY: force
force: branch-guard ## Force a release with a custom type (use TYPE=fix|feat MSG="...")
	@if [ -z "$(MSG)" ]; then \
		echo "$(RED)Error: Please specify the message with MSG=\"...\"$(NC)"; \
		exit 1; \
	fi
	@type="$(or $(TYPE),fix)"; \
	echo "$(YELLOW)Creating empty '$$type:' commit to force a release...$(NC)"; \
	git commit --allow-empty -m "$$type: $(MSG)"
	@echo "$(GREEN)✓ Empty commit created on $(GIT_BRANCH). Run 'make -f semantic-release.Makefile push' to trigger CI.$(NC)"

# === Conventional Commit ===
.PHONY: commit
commit: ## Create a conventional commit (use TYPE=feat MSG="..." [SCOPE=api])
	@if [ -z "$(MSG)" ]; then \
		echo "$(RED)Error: Please specify the message with MSG=\"...\"$(NC)"; \
		exit 1; \
	fi
	@type="$(or $(TYPE),feat)"; \
	if [ -n "$(SCOPE)" ]; then header="$$type($(SCOPE)): $(MSG)"; else header="$$type: $(MSG)"; fi; \
	echo "$(YELLOW)Committing: $$header$(NC)"; \
	git commit -m "$$header"
	@echo "$(GREEN)✓ Commit created$(NC)"

# === Release Execution ===
.PHONY: release-dry
release-dry: ## Preview the next release without publishing (semantic-release --dry-run)
	@echo "$(YELLOW)Running semantic-release in dry-run mode...$(NC)"
	@$(SR) --dry-run

.PHONY: release
release: ## Run semantic-release for real (normally CI-only — runs the publish step)
	@echo "$(RED)WARNING: this runs the REAL release/publish. CI normally owns this step.$(NC)"
	@$(SR)

# === Diagnostics ===
.PHONY: last-commit
last-commit: ## Show the last commit and whether it would trigger a release
	@msg=$$(git log -1 --pretty=%s 2>/dev/null); \
	echo "$(CYAN)Last commit:$(NC) $$msg"; \
	if echo "$$msg" | grep -qE '$(RELEASE_PREFIX)' || git log -1 --pretty=%B | grep -q 'BREAKING CHANGE'; then \
		echo "$(GREEN)✓ This commit can trigger a release (feat:/fix:/perf: or BREAKING CHANGE)$(NC)"; \
	else \
		echo "$(YELLOW)⚠ This message will NOT trigger a release — it lacks a feat:/fix:/perf: prefix or BREAKING CHANGE$(NC)"; \
	fi

.PHONY: latest-tag
latest-tag: ## Show the latest tag locally, on the remote, and the published npm version
	@echo "$(CYAN)Latest local tag:$(NC)  $(LATEST_TAG)"
	@echo "$(CYAN)Latest remote tag:$(NC) $$(git ls-remote --tags $(REMOTE) 2>/dev/null | awk -F/ '{print $$3}' | grep -v '\^{}' | sort -V | tail -1 || echo unknown)"
	@if [ -f package.json ]; then \
		name=$$(node -p "require('./package.json').name" 2>/dev/null); \
		echo "$(CYAN)Published on npm:$(NC)  $$(npm view $$name version 2>/dev/null || echo 'not published / unknown')"; \
		echo "$(YELLOW)Tip: if the latest git tag is AHEAD of the npm version, an earlier publish failed —$(NC)"; \
		echo "$(YELLOW)     semantic-release won't retry that tag. Push a new empty commit, or 'npm publish' manually to sync.$(NC)"; \
	fi

.PHONY: tags
tags: ## List recent git tags (most recent first)
	@echo "$(CYAN)Recent tags:$(NC)"
	@git tag --sort=-creatordate 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (no tags)"

.PHONY: tag-sync
tag-sync: ## List tags that exist locally but not on the remote (failed pushes)
	@echo "$(CYAN)Comparing local tags with $(REMOTE)...$(NC)"
	@git fetch --tags --quiet $(REMOTE) 2>/dev/null || true
	@local_f=/tmp/sr_local_tags.$$$$; remote_f=/tmp/sr_remote_tags.$$$$; \
	git tag | sort > $$local_f; \
	git ls-remote --tags $(REMOTE) 2>/dev/null | awk -F/ '{print $$3}' | grep -v '\^{}' | sort > $$remote_f; \
	out=$$(comm -23 $$local_f $$remote_f); \
	if [ -n "$$out" ]; then \
		echo "$(YELLOW)Local-only tags (never pushed):$(NC)"; echo "$$out" | sed 's/^/  /'; \
	else \
		echo "$(GREEN)✓ All local tags exist on $(REMOTE)$(NC)"; \
	fi; \
	rm -f $$local_f $$remote_f

.PHONY: troubleshoot
troubleshoot: ## Run the 3-point "why won't it release?" checklist
	@echo "$(CYAN)══════════ semantic-release troubleshooting ══════════$(NC)"
	@echo "$(WHITE)1. Branch check$(NC)"
	@if [ "$(GIT_BRANCH)" = "$(RELEASE_BRANCH)" ]; then \
		echo "$(GREEN)  ✓ On release branch '$(RELEASE_BRANCH)'$(NC)"; \
	else \
		echo "$(RED)  ✗ On '$(GIT_BRANCH)', not release branch '$(RELEASE_BRANCH)' — commits here are ignored.$(NC)"; \
	fi
	@echo "$(WHITE)2. Commit format check$(NC)"
	@$(MAKE) -f $(MAKEFILE_LIST) --no-print-directory last-commit
	@echo "$(WHITE)3. Tag sync check (an npm publish may have failed after the git tag)$(NC)"
	@$(MAKE) -f $(MAKEFILE_LIST) --no-print-directory latest-tag

# === Branch & Remote ===
.PHONY: check-branch
check-branch: ## Assert the current branch is the configured release branch
	@if [ "$(GIT_BRANCH)" != "$(RELEASE_BRANCH)" ]; then \
		echo "$(RED)Error: on '$(GIT_BRANCH)', expected release branch '$(RELEASE_BRANCH)' (override with RELEASE_BRANCH=...)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ On release branch '$(RELEASE_BRANCH)'$(NC)"

.PHONY: branches
branches: ## Show the configured release branches (.releaserc* / release key in package.json)
	@if ls .releaserc* release.config.js >/dev/null 2>&1; then \
		echo "$(CYAN)Release config files:$(NC)"; ls .releaserc* release.config.js 2>/dev/null | sed 's/^/  /'; \
	elif [ -f package.json ] && grep -q '"release"' package.json; then \
		echo "$(CYAN)Release config in package.json:$(NC)"; \
		node -e "console.log(JSON.stringify(require('./package.json').release && require('./package.json').release.branches || 'default', null, 2))" 2>/dev/null | sed 's/^/  /'; \
	else \
		echo "$(YELLOW)No release config found; semantic-release defaults to:$(NC)"; \
		echo "  master, main, next, next-major, +({1,n}).x, beta, alpha"; \
	fi

.PHONY: push
push: ## Push the current branch and tags to the remote (triggers the CI release)
	@echo "$(YELLOW)Pushing $(GIT_BRANCH) and tags to $(REMOTE)...$(NC)"
	@git push $(REMOTE) $(GIT_BRANCH)
	@git push $(REMOTE) --tags
	@echo "$(GREEN)✓ Pushed. CI should now run semantic-release.$(NC)"

# === Utilities ===
.PHONY: info
info: ## Show configuration and current release state
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Semantic-Release Configuration:$(NC)"
	@echo "  Release Branch:   $(RELEASE_BRANCH)"
	@echo "  Current Branch:   $(GIT_BRANCH)"
	@echo "  Remote:           $(REMOTE)"
	@echo "  Latest Local Tag: $(LATEST_TAG)"
	@echo "  Git Commit:       $(GIT_COMMIT)"
	@echo "  SR Command:       $(SR)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: validate
validate: ## Validate release config, branch, and last commit
	@echo "$(YELLOW)Validating semantic-release setup...$(NC)"
	@if ls .releaserc* release.config.js >/dev/null 2>&1 || { [ -f package.json ] && grep -q '"release"' package.json; }; then \
		echo "$(GREEN)✓ Release configuration found$(NC)"; \
	else \
		echo "$(YELLOW)⚠ No release config found (semantic-release will use its defaults)$(NC)"; \
	fi
	@if [ "$(GIT_BRANCH)" = "$(RELEASE_BRANCH)" ]; then \
		echo "$(GREEN)✓ On release branch '$(RELEASE_BRANCH)'$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not on release branch '$(RELEASE_BRANCH)' (current: $(GIT_BRANCH))$(NC)"; \
	fi
	@$(MAKE) -f $(MAKEFILE_LIST) --no-print-directory last-commit

.PHONY: check-tools
check-tools: ## Verify git and semantic-release are available
	@command -v git >/dev/null 2>&1 || { echo "$(RED)git is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ git $$(git --version | awk '{print $$3}')$(NC)"
	@command -v npx >/dev/null 2>&1 || { echo "$(RED)npx is not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ npx available$(NC)"
	@npx --no-install semantic-release --version >/dev/null 2>&1 \
		&& echo "$(GREEN)✓ semantic-release resolvable$(NC)" \
		|| echo "$(YELLOW)⚠ semantic-release not installed locally (npx will fetch it on demand)$(NC)"

.PHONY: doctor
doctor: check-tools validate ## Run all health checks
	@echo "$(GREEN)✓ Health checks completed$(NC)"
