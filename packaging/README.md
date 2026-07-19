# Qui packaging (Arch / CachyOS)

## Build the package

```bash
# From the repo root
flutter build linux --release
cd packaging
makepkg -f
```

This produces `qui-0.1.0-1-x86_64.pkg.tar.zst`.

## Install

```bash
sudo pacman -U qui-0.1.0-1-x86_64.pkg.tar.zst
```

Then launch **Qui** from the app menu, or run `qui`.

## Uninstall

```bash
sudo pacman -R qui
```
