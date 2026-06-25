# pip-debug Makefile — Inspect packages on a custom Python registry
# Usage: make -f pip-debug.Makefile [target] PKG=<name> [VERSION=<x.y.z>]
# Default: help
#
# Focus: find / search / version-lookup / version-listing against a custom
# (PyPI-compatible) registry — without polluting the local environment.

# === Configuration Variables ===
PROJECT_NAME    ?= pip-debug
PYTHON          ?= python3
PIP             ?= $(PYTHON) -m pip

# Custom registry endpoints (override for Artifactory / Nexus / devpi / GCP AR)
#   INDEX_URL  -> PEP 503 "simple" index root      (used by pip itself)
#   JSON_URL   -> Warehouse-style JSON metadata API (used for rich queries)
INDEX_URL       ?= https://pypi.org/simple
JSON_URL        ?= https://pypi.org/pypi
EXTRA_INDEX_URL ?=
TRUSTED_HOST    ?=

# Per-invocation arguments
PKG             ?=
VERSION         ?=
LIMIT           ?= 50

# Where transient downloads land (kept out of the project tree)
DOWNLOAD_DIR    ?= .pip-debug-downloads

# Compose pip index arguments from the configuration above
PIP_INDEX_ARGS := --index-url $(INDEX_URL)
ifneq ($(strip $(EXTRA_INDEX_URL)),)
PIP_INDEX_ARGS += --extra-index-url $(EXTRA_INDEX_URL)
endif
ifneq ($(strip $(TRUSTED_HOST)),)
PIP_INDEX_ARGS += --trusted-host $(TRUSTED_HOST)
endif

# HTTP client for JSON-API queries (curl preferred, wget fallback handled inline)
CURL            := curl -fsSL

