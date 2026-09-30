#!/bin/sh
# Install herdr-usage: Claude / Codex / agy usage remaining in statuslines and in herdr.
# Idempotent: safe to re-run after pulling a new version.
#   ./install.sh            install / update
#   ./install.sh --force    also replace an existing Claude Code statusLine
set -eu

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/herdr-usage"
CACHE_DIR="$HOME/.cache/herdr-usage"
OS=$(uname -s)

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
PYTHON=$(command -v python3)

# 1. Script
mkdir -p "$BIN_DIR" "$CACHE_DIR"
install -m 755 "$REPO_DIR/herdr-usage" "$BIN"
say "installed $BIN"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in PATH; add it to your shell profile" ;; esac

# 2. Command statuslines (Claude Code and agy share the same settings.json shape)
# set_statusline <label> <settings.json> <subcommand> <extra json fields>
set_statusline() {
  mkdir -p "$(dirname "$2")"
  "$PYTHON" - "$1" "$2" "$BIN $3" "$4" "$FORCE" <<'EOF'
import json, os, shutil, sys
label, path, command = sys.argv[1:4]
extra, force = json.loads(sys.argv[4]), sys.argv[5] == "1"
wanted = {"type": "command", "command": command, **extra}
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
current = data.get("statusLine")
if current == wanted:
    print(f"==> {label} statusLine already configured")
    sys.exit(0)
if current and "herdr-usage" not in json.dumps(current) and not force:
    print(f"!! {label} already has a custom statusLine; re-run with --force to replace it")
    sys.exit(0)
if os.path.exists(path):
    shutil.copy(path, path + ".bak-herdr-usage")
data["statusLine"] = wanted
with open(path, "w") as f:  # writing in place keeps the file's permissions
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"==> {label} statusLine configured")
EOF
}

if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
  set_statusline "Claude Code" "$HOME/.claude/settings.json" claude-statusline '{"padding": 0}'
fi
if command -v agy >/dev/null 2>&1 || [ -d "$HOME/.gemini/antigravity-cli" ]; then
  set_statusline "agy" "$HOME/.gemini/antigravity-cli/settings.json" agy-statusline '{}'
fi

# 2b. Codex statusline: no custom command support, but it has native limit items
if command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; then
  mkdir -p "$HOME/.codex"
  "$PYTHON" - "$HOME/.codex/config.toml" <<'EOF'
import os, re, shutil, sys
path = sys.argv[1]
line = 'status_line = ["model-with-reasoning", "five-hour-limit", "weekly-limit"]'
text = open(path).read() if os.path.exists(path) else ""
tui = re.search(r"^\[tui\][ \t]*$", text, re.M)
if tui:
    nxt = re.search(r"^\[", text[tui.end():], re.M)
    section = text[tui.end(): tui.end() + nxt.start()] if nxt else text[tui.end():]
    if re.search(r"^status_line\s*=", section, re.M):
        print("==> Codex status_line already set (left as is)")
        sys.exit(0)
    text = text[: tui.end()] + "\n" + line + text[tui.end():]
else:
    text = text.rstrip("\n") + ("\n\n" if text else "") + "[tui]\n" + line + "\n"
if os.path.exists(path):
    shutil.copy(path, path + ".bak-herdr-usage")
with open(path, "w") as f:
    f.write(text)
print("==> Codex status_line configured")
EOF
fi

# 3. herdr sidebar rows + prefix+u popup
if command -v herdr >/dev/null 2>&1; then
  CONF="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"
  mkdir -p "$(dirname "$CONF")"
  touch "$CONF"
  if grep -q '>>> herdr-usage >>>' "$CONF"; then
    # replace the managed block with the current version
    cp "$CONF" "$CONF.bak"
    awk '/# >>> herdr-usage >>>/{skip=1} !skip{print} /# <<< herdr-usage <<</{skip=0}' "$CONF.bak" > "$CONF"
  fi
  if grep -q '^\[ui\.sidebar\.agents\.rows_by_agent\]' "$CONF"; then
    warn "herdr config already has [ui.sidebar.agents.rows_by_agent]; add the rows from herdr.toml manually"
  else
    [ -f "$CONF.bak" ] || cp "$CONF" "$CONF.bak"
    [ -n "$(tail -c1 "$CONF")" ] && echo >> "$CONF"
    sed "s|@BIN@|$BIN|g" "$REPO_DIR/herdr.toml" >> "$CONF"
    say "herdr config updated ($CONF)"
  fi
  herdr server reload-config >/dev/null 2>&1 && say "herdr config reloaded" || true

  # 4. Background refresher for herdr pane tokens
  if [ "$OS" = "Darwin" ]; then
    PLIST="$HOME/Library/LaunchAgents/dev.herdr.usage.plist"
    mkdir -p "$(dirname "$PLIST")"
    sed -e "s|@PYTHON@|$PYTHON|g" -e "s|@BIN@|$BIN|g" -e "s|@HOME@|$HOME|g" \
        -e "s|@PATH@|$BIN_DIR:$(dirname "$(command -v herdr)"):/usr/bin:/bin:/opt/homebrew/bin|g" \
        "$REPO_DIR/service/dev.herdr.usage.plist" > "$PLIST"
    launchctl bootout "gui/$(id -u)/dev.herdr.usage" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    say "launchd agent dev.herdr.usage running"
  elif command -v systemctl >/dev/null 2>&1; then
    UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$UNIT_DIR"
    sed -e "s|@PYTHON@|$PYTHON|g" -e "s|@BIN@|$BIN|g" \
        -e "s|@PATH@|$BIN_DIR:$(dirname "$(command -v herdr)"):/usr/local/bin:/usr/bin:/bin|g" \
        "$REPO_DIR/service/herdr-usage.service" > "$UNIT_DIR/herdr-usage.service"
    systemctl --user daemon-reload
    systemctl --user enable --now herdr-usage.service >/dev/null
    systemctl --user restart herdr-usage.service
    say "systemd user service herdr-usage running"
  else
    warn "no launchd/systemd found; run '$BIN daemon' from your session startup"
  fi
else
  warn "herdr not found; skipping sidebar config and background service (statuslines still work)"
fi

say "done — try: herdr-usage"
