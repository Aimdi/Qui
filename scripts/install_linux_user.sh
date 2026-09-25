#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle="${1:-$repo_root/build/linux/x64/release/bundle}"

if [[ ! -x "$bundle/qui" ]]; then
  cat >&2 <<EOF
Qui's Linux bundle was not found at:
  $bundle

Build it first with:
  flutter build linux --release --no-tree-shake-icons

Or pass the bundle directory as the first argument.
EOF
  exit 2
fi

bin_dir="${HOME}/.local/bin"
lib_dir="${HOME}/.local/lib/qui"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
applications_dir="$data_home/applications"
icons_dir="$data_home/icons/hicolor/512x512/apps"
desktop_source="$repo_root/packaging/linux/com.aimdi.qui.desktop"
desktop_target="$applications_dir/com.aimdi.qui.desktop"

mkdir -p "$bin_dir" "$applications_dir" "$icons_dir"
rm -rf "$lib_dir"
mkdir -p "$lib_dir"
cp -a "$bundle/." "$lib_dir/"

cat > "$bin_dir/qui" <<EOF
#!/usr/bin/env sh
exec "$lib_dir/qui" "\$@"
EOF
chmod 0755 "$bin_dir/qui"

install -m 0644 "$desktop_source" "$desktop_target"
python3 - "$desktop_target" "$bin_dir/qui" <<'PY'
from pathlib import Path
import sys

desktop = Path(sys.argv[1])
launcher = sys.argv[2]
text = desktop.read_text()
text = text.replace("Exec=qui", f'Exec="{launcher}"')
text = text.replace("TryExec=qui", f'TryExec={launcher}')
desktop.write_text(text)
PY

install -m 0644 "$repo_root/assets/icon.png" "$icons_dir/com.aimdi.qui.png"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$data_home/icons/hicolor" >/dev/null 2>&1 || true
fi

cat <<EOF
Qui was installed for this user.

Launcher:
  $bin_dir/qui

Desktop entry:
  $desktop_target

If '$bin_dir' is not already on PATH, add it to your shell profile.
EOF
