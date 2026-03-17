#!/usr/bin/env bash
# install-helvetia.sh — Build a local wrapper image with company certs
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.sh | bash
#
# Or to install to a custom location:
#   curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.sh | bash -s -- --install-dir /custom/path

set -euo pipefail

SCRIPT_NAME="spaetzle"
INSTALL_DIR="${HOME}/.local/bin"
DEFAULT_IMAGE="ghcr.io/tiliavir/opencode-spaetzle:latest"
WRAPPER_IMAGE="opencode-spaetzle-helvetia:latest"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build a local wrapper image for opencode-spaetzle with company certificates.

OPTIONS:
    --install-dir DIR    Directory to install spaetzle script (default: ~/.local/bin)
    --base-image IMAGE  Base Docker image to wrap (default: ${DEFAULT_IMAGE})
    --image IMAGE       Name for the wrapper image (default: ${WRAPPER_IMAGE})
    -h, --help          Show this help message

EXAMPLES:
    # Default build
    curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.sh | bash

    # Custom image name
    curl -fsSL https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.sh | bash -s -- --image my-company/opencode:latest
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --base-image)
            DEFAULT_IMAGE="$2"
            shift 2
            ;;
        --image)
            WRAPPER_IMAGE="$2"
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

warn()  { echo "[install-helvetia.sh] WARNING: $*" >&2; }
info()  { echo "[install-helvetia.sh] $*"; }
error() { echo "[install-helvetia.sh] ERROR: $*" >&2; exit 1; }

info "Building local wrapper image with company certificates..."
info "Base image: ${DEFAULT_IMAGE}"
info "Wrapper image: ${WRAPPER_IMAGE}"

if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
fi

info "Docker found: $(docker --version)"

TEMP_DOCKERFILE=$(mktemp)
info "Creating temporary Dockerfile..."

cat > "${TEMP_DOCKERFILE}" << 'DOCKERFILE_EOF'
FROM ${BASE_IMAGE}

# Add company certificates (HELVETIA: customize this section)
# Example: Copy CA certificates into the system trust store
# COPY company-certs/*.crt /usr/local/share/ca-certificates/
# RUN update-ca-certificates

# Alternative: Copy certificates to a specific location for applications to use
# COPY company-certs/*.crt /etc/ssl/certs/company-ca.crt

# For Node.js/npm, you might need:
# ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/company-ca.crt

# For curl/wget:
# ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/company-ca.crt

# For Git:
# ENV GIT_SSL_CAINFO=/etc/ssl/certs/company-ca.crt

# ============================================================
# IMPORTANT: Replace the section above with your company's
# certificate installation steps before building!
# ============================================================

# Ensure OpenCode is on PATH
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /workspace

CMD ["bash"]
DOCKERFILE_EOF

info "Building wrapper image..."
docker build \
    --build-arg BASE_IMAGE="${DEFAULT_IMAGE}" \
    -t "${WRAPPER_IMAGE}" \
    -f "${TEMP_DOCKERFILE}" \
    .

rm "${TEMP_DOCKERFILE}"

info "Successfully built ${WRAPPER_IMAGE}"

mkdir -p "${INSTALL_DIR}"
if [ ! -w "${INSTALL_DIR}" ]; then
    error "Cannot write to ${INSTALL_DIR}. Use --install-dir to specify a writable location."
fi

info "Writing spaetzle wrapper to ${INSTALL_DIR}/${SCRIPT_NAME}..."

cat > "${INSTALL_DIR}/${SCRIPT_NAME}" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# spaetzle — Docker wrapper for opencode-spaetzle (helvetia version)
#
# Automatically detects and mounts host paths (Git config, SSH keys,
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

IMAGE="${OPENCODE_IMAGE:-opencode-spaetzle-helvetia:latest}"
WORKSPACE="${WORKSPACE:-$(pwd)}"
CONTAINER_USER_HOME="${CONTAINER_USER_HOME:-/root}"

warn()  { echo "[spaetzle] WARNING: $*" >&2; }
info()  { echo "[spaetzle] $*"; }

maybe_mount() {
    local host_path="$1"
    local container_path="$2"
    local mode="${3:-ro}"
    if [ -e "$host_path" ]; then
        MOUNTS+=("-v" "${host_path}:${container_path}:${mode}")
        info "Mounting ${host_path} → ${container_path} (${mode})"
    fi
}

if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
    echo "spaetzle wrapper for opencode-spaetzle (helvetia)"
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

MOUNTS=()

HOME_DIR="${HOME}"

maybe_mount "${HOME_DIR}/.gitconfig"     "${CONTAINER_USER_HOME}/.gitconfig"
maybe_mount "${HOME_DIR}/.config/git"    "${CONTAINER_USER_HOME}/.config/git"

if [ -d "${HOME_DIR}/.ssh" ]; then
    maybe_mount "${HOME_DIR}/.ssh" "${CONTAINER_USER_HOME}/.ssh"
else
    warn "No ~/.ssh directory found — SSH-based git remotes will not work"
fi

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME_DIR}/.config}"
maybe_mount "${XDG_CONFIG_HOME}/github-copilot" "${CONTAINER_USER_HOME}/.config/github-copilot"
maybe_mount "${XDG_CONFIG_HOME}/npm" "${CONTAINER_USER_HOME}/.config/npm"

if [ -f "${HOME_DIR}/.npmrc" ]; then
    maybe_mount "${HOME_DIR}/.npmrc" "${CONTAINER_USER_HOME}/.npmrc"
fi

if [ -d "${HOME_DIR}/.m2" ]; then
    maybe_mount "${HOME_DIR}/.m2" "${CONTAINER_USER_HOME}/.m2"
fi

XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME_DIR}/.local/share}"
maybe_mount "${XDG_DATA_HOME}/opencode" "${CONTAINER_USER_HOME}/.local/share/opencode"

LABEL="spaetzle-$(basename "${WORKSPACE}")"

info "Starting opencode-spaetzle container (image: ${IMAGE})"
info "Workspace: ${WORKSPACE}"
info "Container label: ${LABEL}"

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

info "Done!"
info ""
info "To customize the certificates, edit the Dockerfile that was used to build"
info "the wrapper image, or rebuild with:"
info "  docker build -t ${WRAPPER_IMAGE} -f /path/to/your/Dockerfile ."
