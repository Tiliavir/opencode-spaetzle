#!/usr/bin/env bash
# install.sh — Install spaetzle wrapper script for opencode-spaetzle
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash
#
# Or to install to a custom location:
#   curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash -s -- --install-dir /custom/path

set -euo pipefail

SCRIPT_NAME="spaetzle"
INSTALL_DIR="${HOME}/.local/bin"
DEFAULT_IMAGE="ghcr.io/tiliavir/opencode-spaetzle:latest"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install spaetzle wrapper script for opencode-spaetzle Docker container.

OPTIONS:
    --install-dir DIR    Directory to install spaetzle script (default: ~/.local/bin)
    --image IMAGE       Docker image to use (default: ${DEFAULT_IMAGE})
    -h, --help          Show this help message

EXAMPLES:
    # Default install
    curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash

    # Custom install directory
    curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash -s -- --install-dir /usr/local/bin

    # Custom Docker image
    curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.sh | bash -s -- --image my-registry/opencode-spaetzle:dev
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --image)
            DEFAULT_IMAGE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

warn()  { echo "[install.sh] WARNING: $*" >&2; }
info()  { echo "[install.sh] $*"; }
error() { echo "[install.sh] ERROR: $*" >&2; exit 1; }

info "Installing spaetzle wrapper script..."

if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
fi

info "Docker found: $(docker --version)"

CONTAINER_USER_HOME="/root"
HOME_DIR="${HOME}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME_DIR}/.local/share}"