# Build metadata
BUILD_DATE      := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
PIP_VERSION     := $(shell $(PIP) --version 2>/dev/null | awk '{print $$2}' || echo "no-pip")
PY_VERSION      := $(shell $(PYTHON) --version 2>&1 | awk '{print $$2}' || echo "no-python")

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
PURPLE := \033[0;35m
CYAN   := \033[0;36m
WHITE  := \033[1;37m
NC     := \033[0m # No Color

# === Default Target ===
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)         pip-debug — Inspect a Custom Python Registry$(NC)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make -f pip-debug.Makefile $(GREEN)[target]$(NC) PKG=<name> [VERSION=<x.y.z>]"
	@echo ""
	@echo "$(YELLOW)Registry:$(NC)"
	@grep -E '^(config|ping|show-index|registries)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Find & Search:$(NC)"
	@grep -E '^(find|search|exists|list-all)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Version Lookup & Listing:$(NC)"
	@grep -E '^(versions|latest|version)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Inspect:$(NC)"
	@grep -E '^(show:|metadata|requires)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Download (no install):$(NC)"
	@grep -E '^(download)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Local Environment:$(NC)"
	@grep -E '^(installed|outdated|whoami|doctor)[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cleanup:$(NC)"
	@grep -E '^clean[^:]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-22s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Examples:$(NC)"
	@echo "  $$ make -f pip-debug.Makefile config"
	@echo "  $$ make -f pip-debug.Makefile find PKG=requests"
	@echo "  $$ make -f pip-debug.Makefile versions PKG=requests"
	@echo "  $$ make -f pip-debug.Makefile latest PKG=requests"
	@echo "  $$ make -f pip-debug.Makefile version-exists PKG=requests VERSION=2.31.0"
	@echo "  $$ make -f pip-debug.Makefile show PKG=requests INDEX_URL=https://my.registry/simple"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

# === Internal Guards ===
# Reusable guard: fail early with a friendly message if PKG / VERSION missing.
.PHONY: _require-pkg
_require-pkg:
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: Please specify a package with PKG=<name>$(NC)"; \
		echo "$(YELLOW)Example: make -f pip-debug.Makefile $(MAKECMDGOALS) PKG=requests$(NC)"; \
		exit 1; \
	fi

.PHONY: _require-version
_require-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: Please specify a version with VERSION=<x.y.z>$(NC)"; \
		echo "$(YELLOW)Example: make -f pip-debug.Makefile $(MAKECMDGOALS) PKG=requests VERSION=2.31.0$(NC)"; \
		exit 1; \
	fi

.PHONY: _require-curl
_require-curl:
	@command -v curl >/dev/null 2>&1 || { \
		echo "$(RED)Error: 'curl' is required for JSON-API queries but was not found$(NC)"; \
		exit 1; \
	}

# === Registry ===
.PHONY: config
config: ## Show the active registry configuration
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(WHITE)Registry Configuration:$(NC)"
	@echo "  Simple Index (pip):  $(INDEX_URL)"
	@echo "  JSON Metadata API:   $(JSON_URL)"
	@echo "  Extra Index:         $(if $(EXTRA_INDEX_URL),$(EXTRA_INDEX_URL),$(YELLOW)(none)$(NC))"
	@echo "  Trusted Host:        $(if $(TRUSTED_HOST),$(TRUSTED_HOST),$(YELLOW)(none)$(NC))"
	@echo "  Composed pip args:   $(PIP_INDEX_ARGS)"
	@echo "  Python:              $(PY_VERSION) ($(PYTHON))"
	@echo "  pip:                 $(PIP_VERSION)"
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: registries
registries: ## Show pip's own configured indexes (pip config)
	@echo "$(CYAN)pip configuration (index settings):$(NC)"
	@$(PIP) config list 2>/dev/null | grep -iE 'index|url|trusted' || echo "$(YELLOW)No index settings in pip config$(NC)"

.PHONY: ping
ping: _require-curl ## Check the registry simple index is reachable
	@echo "$(YELLOW)Pinging registry: $(INDEX_URL)/ ...$(NC)"
	@if $(CURL) -o /dev/null -w "  HTTP %{http_code}  in %{time_total}s\n" "$(INDEX_URL)/" 2>/dev/null; then \
		echo "$(GREEN)✓ Registry is reachable$(NC)"; \
	else \
		echo "$(RED)✗ Registry did not respond (check INDEX_URL / network / auth)$(NC)"; \
		exit 1; \
	fi

.PHONY: show-index
show-index: _require-pkg _require-curl ## Show the raw simple-index page for a package
	@echo "$(CYAN)Simple index page for $(PKG):$(NC)"
	@echo "  $(INDEX_URL)/$(PKG)/"
	@echo ""
	@$(CURL) "$(INDEX_URL)/$(PKG)/" 2>/dev/null \
		| grep -oE 'href="[^"]+"' \
		| sed -E 's/href="//; s/"$$//' \
		| head -n $(LIMIT) \
		|| echo "$(RED)✗ Could not fetch index page for $(PKG)$(NC)"

# === Find & Search ===
.PHONY: find
find: _require-pkg ## Find a package on the registry (resolves latest candidate)
	@echo "$(YELLOW)Looking up '$(PKG)' on $(INDEX_URL)...$(NC)"
	@$(PIP) index versions $(PKG) $(PIP_INDEX_ARGS) 2>/dev/null \
		&& echo "$(GREEN)✓ Found '$(PKG)' on the registry$(NC)" \
		|| { echo "$(RED)✗ '$(PKG)' not found on $(INDEX_URL)$(NC)"; exit 1; }

.PHONY: exists
exists: _require-pkg _require-curl ## Test whether a package exists (exit 0/1, quiet)
	@if $(CURL) -o /dev/null "$(INDEX_URL)/$(PKG)/" 2>/dev/null; then \
		echo "$(GREEN)✓ '$(PKG)' exists on $(INDEX_URL)$(NC)"; \
	else \
		echo "$(RED)✗ '$(PKG)' does not exist on $(INDEX_URL)$(NC)"; \
		exit 1; \
	fi

.PHONY: search
search: _require-pkg _require-curl ## Search registry package names by substring (PKG=term)
	@echo "$(CYAN)Searching registry index for names containing '$(PKG)'...$(NC)"
	@echo "$(YELLOW)(scanning $(INDEX_URL)/ — first $(LIMIT) matches)$(NC)"
	@$(CURL) "$(INDEX_URL)/" 2>/dev/null \
		| grep -oE '>[^<]+</a>' \
		| sed -E 's/^>//; s/<\/a>$$//' \
		| grep -i -- "$(PKG)" \
		| sort -u \
		| head -n $(LIMIT) \
		|| echo "$(YELLOW)No matching names (registry may not expose a full index listing)$(NC)"

.PHONY: list-all
list-all: _require-curl ## List all package names on the registry (LIMIT applies)
	@echo "$(CYAN)Packages on $(INDEX_URL)/ (first $(LIMIT)):$(NC)"
	@$(CURL) "$(INDEX_URL)/" 2>/dev/null \
		| grep -oE '>[^<]+</a>' \
		| sed -E 's/^>//; s/<\/a>$$//' \
		| sort -u \
		| head -n $(LIMIT) \
		|| echo "$(RED)✗ Could not list packages (registry may restrict the root index)$(NC)"

# === Version Lookup & Listing ===
.PHONY: versions
versions: _require-pkg ## List all available versions of a package
	@echo "$(CYAN)Available versions of '$(PKG)' on $(INDEX_URL):$(NC)"
	@$(PIP) index versions $(PKG) $(PIP_INDEX_ARGS) 2>/dev/null \
		|| { echo "$(RED)✗ Could not list versions for '$(PKG)'$(NC)"; exit 1; }

.PHONY: versions-json
versions-json: _require-pkg _require-curl ## List versions via the JSON API (sorted, all releases)
	@echo "$(CYAN)Versions of '$(PKG)' (JSON API: $(JSON_URL)/$(PKG)/json):$(NC)"
	@$(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null \
		| $(PYTHON) -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(sorted(d.get('releases',{}).keys())))" \
		|| { echo "$(RED)✗ Could not fetch versions for '$(PKG)' from JSON API$(NC)"; exit 1; }

.PHONY: latest
latest: _require-pkg _require-curl ## Show the latest published version of a package
	@printf "$(WHITE)%s$(NC) latest on $(INDEX_URL): " "$(PKG)"
	@$(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null \
		| $(PYTHON) -c "import sys,json; print(json.load(sys.stdin)['info']['version'])" \
		|| { echo "$(RED)✗ Could not resolve latest version (try 'make versions PKG=$(PKG)')$(NC)"; exit 1; }

.PHONY: version-exists
version-exists: _require-pkg _require-version _require-curl ## Check if a specific version exists (PKG + VERSION)
	@echo "$(YELLOW)Checking $(PKG)==$(VERSION) on $(INDEX_URL)...$(NC)"
	@if $(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null \
		| $(PYTHON) -c "import sys,json; sys.exit(0 if '$(VERSION)' in json.load(sys.stdin).get('releases',{}) else 1)"; then \
		echo "$(GREEN)✓ $(PKG)==$(VERSION) is available$(NC)"; \
	else \
		echo "$(RED)✗ $(PKG)==$(VERSION) was NOT found on the registry$(NC)"; \
		exit 1; \
	fi

.PHONY: version-files
version-files: _require-pkg _require-version _require-curl ## List distribution files for a specific version
	@echo "$(CYAN)Distribution files for $(PKG)==$(VERSION):$(NC)"
	@$(CURL) "$(JSON_URL)/$(PKG)/$(VERSION)/json" 2>/dev/null \
		| $(PYTHON) -c "import sys,json; [print('  %-12s %s' % (u.get('packagetype',''), u.get('filename',''))) for u in json.load(sys.stdin).get('urls',[])]" \
		|| { echo "$(RED)✗ Could not fetch files for $(PKG)==$(VERSION)$(NC)"; exit 1; }

# === Inspect ===
.PHONY: show
show: _require-pkg _require-curl ## Show registry metadata summary for a package
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"
	@$(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null | $(PYTHON) -c "import sys,json; \
i=json.load(sys.stdin)['info']; \
print('$(WHITE)Name:$(NC)        '+str(i.get('name'))); \
print('$(WHITE)Version:$(NC)     '+str(i.get('version'))); \
print('$(WHITE)Summary:$(NC)     '+str(i.get('summary'))); \
print('$(WHITE)Author:$(NC)      '+str(i.get('author'))); \
print('$(WHITE)License:$(NC)     '+str(i.get('license'))); \
print('$(WHITE)Homepage:$(NC)    '+str(i.get('home_page') or (i.get('project_urls') or {}).get('Homepage'))); \
print('$(WHITE)Requires-Py:$(NC) '+str(i.get('requires_python')))" \
		|| { echo "$(RED)✗ Could not fetch metadata for '$(PKG)'$(NC)"; exit 1; }
	@echo "$(CYAN)════════════════════════════════════════════════════════════════════$(NC)"

.PHONY: metadata
metadata: _require-pkg _require-curl ## Dump the full raw JSON metadata for a package
	@$(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null \
		| $(PYTHON) -m json.tool \
		|| { echo "$(RED)✗ Could not fetch metadata for '$(PKG)'$(NC)"; exit 1; }

.PHONY: requires
requires: _require-pkg _require-curl ## Show declared dependencies (requires_dist) of latest
	@echo "$(CYAN)Dependencies declared by '$(PKG)' (latest):$(NC)"
	@$(CURL) "$(JSON_URL)/$(PKG)/json" 2>/dev/null \
		| $(PYTHON) -c "import sys,json; d=json.load(sys.stdin)['info'].get('requires_dist') or []; print('\n'.join('  '+r for r in d) if d else '  $(YELLOW)(no declared dependencies)$(NC)')" \
		|| { echo "$(RED)✗ Could not fetch dependencies for '$(PKG)'$(NC)"; exit 1; }

# === Download (no install) ===
.PHONY: download
download: _require-pkg ## Download a package (latest) without installing it
	@echo "$(YELLOW)Downloading '$(PKG)' into $(DOWNLOAD_DIR)/ (no deps, no install)...$(NC)"
	@mkdir -p $(DOWNLOAD_DIR)
	@$(PIP) download $(PKG) $(PIP_INDEX_ARGS) --no-deps --dest $(DOWNLOAD_DIR) \
		&& echo "$(GREEN)✓ Downloaded to $(DOWNLOAD_DIR)/$(NC)" \
		|| { echo "$(RED)✗ Download failed for '$(PKG)'$(NC)"; exit 1; }

.PHONY: download-version
download-version: _require-pkg _require-version ## Download a specific version (PKG + VERSION)
	@echo "$(YELLOW)Downloading '$(PKG)==$(VERSION)' into $(DOWNLOAD_DIR)/ (no deps)...$(NC)"
	@mkdir -p $(DOWNLOAD_DIR)
	@$(PIP) download $(PKG)==$(VERSION) $(PIP_INDEX_ARGS) --no-deps --dest $(DOWNLOAD_DIR) \
		&& echo "$(GREEN)✓ Downloaded $(PKG)==$(VERSION) to $(DOWNLOAD_DIR)/$(NC)" \
		|| { echo "$(RED)✗ Download failed for '$(PKG)==$(VERSION)'$(NC)"; exit 1; }

# === Local Environment ===
.PHONY: installed
installed: _require-pkg ## Show the locally installed version of a package (pip show)
	@echo "$(CYAN)Locally installed details for '$(PKG)':$(NC)"
	@$(PIP) show $(PKG) 2>/dev/null \
		|| echo "$(YELLOW)'$(PKG)' is not installed in this environment$(NC)"

.PHONY: outdated
outdated: ## List installed packages with newer versions on the registry
	@echo "$(CYAN)Outdated packages (vs $(INDEX_URL)):$(NC)"
	@$(PIP) list --outdated $(PIP_INDEX_ARGS) 2>/dev/null || true

.PHONY: whoami
whoami: ## Show which environment/interpreter pip is operating on
	@echo "$(CYAN)pip environment:$(NC)"
	@echo "  Python:  $(PY_VERSION)"
	@echo "  pip:     $(PIP_VERSION)"
	@echo "  Exe:     $$($(PYTHON) -c 'import sys; print(sys.executable)')"
	@echo "  Site:    $$($(PYTHON) -c 'import site; print(site.getsitepackages()[0])' 2>/dev/null || echo 'n/a')"

.PHONY: doctor
doctor: config ping ## Run a quick connectivity + tooling health check
	@command -v curl >/dev/null 2>&1 && echo "$(GREEN)✓ curl available$(NC)" || echo "$(RED)✗ curl missing (JSON-API targets unavailable)$(NC)"
	@$(PIP) --version >/dev/null 2>&1 && echo "$(GREEN)✓ pip available$(NC)" || echo "$(RED)✗ pip missing$(NC)"
	@echo "$(GREEN)✓ Health check complete$(NC)"

# === Cleanup ===
.PHONY: clean
clean: ## Remove transient downloads
	@echo "$(YELLOW)Removing $(DOWNLOAD_DIR)/ ...$(NC)"
	@rm -rf $(DOWNLOAD_DIR)
	@echo "$(GREEN)✓ Cleaned$(NC)"

.PHONY: clean-cache
clean-cache: ## Purge pip's HTTP/wheel cache
	@echo "$(YELLOW)Purging pip cache...$(NC)"
	@$(PIP) cache purge 2>/dev/null || echo "$(YELLOW)(pip cache not available)$(NC)"
	@echo "$(GREEN)✓ pip cache purged$(NC)"
