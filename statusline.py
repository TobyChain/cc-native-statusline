#!/usr/bin/env python3
"""cc-native-statusline — single-file Claude Code statusLine.

Renders one colored row above the native footer badges:
    path(cyan) · model(blue) · effort(magenta) · context(threshold color + bar)

Implementation notes borrowed from community plugins (ccstatusline,
ClaudeStatusLineWidgets):
- formatTokens  — k/M promotion rules (>=999.5k shows as M, never "1000k")
- ContextBar    — [used/max pct] + bar, percentage clamped to 0-100
- ThinkingEffort — payload.effort.level -> env fallback -> "default";
                   unknown levels get a "?" suffix
- width-aware   — honors $COLUMNS: truncates path, then drops the bar
- config file   — ~/.claude/statusline.json overrides all defaults

Debugging: every render dumps the raw payload to ~/.claude/statusline-last.json
"""
import sys, json, os, re

DEFAULTS = {
    "colors": {"path": "cyan", "model": "blue", "effort": "magenta", "sep": "bright-black",
               "ok": "green", "warn": "yellow", "crit": "red"},
    "thresholds": {"warn": 0.60, "crit": 0.85},
    "bar": {"enabled": True, "width": 16, "chars": "█░"},
    "effort_label": "effort:",
    "model_names": {},  # e.g. {"glm-5.3": "GLM-5.3", "swe-2": "SWE-2"}
}
ANSI = {"black": 30, "red": 31, "green": 32, "yellow": 33, "blue": 34,
        "magenta": 35, "cyan": 36, "white": 37,
        "bright-black": 90, "bright-red": 91, "bright-green": 92,
        "bright-yellow": 93, "bright-blue": 94, "bright-magenta": 95,
        "bright-cyan": 96, "bright-white": 97}
RESET = "" if os.environ.get("NO_COLOR") else "\033[0m"


def deep_merge(base, over):
    for k, v in over.items():
        base[k] = {**base[k], **v} if isinstance(v, dict) and isinstance(base.get(k), dict) else v
    return base


def load_cfg():
    cfg = json.loads(json.dumps(DEFAULTS))  # deep copy
    try:
        with open(os.path.expanduser("~/.claude/statusline.json")) as f:
            deep_merge(cfg, json.load(f))
    except Exception:
        pass
    return cfg


def colorize(name, no_color):
    if no_color:
        return ""
    if name in ANSI:
        return f"\033[{ANSI[name]}m"
    if re.fullmatch(r"#[0-9a-fA-F]{6}", name or ""):
        h = name.lstrip("#")
        return f"\033[38;2;{int(h[0:2],16)};{int(h[2:4],16)};{int(h[4:6],16)}m"
    return ""


def fmt_tokens(n):
    """>=999.5k promotes to M (1 decimal, trailing zeros stripped); >=1k rounded k; else raw."""
    n = int(n)
    if n >= 999_500:
        return f"{n/1e6:.1f}".rstrip("0").rstrip(".") + "M"
    if n >= 1000:
        return f"{round(n/1000)}k"
    return str(n)


def vis_len(s):
    return len(re.sub(r"\033\[[0-9;]*m", "", s))


def truncate_path(p, keep=2):
    parts = p.split("/")
    if len(parts) <= keep + 1:
        return p
    return "…/" + "/".join(parts[-(keep + 1):])


def main():
    no_color = bool(os.environ.get("NO_COLOR"))
    cfg = load_cfg()
    col = lambda k: colorize(cfg["colors"][k], no_color)

    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}
    try:
        with open(os.path.expanduser("~/.claude/statusline-last.json"), "w") as f:
            json.dump(d, f)
    except Exception:
        pass

    # ---- path ----
    home = os.path.expanduser("~")
    path = ((d.get("workspace") or {}).get("current_dir") or "?").replace(home, "~")

    # ---- model (prefix match -> display name, fallback raw id) ----
    mid = ((d.get("model") or {}).get("display_name")
           or (d.get("model") or {}).get("id") or "?").strip()
    low = mid.lower()
    name = next((v for k, v in cfg["model_names"].items() if low.startswith(k)), mid)

    # ---- effort (payload -> env -> default; unknown gets "?") ----
    e = (d.get("effort") or {}).get("level")
    if not isinstance(e, str):
        e = os.environ.get("CLAUDE_CODE_EFFORT_LEVEL") or "default"
    e = e.strip().lower()
    if e not in ("low", "medium", "high", "xhigh", "max", "default", "auto"):
        e += "?"

    # ---- context: used/max pct + bar, clamped 0-100 ----
    cw = d.get("context_window") or {}
    mx = cw.get("context_window_size") or cw.get("max_tokens") or 0
    u = ((cw.get("total_input_tokens") or 0) + (cw.get("total_output_tokens") or 0)) \
        or cw.get("used_tokens") or 0
    if mx and u:
        pct = min(1.0, max(0.0, u / mx))
        ckey = "ok" if pct < cfg["thresholds"]["warn"] else \
               "warn" if pct < cfg["thresholds"]["crit"] else "crit"
        ctx = f"{col(ckey)}{fmt_tokens(u)}/{fmt_tokens(mx)} {pct:.1%} used{RESET}"
        if cfg["bar"]["enabled"]:
            w = cfg["bar"]["width"]
            full, empty = cfg["bar"]["chars"]
            filled = round(pct * w)
            ctx += f" {col(ckey)}{full*filled}{empty*(w-filled)}{RESET}"
    else:
        ctx = f"{col('warn')}context ?{RESET}"

    sep = f"{col('sep')} · {RESET}"
    line = (f"{col('path')}{path}{RESET}{sep}{col('model')}{name}{RESET}"
            f"{sep}{col('effort')}{cfg['effort_label']}{e}{RESET}{sep}{ctx}")

    # ---- width-aware: truncate path, then drop the bar ----
    cols = int(os.environ.get("COLUMNS") or 0)
    if cols and vis_len(line) > cols:
        line = line.replace(path, truncate_path(path), 1)
    if cols and vis_len(line) > cols and cfg["bar"]["enabled"]:
        line = re.sub(r" \033\[[0-9;]*m[█░]+\033\[0m", "", line)
    sys.stdout.write(line + "\n")


if __name__ == "__main__":
    main()
