# cc-native-statusline

Single-file, zero-dependency (Python 3 stdlib only) status line for Claude Code.

```
~/my/project · GLM-5.3 · effort:max · 155k/1M 15.5% used ██░░░░░░░░░░░░░░
```

One row above the native footer badges: **path** (cyan) · **model** (blue) ·
**effort** (magenta) · **context** (green → yellow → red + bar). Works behind
custom `ANTHROPIC_BASE_URL` gateways with non-Claude model ids.

## Install

```bash
git clone https://github.com/TobyChain/cc-native-statusline
cd cc-native-statusline
./install.sh                                  # patches ~/.claude/settings.json
./install.sh ~/.claude/settings.<profile>.json  # multi-entry setups
```

Each patched file gets a `.bak` backup. Restart Claude Code afterwards.
Uninstall: `./uninstall.sh [same files]`.

## What each segment does

| Segment | Behavior |
|---|---|
| path | `~`-abbreviated cwd; truncated from the left when the row exceeds `$COLUMNS` |
| model | prefix match against `model_names` config, else raw model id |
| effort | payload `effort.level` → `$CLAUDE_CODE_EFFORT_LEVEL` → `default`; unknown levels get `?` |
| context | `used/max x.x% used` + 16-cell bar; `<60%` green, `<85%` yellow, else red (clamped 0–100%) |

- Token format follows ccstatusline rules: `155k`, promotes to `1M` at 999.5k
  (never shows `1000k`), raw numbers below 1k.
- Honors `NO_COLOR`. Falls back to legacy payload keys (`used_tokens`/`max_tokens`).
- Every render dumps the raw payload to `~/.claude/statusline-last.json` — check
  it first when something displays wrong.

## Config (optional): `~/.claude/statusline.json`

```json
{
  "colors":   {"model": "#00d7ff", "path": "bright-cyan"},
  "bar":      {"width": 24, "chars": "▓░"},
  "thresholds": {"warn": 0.7, "crit": 0.9},
  "effort_label": "⚡",
  "model_names": {"glm-5.3": "GLM-5.3", "swe-2": "SWE-2", "deepseek": "DS"}
}
```

Colors: ANSI-16 names (`bright-black`, …) or `#rrggbb` truecolor.
Delete the file to restore defaults.

## Pitfall: gateway + modelOverrides shrinks your context window

If you route through `ANTHROPIC_BASE_URL` and use `modelOverrides` to map an
alias to a Claude model id (to light up the native effort suffix), Claude Code
starts treating the alias as *recognized*: `CLAUDE_CODE_MAX_CONTEXT_TOKENS`
no longer applies, and 1M-context models fall back to 200k behind a generic
gateway (native 1M only applies on Bedrock/Vertex/Foundry). Keep the alias
unrecognized and declare the window via env instead:

```json
"env": {"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000"}
```

## Test

```bash
./test.sh   # 9 render checks against synthetic payloads
```

## 中文速览

单文件 Python 状态栏（零依赖）：`路径 · 模型 · effort · context(阈值变色+bar)`。
`./install.sh` 自动写入 settings.json（留 .bak 备份），多入口传额外 settings 路径；
`~/.claude/statusline.json` 可覆盖颜色/阈值/bar/模型名；排查看
`~/.claude/statusline-last.json`。代理用户注意：勿用 modelOverrides 映射别名，
否则 `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 失效、窗口退 200k（见上节）。

## License

MIT