escape_for_double_quotes() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\`/\\\`}"
    printf '%s' "$value"
}

STATIC_MOUNT_LINES=()
STATIC_MOUNT_INFO_LINES=()

add_static_mount() {
    local host_path="$1"
    local container_path="$2"
    local mode="${3:-ro}"

    if [ -e "$host_path" ]; then
        local escaped_host
        local escaped_container
        escaped_host="$(escape_for_double_quotes "$host_path")"
        escaped_container="$(escape_for_double_quotes "$container_path")"
        STATIC_MOUNT_LINES+=("    \"-v\" \"${escaped_host}:${escaped_container}:${mode}\"")
        STATIC_MOUNT_INFO_LINES+=("info \"Mounting ${escaped_host} → ${escaped_container} (${mode})\"")
    fi
}

add_static_mount "${HOME_DIR}/.gitconfig" "${CONTAINER_USER_HOME}/.gitconfig"
add_static_mount "${HOME_DIR}/.config/git" "${CONTAINER_USER_HOME}/.config/git"

if [ -d "${HOME_DIR}/.ssh" ]; then
    add_static_mount "${HOME_DIR}/.ssh" "${CONTAINER_USER_HOME}/.ssh"
else
    warn "No ~/.ssh directory found — SSH-based git remotes will not work"
fi

add_static_mount "${XDG_CONFIG_HOME}/github-copilot" "${CONTAINER_USER_HOME}/.config/github-copilot"
add_static_mount "${XDG_CONFIG_HOME}/npm" "${CONTAINER_USER_HOME}/.config/npm"
add_static_mount "${HOME_DIR}/.npmrc" "${CONTAINER_USER_HOME}/.npmrc"
add_static_mount "${HOME_DIR}/.m2" "${CONTAINER_USER_HOME}/.m2"
add_static_mount "${XDG_DATA_HOME}/opencode" "${CONTAINER_USER_HOME}/.local/share/opencode"

if [ "${#STATIC_MOUNT_LINES[@]}" -eq 0 ]; then
    warn "No optional host mounts detected at install time"
fi

STATIC_MOUNTS_BLOCK="# No optional mounts detected during installation"
if [ "${#STATIC_MOUNT_LINES[@]}" -gt 0 ]; then
    STATIC_MOUNTS_BLOCK="$(printf '%s\n' "${STATIC_MOUNT_LINES[@]}")"
fi

STATIC_MOUNT_INFO_BLOCK="# No optional mounts configured"
if [ "${#STATIC_MOUNT_INFO_LINES[@]}" -gt 0 ]; then
    STATIC_MOUNT_INFO_BLOCK="$(printf '%s\n' "${STATIC_MOUNT_INFO_LINES[@]}")"
fi

mkdir -p "${INSTALL_DIR}"
if [ ! -w "${INSTALL_DIR}" ]; then
    error "Cannot write to ${INSTALL_DIR}. Use --install-dir to specify a writable location."
fi

info "Writing spaetzle wrapper to ${INSTALL_DIR}/${SCRIPT_NAME}..."

wrapper_template="$(cat << 'WRAPPER_EOF'
#!/usr/bin/env bash
# spaetzle — Docker wrapper for opencode-spaetzle
#
# Uses host paths detected during installation (Git config, SSH keys,
# npmrc, Maven settings) and forwards API tokens when present.
#
# Usage:
#   spaetzle [docker run extra flags…] [-- command]
#
# Examples:
#   spaetzle
#   spaetzle -e OPENAI_API_KEY=sk-...
#   spaetzle -- opencode
#   spaetzle --version

set -euo pipefail

IMAGE="${OPENCODE_IMAGE:-ghcr.io/tiliavir/opencode-spaetzle:latest}"
WORKSPACE="${WORKSPACE:-$(pwd)}"

warn()  { echo "[spaetzle] WARNING: $*" >&2; }
info()  { echo "[spaetzle] $*"; }

if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "spaetzle wrapper for opencode-spaetzle"
    echo "Image: ${IMAGE}"
    echo "Workspace: ${WORKSPACE}"
    exit 0
fi

EXTRA_ARGS=()
CMD_OVERRIDE=()
while [[ $# -gt 0 ]]; do
    case "$1" in
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

ENV_FLAGS=()

if [ -n "${GITHUB_TOKEN:-}" ]; then
    ENV_FLAGS+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN}")
    info "Forwarding GITHUB_TOKEN"
elif [ -n "${GH_TOKEN:-}" ]; then
    ENV_FLAGS+=("-e" "GITHUB_TOKEN=${GH_TOKEN}")
    info "Forwarding GH_TOKEN as GITHUB_TOKEN"
else
    warn "No GITHUB_TOKEN / GH_TOKEN set — GitHub Copilot provider will not work without auth"
fi

for var in OPENAI_API_KEY ANTHROPIC_API_KEY; do
    if [ -n "${!var:-}" ]; then
        ENV_FLAGS+=("-e" "${var}=${!var}")
        info "Forwarding ${var}"
    fi
done

MOUNTS=(
__STATIC_MOUNTS__
)

__STATIC_MOUNT_INFO__

LABEL="spaetzle-$(basename "${WORKSPACE}")"

info "Starting opencode-spaetzle container (image: ${IMAGE})"
info "Workspace: ${WORKSPACE}"
info "Container label: ${LABEL}"

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
WRAPPER_EOF
)"

wrapper_content="$wrapper_template"
wrapper_content="${wrapper_content/__STATIC_MOUNTS__/${STATIC_MOUNTS_BLOCK}}"
wrapper_content="${wrapper_content/__STATIC_MOUNT_INFO__/${STATIC_MOUNT_INFO_BLOCK}}"

printf '%s\n' "$wrapper_content" > "${INSTALL_DIR}/${SCRIPT_NAME}"

chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"

info "Successfully installed spaetzle to ${INSTALL_DIR}/${SCRIPT_NAME}"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
    warn "${INSTALL_DIR} is not in your PATH"
    info "Add this to your shell profile to use 'spaetzle' from anywhere:"
    if [ "${INSTALL_DIR}" = "${HOME}/.local/bin" ]; then
        info "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
    else
        info "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
    fi
fi

info "Done! Run 'spaetzle' to start the container."
