# opencode-spaetzle 🥣

> **Smart Programming Ägent for Task-realization with Zero-friction in a Locked-down Environment.**

A minimal but practical Docker-based development environment for running the
[OpenCode](https://opencode.ai) AI coding agent interactively on any local repository.

---

## TLDR

```bash
#!/usr/bin/env bash
# Docker wrapper for opencode-spaetzle with auto-labeling and mounts

set -euo pipefail

IMAGE="${OPENCODE_IMAGE:-ghcr.io/tiliavir/opencode-spaetzle:latest}"
WORKSPACE="$(pwd)"
LABEL="spaetzle-$(basename "$WORKSPACE")"
HOME_DIR="${HOME}"

exec docker run -it \
  --name "$LABEL" \
  -v "$WORKSPACE:/workspace" \
  -w /workspace \
  -v "${HOME_DIR}/.gitconfig:/root/.gitconfig:ro" \
  -v "${HOME_DIR}/.config/git:/root/.config/git:ro" \
  -v "${HOME_DIR}/.ssh:/root/.ssh:ro" \
  -v "${HOME_DIR}/.local/share/opencode:/root/.local/share/opencode:ro" \
  "$IMAGE" \
  "$@"
```

```powershell
#!/usr/bin/env pwsh
# Docker wrapper for opencode-spaetzle with auto-labeling and mounts

$ErrorActionPreference = "Stop"

$Image = $env:OPENCODE_IMAGE ?? "ghcr.io/tiliavir/opencode-spaetzle:latest"
$Workspace = Get-Location
$Label = "spaetzle-$(Split-Path -Leaf $Workspace)"
$HomeDir = $env:USERPROFILE

$DockerArgs = @(
    "run", "-it",
    "--name", $Label,
    "-v", "$($Workspace):/workspace",
    "-w", "/workspace",
    "-v", "$HomeDir\.gitconfig:/root/.gitconfig:ro",
    "-v", "$HomeDir\.config\git:/root/.config/git:ro",
    "-v", "$HomeDir\.ssh:/root/.ssh:ro",
    "-v", "$HomeDir\.local\share\opencode:/root/.local/share/opencode:ro",
    $Image
)

# Pass through any additional arguments
if ($args.Count -gt 0) {
    $DockerArgs += $args
}

& docker @DockerArgs
```

## Why the name "opencode-spaetzle"?

**Spätzle** (pronounced *shpets-leh*) are soft egg noodles — simple, comforting, and
deeply satisfying — much like the developer experience this container tries to provide.

The acronym unpacks as:

**S**mart **P**rogramming **Ä**gent for **T**ask-realization with **Z**ero-friction in a **L**ocked-down **E**nvironment.

Just like Spätzle, it gets the job done and leaves you happy.

---

## Features

- **Debian bookworm-slim** base — minimal, stable, production-grade
- Full **Node.js / npm** stack for OpenCode and related tooling
- Rich set of **CLI tools**: `ripgrep`, `fd`, `bat`, `tree`, `ctags`, `jq`, `htop` and more
- **[OpenCode CLI](https://opencode.ai)** pre-installed and on `PATH`
- **[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc)** pre-installed and pre-configured for OpenCode
- Sensible shell aliases (`ll`, `cat` → `batcat`)
- Interactive terminal support (`TERM=xterm-256color`)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) ≥ 20.10

---

## Building the image

```bash
docker build -t opencode-dev .
```

---

## Running the container

### Minimal run (workspace only)

Mount your project directory as `/workspace` and start an interactive shell:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

### Minimal run with GitHub Copilot (recommended)

Pass your `GITHUB_TOKEN` as an environment variable so OpenCode can use the
**GitHub Copilot** provider without an interactive login:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

> **Note:** `GH_TOKEN` is also accepted in the `scripts/run.sh` wrapper and will
> be forwarded as `GITHUB_TOKEN`.

### Full run (workspace + Copilot token + host Git config + SSH)

This is the recommended command for daily use — it forwards your Git identity,
SSH keys, and GitHub token so everything works as on the host:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
  -v "${HOME}/.gitconfig:/root/.gitconfig:ro" \
  -v "${HOME}/.config/git:/root/.config/git:ro" \
  -v "${HOME}/.ssh:/root/.ssh:ro" \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

### Convenience wrapper script

Instead of typing all the flags every time, use the bundled helper:

```bash
# auto-detects git config, SSH keys, auth stores, and GITHUB_TOKEN
./scripts/run.sh
```

See [scripts/run.sh](scripts/run.sh) for full details and customisation options.

### Passing a different AI provider API key

OpenCode supports other providers. Pass the relevant key as an environment
variable:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  -e OPENAI_API_KEY=sk-... \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

---

## GitHub Copilot authentication

OpenCode supports GitHub Copilot as an LLM backend. Two auth paths are
supported:

### Option A — `GITHUB_TOKEN` environment variable (recommended)

Pass a GitHub personal access token (or a token from `gh auth token`) at
runtime:

```bash
docker run -it \
  -e GITHUB_TOKEN="$(gh auth token)" \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

OpenCode will pick up `GITHUB_TOKEN` and authenticate with Copilot without any
interactive prompts.

### Option B — Mount host auth stores (read-only)

If you have already authenticated on the host (via `gh auth login` or the
Copilot extension), mount the credential stores into the container:

```bash
docker run -it \
  -v "${HOME}/.config/github-copilot:/root/.config/github-copilot:ro" \
  -v "${HOME}/.local/share/opencode:/root/.local/share/opencode:ro" \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/tiliavir/opencode-spaetzle:latest
```

> **Important:** Both mounts are **read-only** (`:ro`). No credentials are ever
> written back to the host from inside the container.

---

## Using host Git config & SSH

### Git identity / config (safe, read-only mounts)

Mount your host Git config so `git` inside the container uses the same name,
email, aliases, and settings:

```bash
# Core config (~/.gitconfig)
-v "${HOME}/.gitconfig:/root/.gitconfig:ro"

# XDG-style config directory (optional, for setups that use ~/.config/git)
-v "${HOME}/.config/git:/root/.config/git:ro"
```

Verify inside the container:

```bash
git config --list
# → user.name=Your Name
# → user.email=you@example.com
# → (all your aliases and settings)
```

### Git authentication (choose one)

#### Recommended: SSH remotes

Mount your SSH keys read-only and make sure the repository uses an SSH remote:

```bash
-v "${HOME}/.ssh:/root/.ssh:ro"
```

```bash
# Inside the container, verify your remote is SSH:
git remote -v
# → origin  git@github.com:OWNER/REPO.git (fetch)

# Test connectivity:
ssh -T git@github.com
```

> **Tip:** If your host SSH keys use a passphrase, start `ssh-agent` on the host
> and forward the socket with `-v "${SSH_AUTH_SOCK}:/tmp/ssh_auth.sock" -e SSH_AUTH_SOCK=/tmp/ssh_auth.sock`.

#### Alternative: HTTPS with token

Use a `.netrc` file (mounted read-only) or pass the token directly in the git
credential helper. **Never embed tokens in remote URLs** — they appear in
`git remote -v` output and shell history.

```bash
# Recommended: use git credential store via .netrc
-v "${HOME}/.netrc:/root/.netrc:ro"
```

---

## Starting OpenCode inside the container

Once inside the container, simply run:

```bash
opencode
```

OpenCode will start its interactive TUI and allow you to analyse and modify the
mounted repository.

### Using GSD

[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc) is also
available and pre-configured to delegate to OpenCode:

```bash
npx get-shit-done-cc@latest
```

---

## Using opencode-spaetzle as a Dev Container

You can use this image directly as a
[VS Code Dev Container](https://containers.dev/) or with any IDE that supports
the Dev Containers specification.

### Minimal `.devcontainer/devcontainer.json`

Create a `.devcontainer/devcontainer.json` file in your project:

```jsonc
{
  "name": "opencode-spaetzle",
  "image": "ghcr.io/tiliavir/opencode-spaetzle:latest",
  // Mount the project into /workspace
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  // Forward tokens and keys from the host environment
  "remoteEnv": {
    // GitHub Copilot provider (recommended)
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}",
    // Alternative AI providers
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}",
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  },
  // Read-only mounts for host Git config and SSH keys (all optional)
  "mounts": [
    "source=${localEnv:HOME}/.gitconfig,target=/root/.gitconfig,type=bind,readonly",
    "source=${localEnv:HOME}/.config/git,target=/root/.config/git,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh,target=/root/.ssh,type=bind,readonly",
    // Copilot credential store (if you authenticated on the host)
    "source=${localEnv:HOME}/.config/github-copilot,target=/root/.config/github-copilot,type=bind,readonly",
    // OpenCode auth store (if you authenticated on the host)
    "source=${localEnv:HOME}/.local/share/opencode,target=/root/.local/share/opencode,type=bind,readonly"
  ],
  // Post-create: nothing extra needed — OpenCode is already installed
  "postCreateCommand": "opencode --version",
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

