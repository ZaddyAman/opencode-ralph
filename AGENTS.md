# AGENTS.md — Project Conventions

> This file is read automatically by AI coding tools. Define your project's conventions, patterns, and gotchas here. Ralph will follow these conventions and append new learnings as they are discovered.

## Build System
- Describe your build tool (npm, cargo, pip, make, etc.)
- Install dev: `your install command here`
- Install prod: `your install command here`

## Quality Checks
```bash
# Linting
# Example: ruff check src/

# Type checking
# Example: mypy src/

# Tests (stop on first failure)
# Example: pytest tests/ -x
```

## Project Structure
```
src/
├── module_a/     — What this module does
├── module_b/     — What this module does
└── ...
```

## Key Conventions
- Language version (e.g., Python 3.11+, TypeScript 5.x)
- Naming conventions (camelCase, snake_case, etc.)
- Testing framework
- How secrets/config are managed
- Logging approach
- File size limits (functions < 50 lines, classes < 300 lines)

## Patterns Discovered by Ralph
<!-- Ralph will append learnings here after each iteration -->

---

*Replace the examples above with your project's actual conventions. This is a template.*
