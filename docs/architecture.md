# Architecture

This document describes the design decisions behind the `opencode-spaetzle` Docker image.

## Base image

**`debian:bookworm-slim`** was chosen as the base image for the following reasons:

| Criterion | Why bookworm-slim |
|-----------|-------------------|
| Stability | Debian stable (bookworm = Debian 12) has long support and predictable behaviour |
| Compatibility | The Debian package ecosystem has the best coverage for developer tools |
| Node.js | `nodejs` and `npm` packages are available directly from `apt` without additional PPAs |
| Size | `-slim` variant strips locale data and documentation, keeping the image small |
| Security | Minimal attack surface compared to a full Debian image |

## Layer structure

The `Dockerfile` is organised to maximise cache reuse and minimise the final image size:

```
debian:bookworm-slim
 └── apt packages (single RUN layer)
      └── fd symlink
           └── shell aliases
                └── OpenCode CLI (curl install)
                     └── GSD install + config
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
| `curl` | HTTP client — used to install OpenCode and other tools |
| `ca-certificates` | TLS trust store — required for `curl` over HTTPS |
| `nodejs` / `npm` | JavaScript runtime — required by OpenCode CLI and GSD |
| `python3` / `python3-pip` | Python runtime — many repositories use Python tooling |
| `build-essential` | C compiler and `make` — required for native npm modules |

### Repository navigation tools

| Package | Purpose |
|---------|---------|
| `ripgrep` (`rg`) | Ultra-fast recursive grep — used by OpenCode for code search |
| `fd-find` (`fdfind` → `fd`) | Fast alternative to `find` |
| `tree` | Directory tree visualisation |
| `universal-ctags` | Code tag generation — useful for navigation and indexing |

### CLI utilities

| Package | Purpose |
|---------|---------|
| `nano` | Lightweight editor for quick edits |
| `less` | Pager for viewing long output |
| `jq` | JSON processor — handy for inspecting API responses |
| `unzip` | Archive extraction |
| `procps` | Process utilities (`ps`, `top`) |
| `htop` | Interactive process viewer |
| `bat` (`batcat`) | Syntax-highlighted `cat` replacement |

## Tool name compatibility

Debian installs the `fd` binary as `fdfind` to avoid a conflict with an existing
`fd` package. A symlink is created so tools expecting `fd` (including OpenCode) work
transparently:

```dockerfile
RUN ln -s $(which fdfind) /usr/local/bin/fd
```

## OpenCode installation

OpenCode is installed using its official install script:

```bash
curl -fsSL https://opencode.ai/install | bash
```

The script places the binary in `~/.local/bin`, which is added to `PATH` via:

```dockerfile
ENV PATH="/root/.local/bin:${PATH}"
```

## GSD configuration

[GSD (get-shit-done-cc)](https://www.npmjs.com/package/get-shit-done-cc) is a
productivity CLI. It is installed via `npx` during the build and pre-configured
to use OpenCode as its AI backend through a config file placed at
`/root/.config/gsd/config.json`.

## Working directory

The container uses `/workspace` as the default working directory. This is the
standard mount point for the host repository:

```bash
docker run -it -v $(pwd):/workspace opencode-dev
```

## Security considerations

- No cloud credentials or API keys are baked into the image
- API keys must be supplied at runtime via `-e` environment variables
- The image runs as `root` inside the container (acceptable for a local dev tool)
- Trivy vulnerability scanning is integrated into the CI pipeline
