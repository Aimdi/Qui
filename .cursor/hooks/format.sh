#!/usr/bin/env bash
# Cursor afterFileEdit hook: format only the file that was just edited.
# Reads the edited file path (`file_path`) from the hook's JSON stdin payload
# and runs `dart format` on that single file. Always exits 0 (never blocks).
payload="$(cat)"
file="$(printf '%s' "$payload" | python3 -c 'import sys, json
try:
    print(json.load(sys.stdin).get("file_path", ""))
except Exception:
    pass' 2>/dev/null)"
if [ -n "${file:-}" ] && [ -f "$file" ]; then
  dart format "$file" >/dev/null 2>&1 || true
fi
exit 0
