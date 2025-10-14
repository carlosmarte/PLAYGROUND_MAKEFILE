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