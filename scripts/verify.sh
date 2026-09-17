#!/usr/bin/env bash
set -euo pipefail
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
fvm dart format --output=none --set-exit-if-changed lib test
