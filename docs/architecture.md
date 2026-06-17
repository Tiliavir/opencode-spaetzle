# Architecture

This document describes the design decisions behind the `devcon-spaetzle` Docker image (claude variant).

## Base image

**`debian:bookworm-slim`** was chosen as the base image for the following reasons:

| Criterion | Why bookworm-slim |
|-----------|-------------------|
| Stability | Debian stable (bookworm = Debian 12) has long support and predictable behaviour |
| Compatibility | The Debian package ecosystem has the best coverage for developer tools |
| Node.js | Node.js 22 is installed via the [NodeSource](https://github.com/nodesource/distributions) APT repository (Debian ships only Node 18) |
| Size | `-slim` variant strips locale data and documentation, keeping the image small |
| Security | Minimal attack surface compared to a full Debian image |

## Layer structure

The `Dockerfile` is organised to maximise cache reuse and minimise the final image size:

```
debian:bookworm-slim
 └── apt packages (single RUN layer)
      └── shell aliases
           └── Node.js 22 (NodeSource)
                └── GSD install + claude config
                     └── Graphify install (pip)
                          └── Claude Code CLI (curl install)
                               └── ponytail plugin setup
                                    └── WORKDIR /workspace
```

All `apt-get` commands are combined in a single `RUN` layer and the apt cache is
removed in the same layer (`rm -rf /var/lib/apt/lists/*`) so no cache files end up
in the image.

## Installed packages

### Development / runtime

| Package | Purpose |
|---------|---------|
| `git` | Source control — essential for any coding agent workflow |
| `curl` | HTTP client — used to install Claude Code and other tools |
| `ca-certificates` | TLS trust store — required for `curl` over HTTPS |
| `nodejs` 22 / `npm` | JavaScript runtime — installed via NodeSource; required by GSD (`npx`) |
| `python3` / `python3-pip` | Python runtime — required by Graphify |
| `build-essential` | C compiler and `make` — required for native npm modules |

### Repository navigation tools

| Package | Purpose |
|---------|---------|
| `ripgrep` (`rg`) | Ultra-fast recursive grep — used by Claude Code for code search |
| `fd-find` (`fdfind` → `fd`) | Fast alternative to `find` |
| `tree` | Directory tree visualisation |

### CLI utilities

| Package | Purpose |
|---------|---------|
| `nano` | Lightweight editor for quick edits |
| `less` | Pager for viewing long output |
| `jq` | JSON processor — used for ponytail plugin setup and inspecting API responses |
| `unzip` | Archive extraction |
| `procps` | Process utilities (`ps`, `top`) |
| `bat` (`batcat`) | Syntax-highlighted `cat` replacement |

## Claude Code installation

[Claude Code](https://claude.ai/code) is Anthropic's agentic coding CLI. It is
installed using its official install script:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

The script places the binary in `~/.local/bin`, which is added to `PATH` via:

```dockerfile
ENV PATH="/root/.local/bin:${PATH}"
```

Authentication credentials are stored in `~/.claude/` on the host and can be
made available inside the container via a read-write bind mount:

```bash
docker run -it -v ~/.claude:/root/.claude:rw devcon-spaetzle:claude
```

`scripts/run.sh` mounts this directory automatically when it exists.

## Ponytail plugin

[Ponytail](https://github.com/DietrichGebert/ponytail) is a Claude Code plugin
that enforces lazy, minimal solutions — YAGNI, stdlib first, no unrequested
abstractions. It is pre-installed during the Docker build by:

1. Cloning the marketplace repo to `/root/.claude/plugins/marketplaces/ponytail/`
2. Copying it to the plugin cache at `/root/.claude/plugins/cache/ponytail/ponytail/<version>/`
3. Writing the three required config files:
   - `known_marketplaces.json` — registers the marketplace source
   - `installed_plugins.json` — tracks the installed version and commit SHA
   - `settings.json` — enables the plugin

The version is read from `.claude-plugin/plugin.json` at build time using `jq`.

**Host mount caveat:** When `~/.claude` from the host is mounted into the container,
it shadows the baked `/root/.claude` including `settings.json`. If the user's host
settings do not have ponytail enabled, the plugin will not activate despite being
installed in the image. Users should enable it on the host via
`claude /plugin install ponytail@ponytail`.

## GSD configuration

[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc) is a
productivity CLI. It is installed via `npx` during the build and pre-configured
to use Claude as its AI backend through a config file placed at
`/root/.config/gsd/config.json`.

## Working directory

The container uses `/workspace` as the default working directory. This is the
standard mount point for the host repository:

```bash
docker run -it -v $(pwd):/workspace devcon-spaetzle:claude
```

## Security considerations

- No cloud credentials or API keys are baked into the image
- API keys must be supplied at runtime via `-e` environment variables
- The image runs as `root` inside the container (acceptable for a local dev tool)
- Trivy vulnerability scanning is integrated into the CI pipeline

## Authentication design

### Environment variable (primary)

`ANTHROPIC_API_KEY` is the preferred mechanism for Claude Code authentication.
`GITHUB_TOKEN` (or `GH_TOKEN`, normalised by `scripts/run.sh`) is used for
GitHub operations. These require no persistent files and work cleanly in
CI/CD and Dev Container environments.

### Read-only credential mounts (secondary)

For users who have already authenticated on the host, credential stores can be
mounted:

| Host path | Container path | Mode | Purpose |
|-----------|---------------|------|---------|
| `~/.config/github-copilot/` | `/root/.config/github-copilot/` | ro | Copilot credential store |
| `~/.claude/` | `/root/.claude/` | rw | Claude Code credential and plugin store |

The `.claude` mount is read-write because Claude Code writes auth credentials,
session state, and plugin data during normal operation.

## Git config injection

Host Git identity and SSH keys can be injected via read-only mounts:

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `~/.gitconfig` | `/root/.gitconfig` | Core Git identity and settings |
| `~/.config/git/` | `/root/.config/git/` | XDG-style Git config directory |
| `~/.ssh/` | `/root/.ssh/` | SSH keys for remote authentication |

SSH remotes (`git@github.com:…`) are recommended over HTTPS because tokens are
never exposed in URL strings or logs.
