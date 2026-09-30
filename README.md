# herdr-usage

CodexBar-style "usage remaining" for AI coding CLIs, in the terminal:

- **Claude Code**: 5h / weekly limits in its statusline (via `statusLine` JSON `rate_limits`)
- **Codex**: 5h / weekly limits from `~/.codex/sessions/**/*.jsonl`
- **Antigravity (`agy`)**: Gemini / 3rd-party quota buckets from agy's `/statusline` JSON
- **herdr**: a `$usage` token under each claude/codex/agy agent in the sidebar, and a `prefix+u` popup

No credentials are read; everything comes from data the CLIs already hand to their statuslines or write to their own logs.

## Install (macOS / Linux)

```sh
git clone <repo-url> ~/.herdr-usage && ~/.herdr-usage/install.sh
```

Then, once inside `agy`:

```
/statusline ~/.local/bin/herdr-usage agy-statusline
```

The installer is idempotent (re-run it after `git pull` to update) and only configures what it finds:

| Piece | Where |
|---|---|
| script | `~/.local/bin/herdr-usage` |
| Claude Code statusline | `~/.claude/settings.json` → `statusLine` (existing custom one kept unless `--force`) |
| Codex statusline | `~/.codex/config.toml` → `[tui] status_line` with native `model-with-reasoning`, `five-hour-limit`, `weekly-limit` (kept if already set) |
| herdr sidebar + popup | managed block in `~/.config/herdr/config.toml` |
| background refresher (only with herdr) | macOS: launchd `dev.herdr.usage` · Linux: systemd user unit `herdr-usage` |

Requires `python3` (preinstalled on macOS and most Linux distros).

## Usage

```sh
herdr-usage            # summary with bars
herdr-usage watch      # live summary (what the herdr popup runs)
herdr-usage push       # push sidebar tokens to herdr once
```

## Uninstall

```sh
~/.herdr-usage/uninstall.sh
```
