# opencode-spaetzle 🥣

> **Smart Programming Ägent for Task-realization with Zero-friction in a Locked-down Environment.**

A minimal but practical Docker-based development environment for running the
[OpenCode](https://opencode.ai) AI coding agent interactively on any local repository.

---

## TLDR — Install & Run

### Bash (Linux/macOS/Git Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash
```

### PowerShell (Windows)

```powershell
irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.ps1 | iex
```

After installation, run:

```bash
spaetzle
```

This starts the container with your current directory mounted as `/workspace`.

---

## Features

- **Debian bookworm-slim** base — minimal, stable, production-grade
- Full **Node.js 22 / npm** stack for OpenCode and related tooling (via [NodeSource](https://github.com/nodesource/distributions))
- Rich set of **CLI tools**: `ripgrep`, `fd`, `bat`, `tree`, `ctags`, `jq`, `htop` and more
- **[OpenCode CLI](https://opencode.ai)** pre-installed and on `PATH`
- **[Claude Code CLI](https://claude.ai/code)** pre-installed and on `PATH`
- **[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc)** pre-installed and pre-configured for OpenCode
- **[GSD2 (gsd-pi)](https://github.com/gsd-build/gsd-2)** pre-installed (`gsd` / `gsd-cli` commands available)
- Sensible shell aliases (`ll`, `cat` → `batcat`)
- Interactive terminal support (`TERM=xterm-256color`)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.10
- `GITHUB_TOKEN` (optional, for GitHub Copilot provider)

---

## What gets mounted

| Host path | Container path | Mode |
|-----------|---------------|------|
| `~/.gitconfig` | `/root/.gitconfig` | ro |
| `~/.config/git/` | `/root/.config/git/` | ro |
| `~/.ssh/` | `/root/.ssh/` | ro |
| `~/.npmrc` | `/root/.npmrc` | ro |
| `~/.config/npm/` | `/root/.config/npm/` | ro |
| `~/.m2/` | `/root/.m2/` | ro |
| `~/.config/github-copilot/` | `/root/.config/github-copilot/` | ro |
| `~/.local/share/opencode/` | `/root/.local/share/opencode/` | ro |
| `~/.claude/` | `/root/.claude/` | ro |
| `$(pwd)` | `/workspace` | **rw** |

---

## Environment variables forwarded

- `GITHUB_TOKEN` / `GH_TOKEN`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`

---

## Usage

### Starting OpenCode

```bash
spaetzle
```

### Passing a custom command

```bash
spaetzle -- opencode
```

### Passing environment variables

```bash
spaetzle -e OPENAI_API_KEY=sk-...
```

### Version info

```bash
spaetzle --version
```

---

## Customization

### Custom Docker image

```bash
OPENCODE_IMAGE=my-custom-image spaetzle
```

Or during install:
```bash
curl -fsSL .../install.sh | bash -s -- --image my-registry/opencode-spaetzle:dev
```

### Custom install location

```bash
curl -fsSL .../install.sh | bash -s -- --install-dir /usr/local/bin
```

---

## Company certificates (Helvetia)

If you need company CA certificates, use the helvetia install script:

```bash
irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.ps1 | iex
```

This builds a local wrapper image with your certificates baked in. See the script for customization options.

---

## Dev Container

Add `.devcontainer/devcontainer.json` to your project:

```jsonc
{
  "name": "opencode-spaetzle",
  "image": "ghcr.io/tiliavir/opencode-spaetzle:latest",
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
    "source=${localEnv:HOME}/.local/share/opencode,target=/root/.local/share/opencode,type=bind,readonly",
    "source=${localEnv:HOME}/.claude,target=/root/.claude,type=bind,readonly"
  ],
  "postCreateCommand": "opencode --version",
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

---

## Building from source

```bash
docker build -t opencode-spaetzle .
```

---

## Security notes

- **Never bake credentials** — API keys must be passed at runtime via `-e` or mounted read-only
- **Read-only mounts** — All config mounts use `:ro`; only workspace is `:rw`
- **No tokens in URLs** — Use SSH remotes or credential helpers, never `https://token@github.com/...`

---

## Project structure

```
opencode-spaetzle/
├── .github/workflows/     # CI/CD
├── docs/                   # Architecture & development docs
├── scripts/
│   ├── install.sh         # Bash install script
│   ├── install.ps1        # PowerShell install script
│   ├── install-helvetia.sh
│   ├── install-helvetia.ps1
│   └── run.sh            # Legacy wrapper
├── Dockerfile
└── README.md
```

---

## License

[MIT](LICENSE)
