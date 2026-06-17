# devcon-spaetzle (claude variant)

> **Smart Programming Ägent for Task-realization with Zero-friction in a Locked-down Environment.**

A minimal but practical Docker-based development environment for running
[Claude Code](https://claude.ai/code) interactively on any local repository.
Comes with the [ponytail](https://github.com/DietrichGebert/ponytail) plugin
pre-installed.

---

## TLDR — Install & Run

### Bash (Linux/macOS/Git Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/tiliavir/devcon-spaetzle/claude/scripts/install.sh | bash
```

### PowerShell (Windows)

```powershell
irm https://raw.githubusercontent.com/tiliavir/devcon-spaetzle/claude/scripts/install.ps1 | iex
```

After installation, run:

```bash
spaetzle
```

This starts the container with your current directory mounted as `/workspace`.

---

## Features

- **Debian bookworm-slim** base — minimal, stable, production-grade
- Full **Node.js 22 / npm** stack for tooling (via [NodeSource](https://github.com/nodesource/distributions))
- Rich set of **CLI tools**: `ripgrep`, `fd`, `bat`, `tree`, `jq` and more
- **[Claude Code CLI](https://claude.ai/code)** pre-installed and on `PATH`
- **[ponytail](https://github.com/DietrichGebert/ponytail)** plugin pre-installed — lazy senior dev mode for Claude Code
- **[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc)** pre-installed and pre-configured for Claude
- **[Graphify (graphifyy)](https://pypi.org/project/graphifyy/)** pre-installed — AI knowledge graph
- Sensible shell aliases (`ll`, `cat` → `batcat`)
- Interactive terminal support (`TERM=xterm-256color`)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.10
- `ANTHROPIC_API_KEY` (for Claude Code)

---

## What gets mounted

| Host path | Container path | Mode |
|-----------|---------------|------|
| `~/.gitconfig` | `/root/.gitconfig` | ro |
| `~/.config/git/` | `/root/.config/git/` | ro |
| `~/.ssh/` | `/root/.ssh/` | ro |
| `~/.config/github-copilot/` | `/root/.config/github-copilot/` | ro |
| `~/.claude/` | `/root/.claude/` | **rw** |
| `$(pwd)` | `/workspace` | **rw** |

> **Note:** The `~/.claude/` mount is read-write because Claude Code writes auth
> credentials, session state, and plugin data during normal operation. When mounted,
> host settings take precedence over the image's baked defaults (including the
> pre-configured ponytail plugin). If ponytail is not configured on the host,
> enable it via `claude /plugin install ponytail@ponytail`.

---

## Environment variables forwarded

- `GITHUB_TOKEN` / `GH_TOKEN`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`

---

## Usage

### Starting the container

```bash
spaetzle
```

### Passing a custom command

```bash
spaetzle -- claude
```

### Passing environment variables

```bash
spaetzle -e ANTHROPIC_API_KEY=sk-...
```

### Version info

```bash
spaetzle --version
```

### Recreate the container

```bash
spaetzle --recreate
```

Removes the existing container for the current workspace and starts a fresh one.

### Update to the latest version

```bash
spaetzle --update
```

Pulls the latest image and re-installs the wrapper script. Use this when a new
version of devcon-spaetzle is released.

---

## Customization

### Custom Docker image

```bash
SPAETZLE_IMAGE=my-custom-image spaetzle
```

Or during install:
```bash
curl -fsSL .../install.sh | bash -s -- --image my-registry/devcon-spaetzle:dev
```

### Custom install location

```bash
curl -fsSL .../install.sh | bash -s -- --install-dir /usr/local/bin
```

---

## Dev Container

Add `.devcontainer/devcontainer.json` to your project:

```jsonc
{
  "name": "devcon-spaetzle",
  "image": "ghcr.io/tiliavir/devcon-spaetzle:claude",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "remoteEnv": {
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}",
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}",
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  },
  "mounts": [
    "source=${localEnv:HOME}/.gitconfig,target=/root/.gitconfig,type=bind,readonly",
    "source=${localEnv:HOME}/.config/git,target=/root/.config/git,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh,target=/root/.ssh,type=bind,readonly",
    "source=${localEnv:HOME}/.config/github-copilot,target=/root/.config/github-copilot,type=bind,readonly",
    "source=${localEnv:HOME}/.claude,target=/root/.claude,type=bind"
  ],
  "postCreateCommand": "claude --version",
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

---

## Building from source

```bash
docker build -t devcon-spaetzle:claude .
```

---

## Security notes

- **Never bake credentials** — API keys must be passed at runtime via `-e` or mounted read-only
- **Read-only mounts** — All config mounts use `:ro` except `~/.claude/` (rw for auth/plugin state); only workspace is `:rw`
- **No tokens in URLs** — Use SSH remotes or credential helpers, never `https://token@github.com/...`

---

## Project structure

```
devcon-spaetzle/
├── .github/workflows/     # CI/CD
├── docs/                   # Architecture & development docs
├── scripts/
│   ├── install.sh         # Bash install script
│   ├── install.ps1        # PowerShell install script
│   └── run.sh            # Legacy wrapper
├── Dockerfile
└── README.md
```

---

## License

[MIT](LICENSE)
