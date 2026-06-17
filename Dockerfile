FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color

# Enable pipefail for all subsequent RUN commands
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Install system packages
# hadolint ignore=DL3008
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
    # CLI utilities
    nano=7.2-1+deb12u1 \
    less=590-2.1~deb12u2 \
    jq=1.6-2.1+deb12u1 \
    unzip=6.0-28 \
    procps=2:4.0.2-3 \
    bat=0.22.1-4 \
    && rm -rf /var/lib/apt/lists/*

# Shell usability improvements
RUN echo 'alias ll="ls -lah"' >> /root/.bashrc \
    && echo 'alias cat="batcat --paging=never"' >> /root/.bashrc

# Install Node.js 22 via NodeSource (GSD requires Node/npx)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs=22.22.0-1nodesource1 \
    && rm -rf /var/lib/apt/lists/*

# Add ~/.local/bin to PATH (used by Claude Code CLI)
ENV PATH="/root/.local/bin:${PATH}"

# Install GSD (get-shit-done-cc) and pre-configure for Claude
RUN npx --yes get-shit-done-cc@latest --claude --global

# Install Graphify — AI knowledge graph (PyPI: graphifyy)
# hadolint ignore=DL3013,DL3042
RUN pip install --break-system-packages --no-cache-dir "graphifyy[all]"

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install ponytail plugin for Claude Code
RUN git clone --depth 1 \
      https://github.com/DietrichGebert/ponytail.git \
      /root/.claude/plugins/marketplaces/ponytail \
    && PONYTAIL_VER=$(jq -r '.version' /root/.claude/plugins/marketplaces/ponytail/.claude-plugin/plugin.json) \
    && PONYTAIL_SHA=$(git -C /root/.claude/plugins/marketplaces/ponytail rev-parse HEAD) \
    && mkdir -p "/root/.claude/plugins/cache/ponytail/ponytail/${PONYTAIL_VER}" \
    && cp -r /root/.claude/plugins/marketplaces/ponytail/. \
       "/root/.claude/plugins/cache/ponytail/ponytail/${PONYTAIL_VER}/" \
    && jq -n --arg ver "$PONYTAIL_VER" --arg sha "$PONYTAIL_SHA" \
       '{"version":2,"plugins":{"ponytail@ponytail":[{"scope":"user","installPath":("/root/.claude/plugins/cache/ponytail/ponytail/"+$ver),"version":$ver,"gitCommitSha":$sha}]}}' \
       > /root/.claude/plugins/installed_plugins.json \
    && jq -n '{"ponytail":{"source":{"source":"github","repo":"DietrichGebert/ponytail"},"installLocation":"/root/.claude/plugins/marketplaces/ponytail"}}' \
       > /root/.claude/plugins/known_marketplaces.json \
    && jq -n '{"extraKnownMarketplaces":{"ponytail":{"source":{"source":"github","repo":"DietrichGebert/ponytail"}}},"enabledPlugins":{"ponytail@ponytail":true}}' \
       > /root/.claude/settings.json

WORKDIR /workspace

CMD ["bash"]
