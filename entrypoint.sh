#!/usr/bin/env bash
set -euo pipefail

# Merge ponytail plugin defaults when ~/.claude is a host bind mount.
# The image bakes config into /root/.claude, but a bind mount shadows it.

DEFAULTS="/opt/claude-defaults"
CLAUDE="/root/.claude"

if [ -d "$DEFAULTS" ] && [ ! -d "$CLAUDE/plugins/cache/ponytail" ]; then
    mkdir -p "$CLAUDE/plugins"

    for d in plugins/marketplaces/ponytail plugins/cache/ponytail; do
        if [ -d "$DEFAULTS/$d" ] && [ ! -d "$CLAUDE/$d" ]; then
            mkdir -p "$(dirname "$CLAUDE/$d")"
            cp -r "$DEFAULTS/$d" "$CLAUDE/$d"
        fi
    done

    for f in plugins/installed_plugins.json plugins/known_marketplaces.json settings.json; do
        if [ ! -f "$DEFAULTS/$f" ]; then
            continue
        elif [ ! -f "$CLAUDE/$f" ]; then
            mkdir -p "$(dirname "$CLAUDE/$f")"
            cp "$DEFAULTS/$f" "$CLAUDE/$f"
        else
            jq -s '.[0] * .[1]' "$DEFAULTS/$f" "$CLAUDE/$f" > "$CLAUDE/$f.tmp" \
                && mv "$CLAUDE/$f.tmp" "$CLAUDE/$f"
        fi
    done
fi

exec "$@"
