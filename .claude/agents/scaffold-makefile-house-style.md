---
name: scaffold-makefile-house-style
description: Scaffold a new Makefile, or audit an existing one, against the examples-makefiles house style — self-documenting categorized `help`, ANSI color palette, `?=`-overridable config vars, `# === Section ===` dividers, `.PHONY` + `## doc` on every target, required-arg guards, and YELLOW/GREEN✓/RED echo conventions. Use when authoring a `*.Makefile` for a project type (npm, npm-workspace, docker, docker-py, or a new one) or checking that one matches the convention.
tools: Read, Glob, Grep, Bash
model: sonnet
---

# Scaffold / Audit Makefile House Style

## Pattern Summary

This repo (`examples-makefiles`) ships a family of project-type Makefiles (`npm.Makefile`, `npm-workspace.Makefile`, `docker.Makefile`, `docker-py.Makefile`) that all follow one strict, opinionated convention set. Hand-written Makefiles drift from it constantly — a target without a `## ` doc comment vanishes from `help`, a missing `.PHONY` breaks when a same-named file exists, a raw `echo` without the color/✓ convention reads as inconsistent, and an unguarded `$(PKG)`-style argument fails with a cryptic error instead of a clear message. This skill captures the house style so every new or edited Makefile matches the four exemplars, and so the exemplars themselves stay self-consistent.

## Root Cause

A Makefile is just a flat list of targets — nothing structurally forces a target to be documented, declared `.PHONY`, or to report progress consistently. The convention lives only in the author's memory of the other files. The moment someone adds a target without copying the surrounding idiom, it silently falls out of the `help` menu (the grep filter only matches lines with `## `), or shadows a real file, or prints bare output. The defect is invisible until a user runs `make help` and can't find the target, or runs it and gets no feedback. The fix is to treat the convention as a checkable spec rather than tribal knowledge.

## The House Style (canonical spec)

Grounded in the four sibling `*.Makefile` files. A compliant Makefile has:

1. **Header block** — leading comment with title, `# Usage: make -f <name>.Makefile [target]`, and `# Default: help`.
2. **`# === Section ===` dividers** — config, then grouped target sections (Build, Test, Cleanup, Utilities, …).
3. **Config variables** — user-tunable ones use `?=` (overridable from CLI/env: `PROJECT_NAME ?= my-app`); computed ones use `:=` (`IMAGE_NAME := $(APP_NAME)`).
4. **Build metadata** via `:=` + `$(shell …)` with a fallback: `GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "no-git")`, `BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")`.
5. **ANSI color palette** — `RED GREEN YELLOW BLUE PURPLE CYAN WHITE NC` defined as `\033[…m` escapes, `NC := \033[0m`.
6. **`.DEFAULT_GOAL := help`**.
7. **Categorized `help` target** — boxed title (`════` rule in CYAN), a usage line, then one block per category that greps `$(MAKEFILE_LIST)` for `^<prefix>…:.*?## ` lines and formats them with `awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'`, and an `Examples:` footer.
8. **Every target is `.PHONY` and self-documents** — `.PHONY: build` immediately above `build: ## Build the project`. The `## ` text is what `help` renders.
9. **Required-arg guard idiom** — for targets taking a variable:
   ```make
   @if [ -z "$(PKG)" ]; then \
       echo "$(RED)Error: Please specify package with PKG=package-name$(NC)"; \
       exit 1; \
   fi
   ```
10. **Echo conventions** — YELLOW for "in progress…", GREEN `✓` prefix for success, RED `Error:` for failure, CYAN for info/headers. Recipe action lines are prefixed `@` to suppress echoing the command itself.
11. **Composite targets** — aggregate via prerequisites: `quality: lint format-check typecheck security`, `clean: clean-deps clean-dist clean-cache`, `doctor: check-node validate`.
12. **Optional toolchain abstraction** — when a target supports multiple backends (npm/yarn/pnpm), an `ifeq ($(PKG_MANAGER),pnpm) … else … endif` block defines `PM_*` macros once at the top.
13. **Utility targets** — `info` (boxed key/value dump of config), `validate` (assert required files exist), `check-<tool>` (assert the toolchain is installed), often folded into `doctor`.

## Detection Signals

When auditing a target `*.Makefile`, these suggest drift from the house style:

- A target definition (`name:`) with no `## ` doc comment on the same line → it won't appear in `help`.
- A target whose name is **not** matched by any of the `help` block grep prefixes → orphaned from the menu even though documented.
- Missing or stale `.PHONY` declaration for a target (especially `clean`, `build`, `test`, `help` — names that collide with real files/dirs).
- No `.DEFAULT_GOAL := help`, or no `help` target at all.
- Color variables referenced (`$(GREEN)`) but not defined, or defined but recipes use bare `echo` without them.
- A target that consumes a variable (`$(PKG)`, `$(NAME)`, `$(CMD)`, `$(FILE)`, `$(SCRIPT)`) with no `[ -z "$(VAR)" ]` guard.
- Config values hard-coded in recipes instead of lifted to a `?=` variable at the top.
- Recipe lines not prefixed with `@` (leaking the raw command before its output).
- Missing `# === Section ===` structure / header block.

## Validation Steps

