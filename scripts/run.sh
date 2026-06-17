#!/usr/bin/env bash
# scripts/run.sh — convenience wrapper for devcon-spaetzle
#
# Automatically detects and mounts host paths (Git config, SSH keys,
# Claude/Copilot auth stores) and forwards GITHUB_TOKEN when present.
#
# Usage:
#   ./scripts/run.sh [flags] [docker run extra flags…] [-- command]
#
# Flags:
#   --recreate    Remove existing container for this workspace and start fresh
#   --version     Show version info
#
# Examples:
#   ./scripts/run.sh
#   ./scripts/run.sh -e ANTHROPIC_API_KEY=sk-...
#   ./scripts/run.sh -- claude
#   ./scripts/run.sh --recreate

set -euo pipefail

IMAGE="${SPAETZLE_IMAGE:-ghcr.io/tiliavir/devcon-spaetzle:claude}"
WORKSPACE="${WORKSPACE:-$(pwd)}"
CONTAINER_USER_HOME="${CONTAINER_USER_HOME:-/root}"
RECREATE=false

# ── helpers ────────────────────────────────────────────────────────────────────

warn()  { echo "[run.sh] WARNING: $*" >&2; }
info()  { echo "[run.sh] $*"; }

# Append a read-only bind mount if the source path exists on the host.
# Usage: maybe_mount <host_path> <container_path>
maybe_mount() {
  local host_path="$1"
  local container_path="$2"
  local mode="${3:-ro}"
  if [ -e "$host_path" ]; then
    MOUNTS+=("-v" "${host_path}:${container_path}:${mode}")
    info "Mounting ${host_path} → ${container_path} (${mode})"
  fi
}

# ── argument parsing ───────────────────────────────────────────────────────────

EXTRA_ARGS=()
CMD_OVERRIDE=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      echo "run.sh wrapper for devcon-spaetzle"
      echo "Image: ${IMAGE}"
      echo "Workspace: ${WORKSPACE}"
      exit 0
      ;;
    --recreate)
      RECREATE=true
      shift
      ;;
    --)
      shift
      CMD_OVERRIDE=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

# ── environment forwarding ─────────────────────────────────────────────────────

ENV_FLAGS=()

# GitHub token — used by GitHub Copilot provider
if [ -n "${GITHUB_TOKEN:-}" ]; then
  ENV_FLAGS+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN}")
  info "Forwarding GITHUB_TOKEN"
elif [ -n "${GH_TOKEN:-}" ]; then
  ENV_FLAGS+=("-e" "GITHUB_TOKEN=${GH_TOKEN}")
  info "Forwarding GH_TOKEN as GITHUB_TOKEN"
else
  warn "No GITHUB_TOKEN / GH_TOKEN set — GitHub Copilot provider will not work without auth"
fi

# Forward other common AI provider keys if present (do not warn when absent)
for var in OPENAI_API_KEY ANTHROPIC_API_KEY; do
  if [ -n "${!var:-}" ]; then
    ENV_FLAGS+=("-e" "${var}=${!var}")
    info "Forwarding ${var}"
  fi
done

# ── mount detection ────────────────────────────────────────────────────────────

MOUNTS=()

# Git identity / config (safe, read-only)
maybe_mount "${HOME}/.gitconfig"     "${CONTAINER_USER_HOME}/.gitconfig"
maybe_mount "${HOME}/.config/git"    "${CONTAINER_USER_HOME}/.config/git"

# SSH keys (read-only)
if [ -d "${HOME}/.ssh" ]; then
  maybe_mount "${HOME}/.ssh" "${CONTAINER_USER_HOME}/.ssh"
else
  warn "No ~/.ssh directory found — SSH-based git remotes will not work"
fi

# GitHub Copilot credential store (read-only)
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
maybe_mount "${XDG_CONFIG_HOME}/github-copilot" "${CONTAINER_USER_HOME}/.config/github-copilot"

# Claude Code credential and plugin store (read-write)
maybe_mount "${HOME}/.claude" "${CONTAINER_USER_HOME}/.claude" "rw"

# ── launch ─────────────────────────────────────────────────────────────────────

LABEL="spaetzle-$(basename "${WORKSPACE}")"

info "Starting devcon-spaetzle container (image: ${IMAGE})"
info "Workspace: ${WORKSPACE}"
info "Container label: ${LABEL}"

info "Checking for newer image..."
if docker pull "${IMAGE}" 2>&1 | grep -q "Downloaded newer"; then
    info "A newer image was pulled."
fi

if [ "${RECREATE}" = "true" ]; then
    if docker container inspect "${LABEL}" &>/dev/null; then
        info "Removing existing container '${LABEL}'..."
        docker rm -f "${LABEL}"
    fi
fi

if docker container inspect "${LABEL}" &>/dev/null; then
  STATUS="$(docker container inspect --format '{{.State.Status}}' "${LABEL}")"
  if [ "${STATUS}" = "running" ]; then
    info "Container '${LABEL}' is already running — reconnecting..."
    warn "Environment variables (tokens/keys) are from the original run and cannot be updated on reconnect."
    exec docker exec -it "${LABEL}" bash
  else
    info "Container '${LABEL}' exists but is stopped — restarting..."
    warn "Environment variables (tokens/keys) are from the original run and cannot be updated on reconnect."
    exec docker start -ai "${LABEL}"
  fi
fi

exec docker run -it \
  --name "${LABEL}" \
  -v "${WORKSPACE}:/workspace:rw" \
  -w /workspace \
  "${MOUNTS[@]+"${MOUNTS[@]}"}" \
  "${ENV_FLAGS[@]+"${ENV_FLAGS[@]}"}" \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" \
  "${IMAGE}" \
  "${CMD_OVERRIDE[@]+"${CMD_OVERRIDE[@]}"}"
