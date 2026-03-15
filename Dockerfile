FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color

# Install system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Development / runtime
    git \
    curl \
    ca-certificates \
    nodejs \
    npm \
    python3 \
    python3-pip \
    build-essential \
    # Repository navigation tools
    ripgrep \
    fd-find \
    tree \
    universal-ctags \
    # CLI utilities
    nano \
    less \
    jq \
    unzip \
    procps \
    htop \
    bat \
    && rm -rf /var/lib/apt/lists/*

# Create fd symlink (Debian installs fd as fdfind)
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# Shell usability improvements
RUN echo 'alias ll="ls -lah"' >> /root/.bashrc \
    && echo 'alias cat="batcat --paging=never"' >> /root/.bashrc

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash

# Add OpenCode install location to PATH
ENV PATH="/root/.local/bin:${PATH}"

# Install GSD (get-shit-done-cc) and pre-configure for OpenCode
RUN npx --yes get-shit-done-cc@latest

# Pre-configure GSD to use OpenCode as the AI provider
RUN mkdir -p /root/.config/gsd \
    && printf '{\n  "provider": "opencode",\n  "command": "opencode"\n}\n' \
       > /root/.config/gsd/config.json

WORKDIR /workspace

CMD ["bash"]
