#!/usr/bin/env bash
# Install cc-native-statusline into Claude Code.
# Usage: ./install.sh [extra settings.json paths ...]
#   Extra paths are for multi-entry setups, e.g. ~/.claude/settings.devin.json
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${CC_STATUSLINE_DEST:-$HOME/.claude/statusline.py}"

install -m 755 "$SRC/statusline.py" "$DEST"
echo "script  -> $DEST"

FILES=("$HOME/.claude/settings.json")
[ $# -gt 0 ] && FILES+=("$@")

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "skip    -> $f (not found)"
    continue
  fi
  python3 - "$f" "$DEST" <<'PY'
import json, os, shutil, sys
f, dest = sys.argv[1], sys.argv[2]
d = json.load(open(f))
new = {"type": "command", "command": f"python3 {dest}"}
if d.get("statusLine") == new:
    print(f"skip    -> {f} (already configured)")
    sys.exit()
shutil.copy2(f, f + ".bak")
d["statusLine"] = new
with open(f, "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
print(f"patched -> {f} (backup: {f}.bak)")
PY
done

echo "Done. Restart Claude Code to see the status line."