> **Note:** Dev Containers will silently skip mounts whose source path does not
> exist on the host, so it is safe to include all optional mounts above.

### Build from source instead of pulling

If you prefer to build the image locally from the `Dockerfile`:

```jsonc
{
  "name": "opencode-spaetzle",
  "build": {
    "context": ".",
    "dockerfile": "Dockerfile"
  },
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "remoteEnv": {
    "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}",
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}"
  },
  "mounts": [
    "source=${localEnv:HOME}/.gitconfig,target=/root/.gitconfig,type=bind,readonly",
    "source=${localEnv:HOME}/.ssh,target=/root/.ssh,type=bind,readonly"
  ]
}
```

Once VS Code detects the `.devcontainer` folder it will prompt you to
**Reopen in Container**. After the container starts, open a terminal and run:

```bash
opencode
```

---

## Project structure

```
opencode-spaetzle/
├── .devcontainer/          # (optional, add to your own project)
├── .github/
│   ├── dependabot.yml      # Automated dependency updates
│   └── workflows/
│       ├── ci.yml          # Quality & security checks
│       └── release.yml     # Docker image build & publish
├── docs/
│   ├── architecture.md     # Image design decisions
│   └── development.md      # Contributing guide
├── scripts/
│   └── run.sh              # Convenience wrapper (auto-mounts, forwards tokens)
├── Dockerfile
├── .dockerignore
└── README.md
```

