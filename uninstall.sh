#!/bin/sh
# Remove herdr-usage: service, herdr config block, Claude statusLine, script and cache.
set -u

BIN="$HOME/.local/bin/herdr-usage"

if [ "$(uname -s)" = "Darwin" ]; then
  launchctl bootout "gui/$(id -u)/dev.herdr.usage" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/dev.herdr.usage.plist"
elif command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now herdr-usage.service 2>/dev/null
  rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/herdr-usage.service"
  systemctl --user daemon-reload 2>/dev/null
fi

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"
if [ -f "$CONF" ] && grep -q '>>> herdr-usage >>>' "$CONF"; then
  cp "$CONF" "$CONF.bak"
  awk '/# >>> herdr-usage >>>/{skip=1} !skip{print} /# <<< herdr-usage <<</{skip=0}' "$CONF.bak" > "$CONF"
  herdr server reload-config >/dev/null 2>&1
fi

for SETTINGS in "$HOME/.claude/settings.json" "$HOME/.gemini/antigravity-cli/settings.json"; do
  [ -f "$SETTINGS" ] || continue
  python3 - "$SETTINGS" <<'EOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if "herdr-usage" in json.dumps(data.get("statusLine", "")):
    del data["statusLine"]
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
EOF
done

CODEX_CONF="$HOME/.codex/config.toml"
if [ -f "$CODEX_CONF" ]; then
  cp "$CODEX_CONF" "$CODEX_CONF.bak"
  grep -v -x 'status_line = \["model-with-reasoning", "five-hour-limit", "weekly-limit"\]' "$CODEX_CONF.bak" > "$CODEX_CONF"
fi

rm -rf "$BIN" "$HOME/.cache/herdr-usage"
echo "herdr-usage removed"
