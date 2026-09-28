#!/usr/bin/env bash
# Remove cc-native-statusline from Claude Code.
# Usage: ./uninstall.sh [extra settings.json paths ...]
set -euo pipefail

FILES=("$HOME/.claude/settings.json" "$@")
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  python3 - "$f" <<'PY'
import json, shutil, sys
f = sys.argv[1]
d = json.load(open(f))
if "statusLine" not in d:
    sys.exit()
shutil.copy2(f, f + ".bak")
del d["statusLine"]
with open(f, "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
print("removed statusLine from", f)
PY
done

rm -f "${CC_STATUSLINE_DEST:-$HOME/.claude/statusline.py}"
echo "Done. Restart Claude Code."
