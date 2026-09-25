#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Match verify.yml: analyzer errors/warnings are fatal; legacy informational
# lints (including generated license text) are reported but are not a gate.
fvm flutter analyze --no-fatal-infos --fatal-warnings
fvm flutter test
python3 scripts/validate_arb.py

# Qui intentionally avoids a repository-wide style rewrite when porting XTA
# changes (see verify.yml). Check changed and new Dart files at its 120-column
# width, without rewriting them as a side effect of verification.
base_ref="${VERIFY_BASE_REF:-origin/main}"
git rev-parse --verify "$base_ref" >/dev/null
mapfile -d '' -t files < <(
  { git diff --name-only --diff-filter=ACMR -z "$base_ref" -- '*.dart';
    git ls-files --others --exclude-standard -z -- '*.dart'; } | sort -zu
)
if [ "${#files[@]}" -gt 0 ]; then
  fvm dart format --output=none --set-exit-if-changed --line-length 120 "${files[@]}"
fi
git diff --check
