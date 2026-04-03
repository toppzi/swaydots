#!/usr/bin/env bash
# Install Sway dotfiles (Catppuccin-themed sway, waybar, wlogout, wallpaper picker).
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1

usage() {
  sed -n '1,80p' <<'EOF'
Usage: install.sh [options]

  Copies sway/, waybar/, and wlogout/ from this directory into ~/.config/,
  sets executable bits on scripts, and optionally installs Fedora packages.

Options:
  --dry-run       Print actions only; do not copy files.
  --no-packages   Skip dnf install (dependencies must be present).
  -h, --help      Show this help.

After install:
  - Edit ~/.config/sway/config for monitors (output ...) and personal apps ($term, etc.).
  - Set WALLPAPER_DIR or ensure ~/Pictures/wallpapers (or your path) matches wallpaper scripts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) INSTALL_PKGS=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

for d in sway waybar wlogout; do
  if [[ ! -d "$SCRIPT_DIR/$d" ]]; then
    echo "Missing directory: $SCRIPT_DIR/$d" >&2
    echo "Run ./pack.sh on your source machine to build this bundle, or extract a complete archive." >&2
    exit 1
  fi
done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %q ' "$@"
    echo
  else
    "$@"
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && "$DRY_RUN" -eq 0 ]]; then
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    run mv "$path" "${path}.bak.${ts}"
    echo "Backed up existing: ${path}.bak.${ts}"
  elif [[ -e "$path" ]]; then
    echo "Would back up: $path"
  fi
}

echo "Target config directory: $CONFIG"

if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  echo "Installing packages with dnf (use --no-packages to skip)..."
  run sudo dnf install -y \
    sway waybar wlogout \
    grim slurp wl-clipboard \
    python3-gobject gtk3 \
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts \
    || true
  echo "Optional: pip install --user autotiling  |  wallpaper picker needs python3-gobject + gtk3"
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    echo "dnf not found; install sway, waybar, wlogout, grim, slurp, wl-clipboard, python3-gobject, gtk3, fonts."
  fi
fi

mkdir_p() {
  run mkdir -p "$1"
}

mkdir_p "$CONFIG"

for name in sway waybar wlogout; do
  dest="$CONFIG/$name"
  if [[ -e "$dest" ]]; then
    backup_if_exists "$dest"
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  run cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
else
  cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
fi

# Executable scripts
if [[ "$DRY_RUN" -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    chmod +x "$f"
  done < <(find "$CONFIG/sway" "$CONFIG/waybar" -type f \( -name '*.sh' -o -name 'wallpaper-picker.py' \) -print0 2>/dev/null || true)
fi

echo
echo "Done. Reload Sway: \$mod+Shift+c"
echo "Review monitor layout: ~/.config/sway/config (output ...) and workspace → output lines."
