#!/usr/bin/env bash
set -euo pipefail
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
dart format --set-exit-if-changed lib test
