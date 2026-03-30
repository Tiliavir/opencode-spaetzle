FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color

# Enable pipefail for all subsequent RUN commands
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Install system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Development / runtime
    git=1:2.39.5-0+deb12u3 \
    curl=7.88.1-10+deb12u14 \
    ca-certificates=20230311+deb12u1 \
    python3=3.11.2-1+b1 \
    python3-pip=23.0.1+dfsg-1 \
    build-essential=12.9 \
    # Repository navigation tools
    ripgrep=13.0.0-4+b2 \
    fd-find=8.6.0-3 \
    tree=2.1.0-1 \
    universal-ctags=5.9.20210829.0-1 \
    # CLI utilities
    nano=7.2-1+deb12u1 \
    less=590-2.1~deb12u2 \
    jq=1.6-2.1+deb12u1 \
    unzip=6.0-28 \
    procps=2:4.0.2-3 \
    htop=3.2.2-2 \
    bat=0.22.1-4 \
    # Networking tools
    iputils-ping=3:20221126-1+deb12u1 \
    telnet=0.17+2.4-2+deb12u2 \
    && rm -rf /var/lib/apt/lists/*

# Create fd symlink (Debian installs fd as fdfind)
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# Shell usability improvements
RUN echo 'alias ll="ls -lah"' >> /root/.bashrc \
    && echo 'alias cat="batcat --paging=never"' >> /root/.bashrc

# Install Node.js 22 via NodeSource (gsd-pi requires Node >= 22)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs=22.22.0-1nodesource1 \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash

# Add OpenCode install location to PATH
ENV PATH="/root/.local/bin:${PATH}"

# Install GSD (get-shit-done-cc) and pre-configure for OpenCode
RUN npx --yes get-shit-done-cc@latest --opencode --global

# Install GSD2 (gsd-pi)
RUN npm install -g gsd-pi@2.58.0

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

CMD ["bash"]
