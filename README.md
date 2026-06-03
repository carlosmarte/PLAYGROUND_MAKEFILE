# examples-makefiles

## Docker Makefile Usage

Since `docker-py.Makefile` is not the default Makefile, you need to specify it explicitly when running make commands.

### Usage Syntax

```bash
make -f docker-py.Makefile [target]
```

### Quick Start

```bash
# Show all available commands
make -f docker-py.Makefile

# Build Docker image
make -f docker-py.Makefile build

# Run tests
make -f docker-py.Makefile test

# Install dependencies with Poetry
make -f docker-py.Makefile poetry-install

# Open shell in container
make -f docker-py.Makefile shell
```

### Alternative: Create an Alias

To simplify usage, you can create a shell alias:

```bash
# Add to your .bashrc, .zshrc, or shell config
alias dpymake='make -f docker-py.Makefile'

# Then use:
dpymake build
dpymake test
dpymake shell
```

### Common Commands

| Command | Description |
|---------|-------------|
| `make -f docker-py.Makefile` | Show help with all available commands |
| `make -f docker-py.Makefile build` | Build development Docker image |
| `make -f docker-py.Makefile test` | Run pytest test suite |
| `make -f docker-py.Makefile test-cov` | Run tests with coverage report |
| `make -f docker-py.Makefile poetry-add PKG=package` | Add a new package |
| `make -f docker-py.Makefile shell` | Open bash shell in container |
| `make -f docker-py.Makefile python` | Open Python REPL |
| `make -f docker-py.Makefile lint` | Run code linting |
| `make -f docker-py.Makefile format` | Format code with black |
| `make -f docker-py.Makefile clean` | Remove container and image |

## Semantic-Release Makefile Usage

`semantic-release.Makefile` forces and troubleshoots [semantic-release](https://semantic-release.gitbook.io/) runs. semantic-release has no `--force` flag by design — a release is a pure function of commit history — so to "force" one you push an empty commit whose message implies a release (the `--allow-empty` trick).

### Usage Syntax

```bash
make -f semantic-release.Makefile [target]
```

### Quick Start

```bash
# Show all available commands
make -f semantic-release.Makefile

# Force a PATCH release (v1.0.1 -> v1.0.2) via an empty `fix:` commit
make -f semantic-release.Makefile patch

# Force a MINOR release (v1.0.1 -> v1.1.0), with a custom message
make -f semantic-release.Makefile minor MSG="add retry logic"

# Push the branch + tags so CI runs semantic-release
make -f semantic-release.Makefile push

# Diagnose "I pushed but it still won't release!"
make -f semantic-release.Makefile troubleshoot
```

### Common Commands

| Command | Description |
|---------|-------------|
| `make -f semantic-release.Makefile` | Show help with all available commands |
| `make -f semantic-release.Makefile patch` | Empty `fix:` commit to force a PATCH release |
| `make -f semantic-release.Makefile minor` | Empty `feat:` commit to force a MINOR release |
| `make -f semantic-release.Makefile major` | Empty `feat!:` + BREAKING CHANGE commit to force a MAJOR release |
| `make -f semantic-release.Makefile force TYPE=fix MSG="..."` | Force a release with a custom commit type/message |
| `make -f semantic-release.Makefile release-dry` | Preview the next version without publishing |
| `make -f semantic-release.Makefile troubleshoot` | Run the 3-point "why won't it release?" checklist |
| `make -f semantic-release.Makefile last-commit` | Show whether the last commit triggers a release |
| `make -f semantic-release.Makefile latest-tag` | Compare latest git tag vs. published npm version |
| `make -f semantic-release.Makefile tag-sync` | Find tags pushed to git but not the remote |
| `make -f semantic-release.Makefile RELEASE_BRANCH=master patch` | Override the release branch (default `main`) |

> The three forced-release targets only create the commit. Run `push` afterward so CI picks it up. If a release still doesn't fire, `troubleshoot` checks the three usual causes: wrong branch, non-conventional commit message, and a git tag whose npm publish previously failed.