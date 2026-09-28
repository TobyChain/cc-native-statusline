#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Isolate config + payload dump from the real ~/.claude
export HOME="$(mktemp -d)"
mkdir -p "$HOME/.claude"

fail=0
check() {  # check <expected-substring> <payload> <label>
  if echo "$2" | python3 statusline.py | grep -q "$1"; then
    echo "PASS: $3"
  else
    echo "FAIL: $3 (expected '$1')"
    fail=1
  fi
}

CTX99='{"total_input_tokens":240000,"total_output_tokens":4000,"context_window_size":262000}'
CTX15='{"total_input_tokens":150000,"total_output_tokens":5000,"context_window_size":1000000}'

check "glm-5.3" \
  "{\"model\":{\"id\":\"glm-5.3\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"context_window\":$CTX15}" \
  "raw id passthrough without config"

printf '{"model_names":{"glm-5.3":"GLM-5.3","swe-2":"SWE-2"}}' > "$HOME/.claude/statusline.json"
check "GLM-5.3" \
  "{\"model\":{\"id\":\"glm-5.3\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"effort\":{\"level\":\"max\"},\"context_window\":$CTX15}" \
  "model name mapping via config"

check "155k/1M 15.5% used" \
  "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"context_window\":$CTX15}" \
  "token format"

check "93.1% used" \
  "{\"model\":{\"id\":\"swe-2-max\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"context_window\":$CTX99}" \
  "crit threshold red"

check "999k/1M" \
  '{"model":{"id":"x"},"workspace":{"current_dir":"/tmp/p"},"context_window":{"total_input_tokens":999000,"total_output_tokens":0,"context_window_size":1000000}}' \
  "no 1000k promotion bug"

check "super-max?" \
  '{"model":{"id":"x"},"workspace":{"current_dir":"/tmp/p"},"effort":{"level":"super-max"},"context_window":{"total_input_tokens":10,"total_output_tokens":0,"context_window_size":1000}}' \
  "unknown effort gets ?"

check "context ?" \
  '{"model":{"id":"x"},"workspace":{"current_dir":"/tmp/p"}}' \
  "missing context fields"

out=$(echo "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/a/b/c/d/e\"},\"context_window\":$CTX15}" \
  | COLUMNS=40 python3 statusline.py)
echo "$out" | grep -q "…/" && echo "PASS: narrow width truncates path" || { echo "FAIL: narrow width truncates path"; fail=1; }
echo "$out" | grep -q "█" && { echo "FAIL: narrow width drops bar"; fail=1; } || echo "PASS: narrow width drops bar"

out=$(echo "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"context_window\":$CTX15}" \
  | NO_COLOR=1 python3 statusline.py)
echo "$out" | grep -q $'\033' && { echo "FAIL: NO_COLOR strips escapes"; fail=1; } || echo "PASS: NO_COLOR strips escapes"

exit $fail
