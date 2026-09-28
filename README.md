# cc-native-statusline

One row above Claude Code's native footer badges:

```
~/my/project · GLM-5.3 · effort:max · 155k/1M 15.5% used ██░░░░░░░░░░░░░░
```

Zero dependencies. Python 3 stdlib only. Works behind custom `ANTHROPIC_BASE_URL`
gateways with non-Claude model ids.

## Install

1. `git clone https://github.com/TobyChain/cc-native-statusline`
2. `cd cc-native-statusline`
3. `./install.sh`
4. Restart Claude Code

Multiple settings files (one per provider/profile)? Pass them:

```bash
./install.sh ~/.claude/settings.<profile>.json
```

Each patched file gets a `.bak` backup. Re-running skips already-patched files.

## Uninstall

```bash
./uninstall.sh [same files]
```

## Segments

| Segment | Color | Behavior |
|---|---|---|
| path | cyan | cwd with `~` abbreviated; truncated from the left on narrow terminals |
| model | blue | prefix match against `model_names`, else raw model id |
| effort | magenta | payload `effort.level` → `$CLAUDE_CODE_EFFORT_LEVEL` → `default`; unknown levels get `?` |
| context | green/yellow/red | `used/max x.x% used` + 16-cell bar; `<60%` green, `<85%` yellow, else red |

Also: `NO_COLOR` disables colors. `$COLUMNS` too small → drop the bar, then
truncate the path. Token counts render as `155k` / `1M` (never `1000k`).

## Configure

Optional `~/.claude/statusline.json`:

```json
{
  "colors":     {"model": "#00d7ff"},
  "bar":        {"width": 24, "chars": "▓░"},
  "thresholds": {"warn": 0.7, "crit": 0.9},
  "effort_label": "⚡",
  "model_names": {"glm-5.3": "GLM-5.3", "swe-2": "SWE-2"}
}
```

Colors: ANSI-16 names (`bright-cyan`, …) or `#rrggbb`. Delete the file to reset.

## Debug

Numbers look wrong? Read `~/.claude/statusline-last.json`. It holds the raw
payload Claude Code sent on the last render. Compare it against what you expect
before touching the script.

## Test

```bash
./test.sh   # 10 checks, runs in an isolated $HOME
```

## 中文速览

1. `git clone https://github.com/TobyChain/cc-native-statusline && cd cc-native-statusline`
2. `./install.sh`（多入口：后面追加各 settings 路径）
3. 重启 Claude Code

配置 `~/.claude/statusline.json`（颜色/bar/阈值/模型名）；排错看
`~/.claude/statusline-last.json` 里的原始 payload。

## License

MIT
