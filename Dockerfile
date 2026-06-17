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
    python3-dev=3.11.2-1+b1 \
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
    telnet=0.17+2.4-2+deb12u3 \
    && rm -rf /var/lib/apt/lists/*

# Shell usability improvements
RUN echo 'alias ll="ls -lah"' >> /root/.bashrc \
    && echo 'alias cat="batcat --paging=never"' >> /root/.bashrc

# Install Node.js 22 via NodeSource (gsd-pi requires Node >= 22)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs=22.22.0-1nodesource1 \
    && rm -rf /var/lib/apt/lists/*

# Install Java 25 SDK (Temurin) with Debian architecture mapping
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
        amd64) java_arch='x64' ;; \
        arm64) java_arch='aarch64' ;; \
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    java_version='25.0.1_8'; \
    java_pkg_version='25.0.1+8'; \
    curl -fsSL "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-${java_pkg_version}/OpenJDK25U-jdk_${java_arch}_linux_hotspot_${java_version}.tar.gz" -o /tmp/openjdk25.tar.gz; \
    mkdir -p /opt/java; \
    tar -xzf /tmp/openjdk25.tar.gz -C /opt/java; \
    rm -f /tmp/openjdk25.tar.gz; \
    mv /opt/java/jdk-25.0.1+8 /opt/java/openjdk25

ENV JAVA_HOME=/opt/java/openjdk25
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Install Maven 3.9.x (Apache binary, checksum-verified)
RUN set -eux; \
    maven_version='3.9.9'; \
    maven_sha512='a555254d6b53d267965a3404ecb14e53c3827c09c3b94b5678835887ab404556bfaf78dcfe03ba76fa2508649dca8531c74bca4d5846513522404d48e8c4ac8b'; \
    curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${maven_version}/binaries/apache-maven-${maven_version}-bin.tar.gz" -o /tmp/apache-maven.tar.gz; \
    echo "${maven_sha512}  /tmp/apache-maven.tar.gz" | sha512sum -c -; \
    tar -xzf /tmp/apache-maven.tar.gz -C /opt; \
    rm -f /tmp/apache-maven.tar.gz; \
    ln -s "/opt/apache-maven-${maven_version}" /opt/maven

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# Install OpenCode CLI
RUN curl -fsSL https://opencode.ai/install | bash

# Add OpenCode install location to PATH
ENV PATH="/root/.local/bin:${PATH}"

# Install GSD (get-shit-done-cc) and pre-configure for OpenCode + Claude
RUN npx --yes get-shit-done-cc@latest --opencode --global \
    && npx --yes get-shit-done-cc@latest --claude --global

# Install Graphify — AI knowledge graph (PyPI: graphifyy)
# hadolint ignore=DL3013,DL3042
RUN pip install --break-system-packages --no-cache-dir "graphifyy[all]"

# Install Caveman — output token compression for AI agents
RUN curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash

# Install GSD2 (gsd-pi)
RUN npm install -g gsd-pi@3.0.0

# Install Ponytail v4.7.0 — AI agent "lazy senior dev" skill (DietrichGebert/ponytail)
# OpenCode: plugin registered in global opencode.json (README: add to opencode.json with absolute path)
# Claude Code: plugin pre-installed at ~/.claude/plugins/ponytail (README: /plugin install ponytail@ponytail)
RUN git clone --branch v4.7.0 --depth 1 https://github.com/DietrichGebert/ponytail.git /opt/ponytail \
    && mkdir -p /root/.config/opencode \
    && if [ -f /root/.config/opencode/opencode.json ]; then \
           jq '.plugin = ((.plugin // []) + ["/opt/ponytail/.opencode/plugins/ponytail.mjs"])' \
               /root/.config/opencode/opencode.json > /tmp/opencode.json \
           && mv /tmp/opencode.json /root/.config/opencode/opencode.json; \
       else \
           printf '%s\n' '{"$schema":"https://opencode.ai/config.json","plugin":["/opt/ponytail/.opencode/plugins/ponytail.mjs"]}' \
               > /root/.config/opencode/opencode.json; \
       fi \
    && mkdir -p /root/.claude/plugins \
    && cp -r /opt/ponytail /root/.claude/plugins/ponytail

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

CMD ["bash"]