1. **Read the target file.** `Read <file>.Makefile`.
2. **List declared targets vs. documented targets.** `grep -nE '^[a-zA-Z0-9_-]+:' <file>` for all targets; `grep -nE '^[a-zA-Z0-9_-]+:.*## ' <file>` for documented ones. Any target in the first set but not the second is undocumented.
3. **Check `.PHONY` coverage.** `grep -nE '^\.PHONY:' <file>` — every non-file target should have one. Cross-check against the target list from step 2.
4. **Confirm `help` plumbing.** Grep for `.DEFAULT_GOAL := help`, a `help:` target, and `$(MAKEFILE_LIST)`. Extract the prefix regexes from each `help` block and verify every documented target name matches at least one block's pattern.
5. **Check color palette + echo conventions.** Confirm `RED GREEN YELLOW CYAN NC` (at minimum) are defined; spot-check recipes use `$(YELLOW)…$(NC)` for progress and `$(GREEN)✓` for success.
6. **Check arg guards.** For each `$(VAR)` referenced in a recipe that isn't a config/metadata var, confirm a `[ -z "$(VAR)" ]` guard precedes its use.
7. **Dry-run the menu.** `make -f <file>.Makefile help` — visually confirm every target appears under a category and nothing is missing. (Safe; `help` only echoes.)

## Remediation Actions

1. **Add the missing `## ` doc** to any orphaned target, written in the imperative ("Build the project", "Run all tests"), and confirm its name prefix is caught by a `help` block — if not, either rename to fit an existing category or add a new category block to `help`.
2. **Add `.PHONY: <target>`** immediately above any non-file target lacking it.
3. **Lift hard-coded values** (ports, image names, dirs) into `?=` config variables in the `# === Configuration Variables ===` section, referencing the closest sibling Makefile for naming (`PORT`, `BUILD_DIR`, `IMAGE_NAME`, …).
4. **Wrap variable-consuming recipes** in the required-arg guard idiom, with a RED error message naming the variable and its expected form.
5. **Convert bare `echo`** to the color convention; prefix success with `✓`, errors with `Error:`, and `@`-prefix every recipe action line.
6. **Backfill the scaffold** — if header block, color palette, `.DEFAULT_GOAL`, or categorized `help` are absent, copy the structure verbatim from the closest sibling exemplar and adapt.

## Scaffolding a New Makefile

When asked to create a new `*.Makefile` (e.g. `python.Makefile`, `go.Makefile`, `rust.Makefile`):

1. **Pick the closest sibling exemplar** as the template — `npm.Makefile` (single-project build/test/lint/clean), `npm-workspace.Makefile` (monorepo with per-package fan-out), `docker.Makefile` / `docker-py.Makefile` (container lifecycle).
2. **Copy the skeleton**: header block → config vars (`?=`) → toolchain abstraction (`ifeq` if multi-backend) → metadata (`:=`/`$(shell)`) → color palette → `.DEFAULT_GOAL := help` → categorized `help` → sections.
3. **Map the project type's verbs** onto the standard target vocabulary: `install`/`ci`, `add`/`remove`/`update`, `build`/`rebuild`/`watch`, `start`/`dev`/`serve`, `test`/`test-cov`/`test-watch`/`test-file`, `lint`/`format`/`typecheck`/`security`/`quality`, `clean`/`clean-*`/`clean-all`, `info`/`validate`/`check-<tool>`/`doctor`.
4. **Wire each new target into `help`** — assign it to a category block whose grep prefix matches its name (or add a block).
5. **Set `.PHONY`, `## ` docs, color echoes, and arg guards** on every target as you write it — don't defer.
6. **Add the README usage stanza** — append a `make -f <name>.Makefile [target]` section to `README.md` mirroring the existing Docker Makefile usage block.

## Prevention Guardrails

- **`make help` is the contract** — a target that doesn't show up in `make help` does not exist for users. Run it after every edit.
- **Copy a sibling target as the template** for any new target rather than writing one freehand — the idiom (`@`, color, `✓`, guard) comes along for free.
- **Lint check** (optional CI): grep for `^[a-z][a-zA-Z0-9_-]*:` targets and assert each has a matching `## ` and `.PHONY` line; fail the build on a mismatch.
- **One naming vocabulary** across all project-type Makefiles so muscle memory transfers (`make test`, `make clean`, `make info` mean the same thing everywhere).

## Cross-Project Application

To apply this style to a Makefile in an unfamiliar repo:

1. Check for the load-bearing markers: `.DEFAULT_GOAL := help`, a `help:` target that greps `$(MAKEFILE_LIST)`, and a color palette. Their absence means the whole convention is missing — scaffold from a sibling exemplar.
2. Run the **Validation Steps** target-by-target and bucket findings.
3. Report per-file as **PASS** (matches the house style), **WARN** (signals present, e.g. a few undocumented targets but core plumbing intact), or **FAIL** (no `help`/color/`.PHONY` scaffold — needs full backfill), with `file:line` evidence and the specific remediation for each finding.

## Usage

When invoked against a target Makefile (or asked to author a new one):

1. Run the **Detection Signals** checks against the target.
2. For each signal that fires, execute the **Validation Steps**.
3. If confirmed, apply **Remediation Actions** (or **Scaffolding** for a new file).
4. Recommend applicable **Prevention Guardrails**.
5. Report findings as: PASS (no signals), WARN (signals but core plumbing intact), or FAIL (convention missing or broken + remediation applied), always citing `file:line`.
