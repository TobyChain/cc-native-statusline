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

# transcript fallback: payload zeros + transcript_path -> real usage from JSONL tail
cat > "$HOME/fake-transcript.jsonl" <<'EOF'
{"message":{"usage":{"input_tokens":10,"cache_read_input_tokens":0,"output_tokens":5}}}
garbage line
{"message":{"usage":{"input_tokens":389,"cache_creation_input_tokens":0,"cache_read_input_tokens":125952,"output_tokens":1074}}}
EOF
check "126k/1M" \
  "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"transcript_path\":\"$HOME/fake-transcript.jsonl\",\"context_window\":{\"context_window_size\":1000000}}" \
  "transcript fallback fills context"

check "context ?" \
  "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"transcript_path\":\"$HOME/missing.jsonl\",\"context_window\":{\"context_window_size\":1000000}}" \
  "unreadable transcript stays ?"

out=$(echo "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/a/very/long/directory/path/here\"},\"context_window\":$CTX15}" \
  | COLUMNS=40 python3 statusline.py)
echo "$out" | grep -q "…/" && echo "PASS: oversized path truncates" || { echo "FAIL: oversized path truncates"; fail=1; }
echo "$out" | grep -q "█" && echo "PASS: bar kept when wrapping" || { echo "FAIL: bar kept when wrapping"; fail=1; }

out=$(echo "{\"model\":{\"id\":\"glm-5.3\"},\"workspace\":{\"current_dir\":\"/tmp/a/reasonably/long/path\"},\"effort\":{\"level\":\"max\"},\"context_window\":$CTX15}" \
  | COLUMNS=60 python3 statusline.py)
[ "$(echo "$out" | wc -l | tr -d ' ')" -ge 2 ] && echo "$out" | grep -q "█" && echo "PASS: overflow wraps to 2nd line, bar kept" \
  || { echo "FAIL: overflow wraps to 2nd line, bar kept"; fail=1; }
echo "$out" | grep -q "effort:" && { echo "FAIL: effort label removed"; fail=1; } || echo "PASS: effort label removed"
echo "$out" | grep -q "max" && echo "PASS: bare effort level shown" || { echo "FAIL: bare effort level shown"; fail=1; }

out=$(echo "{\"model\":{\"id\":\"x\"},\"workspace\":{\"current_dir\":\"/tmp/p\"},\"context_window\":$CTX15}" \
  | NO_COLOR=1 python3 statusline.py)
echo "$out" | grep -q $'\033' && { echo "FAIL: NO_COLOR strips escapes"; fail=1; } || echo "PASS: NO_COLOR strips escapes"

exit $fail
