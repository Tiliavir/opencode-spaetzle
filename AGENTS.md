# AGENTS.md — Codebase Guide for AI Coding Agents

This repository is a Docker infrastructure project that packages the
[OpenCode](https://opencode.ai) AI coding agent as a portable container image,
with cross-platform installer scripts for Bash and PowerShell.

**There is no application source code, no package manager, and no language-level build system.**
The deliverables are a `Dockerfile` and shell scripts.

---

## Project Layout

```
opencode-spaetzle/
├── Dockerfile                  # Core artifact — the container image definition
├── scripts/
│   ├── run.sh                  # Dynamic run wrapper (detects mounts at runtime)
│   ├── install.sh              # Bash installer (generates a baked spaetzle script)
│   ├── install.ps1             # PowerShell installer (generates spaetzle.ps1 + .cmd)
│   └── install-helvetia.ps1   # Helvetia variant (adds company CA certs)
├── docs/
│   ├── architecture.md         # Design decisions and layer structure
│   └── development.md          # Developer guide: local workflow, CI/CD, releases
└── .github/
    ├── dependabot.yml
    └── workflows/
        ├── ci.yml              # Lint, security scan, build verification
        └── release.yml         # Multi-arch image build & push to GHCR on semver tags
```

---

## Build, Lint, and Test Commands

### Docker

```bash
# Build the image locally
docker build -t opencode-dev .

# Run the container against the current directory
./scripts/run.sh

# Build a named image for scanning
docker build -t opencode-spaetzle:scan .
```

### Dockerfile Linting (hadolint)

```bash
# Lint the Dockerfile (must pass with no warnings)
hadolint Dockerfile

# Or via Docker (no local install required)
docker run --rm -i hadolint/hadolint < Dockerfile
```

CI uses `hadolint/hadolint-action@v3.3.0` with `failure-threshold: warning`.
Any hadolint warning is a CI failure.

### Security Scanning (Trivy)

```bash
# Build and scan the image
docker build -t opencode-spaetzle:scan .
trivy image opencode-spaetzle:scan
```

CI uploads results as SARIF to the GitHub Security tab.

### Tests

**There is no unit or integration test suite.**
The equivalent of "running the tests" is:

```bash
hadolint Dockerfile          # Static analysis
docker build -t opencode-dev .  # End-to-end build verification
```

### Releasing

Releases are fully automated via git tags:

```bash
git tag v1.2.3
git push origin v1.2.3
```

The `release.yml` workflow builds a multi-arch image (`linux/amd64`, `linux/arm64`),
pushes it to GHCR as `ghcr.io/tiliavir/opencode-spaetzle`, and auto-creates a
GitHub Release with generated notes.

---

## Dockerfile Style Guidelines

- **Base image:** `debian:bookworm-slim` — keep it slim; avoid bloated base images.
- **Pin all package versions:** Every `apt-get install` line must include the full
  Debian version string, e.g., `git=1:2.39.5-0+deb12u3`. This ensures reproducible builds.
- **Single RUN for apt packages:** Combine all `apt-get` calls into one `RUN` layer
  and end with `rm -rf /var/lib/apt/lists/*` in the same layer to minimize image size.
- **Shell mode:** Set `SHELL ["/bin/bash", "-eo", "pipefail", "-c"]` before any `RUN`
  commands that use pipes or multi-step logic.
- **Layer ordering:** Order layers by change frequency — system packages first
  (rarely change), then tool installs, then config/runtime setup. This maximizes
  Docker build cache reuse.
- **Section comments:** Use inline comments inside multi-line `RUN` blocks to group
  related packages, e.g., `# Development / runtime`.
- **Avoid unnecessary files:** `.dockerignore` is authoritative; keep it up to date.

---

## Bash Script Style Guidelines

### Shebang and Strict Mode

Every Bash script must start with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- Use `#!/usr/bin/env bash` (portable), not `#!/bin/bash`.
- `set -euo pipefail` is mandatory — no exceptions.

### Logging

Define and use consistent named logging functions with a script-name prefix:

```bash
info()  { echo "[script-name] $*"; }
warn()  { echo "[script-name] WARNING: $*" >&2; }
error() { echo "[script-name] ERROR: $*" >&2; exit 1; }
```

Errors always go to stderr (`>&2`). `error()` must always `exit 1`.

### Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Environment / config variables | `SCREAMING_SNAKE_CASE` | `INSTALL_DIR`, `IMAGE_NAME` |
| Local variables | `snake_case` | `mount_args`, `container_id` |
| Functions | `snake_case` | `maybe_mount()`, `escape_for_double_quotes()` |

### Array Safety (under `set -u`)

Use the safe array expansion pattern to avoid unbound variable errors on empty arrays:

```bash
"${ARRAY[@]+"${ARRAY[@]}"}"
```

### Environment Variable Defaults

Use `${VAR:-default}` for optional variables with fallbacks:

```bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
```

### Process Replacement

Use `exec` for the final `docker run` invocation to replace the shell process cleanly,
ensuring correct signal propagation:

```bash
exec docker run ... "$IMAGE" "${CMD[@]}"
```

### Section Dividers

Use ASCII-art separators to visually organize long scripts:

```bash
# ── section name ──────────────────────────────────────────────────────────────
```

### Template / Code Generation

When generating scripts from templates, use:
- Heredoc (`<< 'MARKER_EOF'`) with a descriptive marker name
- `__SCREAMING_SNAKE_CASE__` tokens as placeholders for runtime substitution
- A dedicated helper function like `escape_for_double_quotes()` for safe string embedding

---

## PowerShell Script Style Guidelines

- `$ErrorActionPreference = "Stop"` at the top of every script (equivalent of `set -e`).
- Parameters go in a `param()` block at the top with typed parameters and defaults.
- Logging mirrors the Bash pattern: `Write-Info`, `Write-Warn`, `Write-Error` functions.
- Use `[System.Collections.Generic.List[string]]::new()` for dynamic lists.
- Maintain **behavioral parity** with the Bash equivalents — the Bash and PowerShell
  installers must produce functionally identical results.
- Use the same `__STATIC_MOUNTS__` / `__STATIC_MOUNT_INFO__` placeholder tokens as the
  Bash installer for cross-script consistency.

---

## CI / GitHub Actions Guidelines

- CI must pass before merging. The pipeline is: hadolint → Trivy scan → Docker build.
- Do not suppress hadolint rules in `ci.yml` without a documented justification.
- Dependabot manages Docker base image and Actions version updates (weekly cadence).
- Dependabot PRs for patch/minor updates are auto-merged by `dependabot-automerge`
  after CI passes.
- Multi-arch builds (`linux/amd64,linux/arm64`) are required for all releases.

---

## General Conventions

- **Reproducibility is paramount.** Pin everything: apt package versions, base image
  digests (for releases), and Actions versions.
- **Minimal surface area.** Do not add dependencies unless they are clearly necessary.
  Every tool in the image must justify its presence.
- **XDG compliance.** Respect `XDG_CONFIG_HOME` and `XDG_DATA_HOME` with
  `${VAR:-default}` fallbacks when dealing with config/data paths.
- **No secrets in scripts.** API keys and tokens are always injected via environment
  variables at runtime, never hardcoded.
- **Commit messages:** Use the imperative mood, present tense (e.g., `Add`, `Fix`,
  `Update`, `Remove`). Keep the subject line under 72 characters.
