# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

devcon-spaetzle (claude variant) is a Docker infrastructure project — a portable dev environment image packaging Claude Code with the ponytail plugin, GSD, and Graphify. The deliverables are a `Dockerfile` and cross-platform installer scripts (Bash + PowerShell). There is no application source code, no package manager, and no test suite.

This is the `claude` branch. The `main` branch has a different variant that includes OpenCode, Caveman, and GSD2.

## Build and Verify

```bash
# Build the image
docker build -t devcon-spaetzle:claude .

# Lint the Dockerfile (CI fails on warnings)
hadolint Dockerfile
# Or without local install:
docker run --rm -i hadolint/hadolint < Dockerfile

# Security scan
docker build -t devcon-spaetzle:scan . && trivy image devcon-spaetzle:scan

# Run locally
./scripts/run.sh
```

"Running the tests" means: `hadolint Dockerfile && docker build -t devcon-spaetzle:claude .`

## Releasing

The `claude` branch auto-publishes `ghcr.io/tiliavir/devcon-spaetzle:claude` on every push. Semver tags on `main` publish `:latest` and versioned tags.

## Dockerfile Conventions

- Base image: `debian:bookworm-slim`. Pin all apt package versions (full Debian version string).
- Single `RUN` layer for all apt packages, ending with `rm -rf /var/lib/apt/lists/*`.
- `SHELL ["/bin/bash", "-eo", "pipefail", "-c"]` before any `RUN` with pipes.
- Order layers by change frequency (system packages first, config last).
- Use section comments inside multi-line `RUN` blocks to group packages.

## Shell Script Conventions

- Shebang: `#!/usr/bin/env bash` (not `#!/bin/bash`). `set -euo pipefail` is mandatory.
- Logging functions: `info()`, `warn()` (to stderr), `error()` (to stderr + `exit 1`), prefixed with script name.
- Naming: `SCREAMING_SNAKE_CASE` for env/config vars, `snake_case` for locals and functions.
- Safe empty-array expansion: `"${ARRAY[@]+"${ARRAY[@]}"}"`.
- Final `docker run` uses `exec` for clean signal propagation.
- Section dividers: `# ── section name ──────────────────────────────────────────`
- Template placeholders: `__SCREAMING_SNAKE_CASE__` tokens, substituted at install time via heredoc.

## PowerShell Conventions

- `$ErrorActionPreference = "Stop"` at the top. Typed `param()` block for parameters.
- Logging: `Write-Info`, `Write-Warn`, `Write-Error` matching Bash pattern.
- Dynamic lists: `[System.Collections.Generic.List[string]]::new()`.
- Must maintain behavioral parity with the Bash equivalents.
- Uses same `__STATIC_MOUNTS__` / `__STATIC_MOUNT_INFO__` placeholder tokens.

## Architecture

The install scripts (`install.sh` / `install.ps1`) are **code generators**: they detect host mounts at install time and bake the results into a `spaetzle` wrapper script. The wrapper is a self-contained script that handles container lifecycle (create/reconnect/restart), mounts, and env forwarding. `run.sh` is the legacy dynamic-detection equivalent (probes mounts at runtime).

The `~/.claude/` directory is mounted read-write (unlike other mounts which are read-only) because Claude Code writes auth, session state, and plugin data during normal operation.

## CI Pipeline

Defined in `.github/workflows/ci.yml`: hadolint lint → Trivy scan → Docker build. Runs on pushes to `main` and `claude` branches and PRs to `main`. All must pass before merge. Dependabot PRs for patch/minor updates auto-merge after CI passes (requires `GH_ACTION_MERGER_TOKEN` secret).
