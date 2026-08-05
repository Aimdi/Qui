#!/usr/bin/env bash
set -euo pipefail
fvm install && fvm use
fvm flutter pub get
dart run flutter_launcher_icons
dart run dart_pubspec_licenses:generate
dart run intl_utils:generate
dart run flutter_iconpicker:generate_packs --packs material
