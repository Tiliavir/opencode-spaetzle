# Development guide

This document covers how to develop and maintain the `devcon-spaetzle` project (claude variant).

## Repository structure

```
devcon-spaetzle/
├── .github/
│   ├── dependabot.yml          # Automated dependency updates
│   └── workflows/
│       ├── ci.yml              # Quality checks + security scan + dependabot automerge
│       └── release.yml         # Docker image build & publish to GHCR
├── docs/
│   ├── architecture.md         # Image design decisions
│   └── development.md          # This file
├── scripts/
│   ├── run.sh                  # Convenience run wrapper (auto-mounts, forwards tokens)
│   ├── install.sh              # Bash installer (generates spaetzle wrapper)
│   └── install.ps1             # PowerShell installer (generates spaetzle.ps1 + .cmd)
├── Dockerfile                  # Main image definition
├── .dockerignore               # Files excluded from Docker build context
├── README.md                   # User-facing documentation
└── LICENSE                     # MIT license
```

## Local development workflow

### Build the image

```bash
docker build -t devcon-spaetzle:claude .
```

### Run the container

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  devcon-spaetzle:claude
```

Or use the convenience wrapper (auto-detects git config, SSH keys, and tokens):

```bash
./scripts/run.sh

# Recreate the container for a fresh start
./scripts/run.sh --recreate
```

### Lint the Dockerfile

Install [hadolint](https://github.com/hadolint/hadolint) and run:

```bash
hadolint Dockerfile
```

### Scan for vulnerabilities

Install [Trivy](https://github.com/aquasecurity/trivy) and run:

```bash
trivy image devcon-spaetzle:claude
```

## CI/CD pipeline

### CI workflow (`.github/workflows/ci.yml`)

Triggered on every push to `main` or `claude` and on every pull request targeting `main`.

| Job | Description |
|-----|-------------|
| `lint` | Runs `hadolint` against the `Dockerfile` — fails on warnings or higher |
| `security` | Builds the image and runs `trivy` — uploads SARIF results to GitHub Security |
| `build` | Full Docker build (no push) — validates the `Dockerfile` end-to-end |
| `automerge` | Merges Dependabot PRs automatically after all checks pass |

### Release workflow (`.github/workflows/release.yml`)

Triggered when a tag matching `v*.*.*` is pushed, or when the `claude` branch is pushed.

**For the `claude` branch:**
- Builds multi-arch (`linux/amd64`, `linux/arm64`)
- Pushes to GHCR as `ghcr.io/tiliavir/devcon-spaetzle:claude`
- No GitHub Release is created

**For semver tags:**
1. Builds the image for `linux/amd64` **and** `linux/arm64` (Apple Silicon compatible)
2. Pushes to [GitHub Container Registry (GHCR)](https://ghcr.io) with multiple tags:
   - `ghcr.io/tiliavir/devcon-spaetzle:latest`
   - `ghcr.io/tiliavir/devcon-spaetzle:1.2.3`
   - `ghcr.io/tiliavir/devcon-spaetzle:1.2`
   - `ghcr.io/tiliavir/devcon-spaetzle:1`
3. Creates a GitHub Release with auto-generated release notes

## Publishing the claude variant

Simply push to the `claude` branch:

```bash
git push origin claude
```

The release workflow automatically builds and publishes
`ghcr.io/tiliavir/devcon-spaetzle:claude`.

## Creating a release (main branch)

```bash
# Tag the commit
git tag v1.0.0

# Push the tag — this triggers the release workflow
git push origin v1.0.0
```

## Dependabot

Dependabot is configured (`.github/dependabot.yml`) to open weekly PRs for:

- Docker base image updates (`FROM debian:bookworm-slim`)
- GitHub Actions version bumps

These PRs are auto-merged by the `automerge` job in `ci.yml` once all CI checks pass,
using the `GH_ACTION_MERGER_TOKEN` repository secret.

## Required repository secrets

| Secret | Purpose |
|--------|---------|
| `GH_ACTION_MERGER_TOKEN` | PAT with `pull-requests:write` and `contents:write` — used by Dependabot automerge |

`GITHUB_TOKEN` is used for pushing to GHCR and is provided automatically by GitHub Actions.
