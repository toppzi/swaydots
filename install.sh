#!/usr/bin/env bash
# Install Sway dotfiles (Catppuccin-themed sway, waybar, wlogout, kitty, fuzzel, wallpaper picker).
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1
WALLPAPER_DIR_CLI=""

usage() {
  sed -n '1,100p' <<'EOF'
Usage: install.sh [options]

  Copies sway/, waybar/, wlogout/, kitty/, and fuzzel/ from this directory into ~/.config/,
  writes WALLPAPER_DIR for wallpaper scripts (systemd user environment.d),
  sets executable bits on scripts, and optionally installs Fedora packages.

Options:
  --dry-run          Print actions only; do not copy files or write env.
  --no-packages      Skip dnf install (dependencies must be present).
  --wallpaper-dir PATH
                     Set wallpaper folder (non-interactive). Expands ~.
  -h, --help         Show this help.

After install:
  - Log out and back in (or reboot) so systemd user environment.d picks up WALLPAPER_DIR,
    or run: systemctl --user import-environment WALLPAPER_DIR  (if your session supports it).
  - Edit ~/.config/sway/config for monitors (output ...) and personal apps ($term, etc.).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) INSTALL_PKGS=0 ;;
    --wallpaper-dir)
      if [[ -z "${2:-}" ]]; then
        echo "install.sh: missing path for --wallpaper-dir" >&2
        exit 1
      fi
      WALLPAPER_DIR_CLI="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

for d in sway waybar wlogout kitty fuzzel; do
  if [[ ! -d "$SCRIPT_DIR/$d" ]]; then
    echo "Missing directory: $SCRIPT_DIR/$d" >&2
    echo "Run ./pack.sh on your source machine to build this bundle, or extract a complete archive." >&2
    exit 1
  fi
done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ENV_DIR="$CONFIG/environment.d"
ENV_FILE="$ENV_DIR/99-sway-dotfiles-wallpaper.conf"

expand_tilde_path() {
  local p="$1"
  if [[ "$p" == '~' ]]; then
    printf '%s' "$HOME"
  elif [[ "$p" == '~/'* ]]; then
    printf '%s' "${HOME}/${p#~/}"
  else
    printf '%s' "$p"
  fi
}

normalize_wallpaper_dir() {
  local raw="$1"
  local p
  if [[ -z "$raw" ]]; then
    p="${HOME}/Pictures/wallpapers"
  else
    p="$(expand_tilde_path "$raw")"
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p"
  else
    printf '%s' "$p"
  fi
}

resolve_wallpaper_dir() {
  local default="${HOME}/Pictures/wallpapers"
  local input=""
  if [[ -n "$WALLPAPER_DIR_CLI" ]]; then
    normalize_wallpaper_dir "$WALLPAPER_DIR_CLI"
    return
  fi
  if [[ -t 0 ]]; then
    read -r -p "Wallpaper directory for picker & random wallpaper [${default}]: " input || true
  fi
  # Non-interactive (piped CI, etc.): use default or pass --wallpaper-dir.
  if [[ -z "${input// }" ]]; then
    normalize_wallpaper_dir ""
  else
    normalize_wallpaper_dir "$input"
  fi
}

WALLPAPER_DIR_RESOLVED="$(resolve_wallpaper_dir)"

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
echo "Wallpaper directory: $WALLPAPER_DIR_RESOLVED"

if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  echo "Installing packages with dnf (use --no-packages to skip)..."
  run sudo dnf install -y \
    sway waybar wlogout \
    kitty fuzzel \
    grim slurp wl-clipboard \
    python3-gobject gtk3 \
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts \
    || true
  echo "Optional: pip install --user autotiling  |  wallpaper picker needs python3-gobject + gtk3"
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    echo "dnf not found; install sway, waybar, wlogout, kitty, fuzzel, grim, slurp, wl-clipboard, python3-gobject, gtk3, fonts."
  fi
fi

mkdir_p() {
  run mkdir -p "$1"
}

mkdir_p "$CONFIG"
mkdir_p "$ENV_DIR"

if [[ -e "$ENV_FILE" ]]; then
  backup_if_exists "$ENV_FILE"
fi

write_wallpaper_env() {
  local content esc
  esc="$WALLPAPER_DIR_RESOLVED"
  esc="${esc//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  content="# Written by sway-dotfiles install.sh — WALLPAPER_DIR for wallpaper.sh and wallpaper-picker.py
WALLPAPER_DIR=\"$esc\"
"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would write $ENV_FILE:"
    printf '%s' "$content" | sed 's/^/[dry-run] /'
  else
    printf '%s' "$content" >"$ENV_FILE"
    echo "Wrote $ENV_FILE"
  fi
}

write_wallpaper_env

if [[ "$DRY_RUN" -eq 0 ]]; then
  run mkdir -p "$WALLPAPER_DIR_RESOLVED"
fi

for name in sway waybar wlogout kitty fuzzel; do
  dest="$CONFIG/$name"
  if [[ -e "$dest" ]]; then
    backup_if_exists "$dest"
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  run cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
else
  cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
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
echo "If WALLPAPER_DIR is new, log out and back in so desktop apps inherit it, or start a new login session."