---

## Security notes

### Never bake credentials into the image

API keys and tokens must **always** be passed at runtime via `-e` environment
variables or read-only volume mounts — never baked into the `Dockerfile` or
committed to source control.

### Prefer read-only mounts

All credential and config mounts shown in this document use the `:ro` (read-only)
flag. This ensures container processes cannot modify your host credentials even if
the container is compromised.

```bash
# Good — read-only
-v "${HOME}/.ssh:/root/.ssh:ro"

# Avoid — writable mount gives container full write access to your SSH keys
-v "${HOME}/.ssh:/root/.ssh"
```

### Never embed tokens in Git remote URLs

Tokens embedded in HTTPS remote URLs appear in `git remote -v` output and shell
history, and can be accidentally committed in scripts or logs.

```bash
# Bad — token visible in remote URL
git remote set-url origin https://token:${GITHUB_TOKEN}@github.com/OWNER/REPO.git

# Good — use SSH remotes or a credential helper
git remote set-url origin git@github.com:OWNER/REPO.git
```

### Mounted credentials grant container-level access

When you mount `~/.ssh` or `~/.config/github-copilot` into the container, any
process running inside has the same access to those credentials as your host user.
Only run trusted images and review any tools you install inside the container.

---

## Contributing

See [docs/development.md](docs/development.md).

---

## License

[MIT](LICENSE)

