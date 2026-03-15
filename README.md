# opencode-spaetzle 🥣

> **Smart Programming Ägent for Task-realization with Zero-friction in a Locked-down Environment.**

A minimal but practical Docker-based development environment for running the
[OpenCode](https://opencode.ai) AI coding agent interactively on any local repository.

---

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

Mount your project directory as `/workspace` and start an interactive shell:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  opencode-dev
```

### Passing an OpenCode API key

OpenCode requires an API key for the configured AI provider. Pass it as an environment variable:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -w /workspace \
  -e OPENAI_API_KEY=sk-... \
  -l optional-label \
  ghcr.io/tiliavir/opencode-spaetzle:latest
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
  // Forward your AI provider API key from the host
  "remoteEnv": {
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}"
  },
  // Post-create: nothing extra needed — OpenCode is already installed
  "postCreateCommand": "opencode --version",
  "terminal.integrated.defaultProfile.linux": "bash"
}
```

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
    "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}"
  }
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
├── Dockerfile
├── .dockerignore
└── README.md
```

---

## Contributing

See [docs/development.md](docs/development.md).

---

## License

[MIT](LICENSE)

