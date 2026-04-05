#!/usr/bin/env bash
# Install Sway dotfiles (sway, waybar, wlogout, kitty, fuzzel, theme switcher, wallpaper picker).
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1
WALLPAPER_DIR_CLI=""
SKIP_DISPLAY_MANAGER=0
DISPLAY_MANAGER_CLI=""
CHOSEN_DM=""

UI_init() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_R=$'\033[0m'
    UI_DIM=$'\033[2m'
    UI_BLD=$'\033[1m'
    UI_CYN=$'\033[36m'
    UI_GRN=$'\033[32m'
    UI_YLW=$'\033[33m'
    UI_RED=$'\033[31m'
    UI_MAG=$'\033[35m'
  else
    UI_R=; UI_DIM=; UI_BLD=; UI_CYN=; UI_GRN=; UI_YLW=; UI_RED=; UI_MAG=
  fi
}

ui_err() {
  printf '%s✗ %s%s\n' "$UI_RED" "$UI_R" "$*" >&2
}

UI_init

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
  --display-manager NAME
                     When no display manager is installed: install NAME (sddm, lightdm,
                     gdm, or ly). Non-interactive; use with dnf-based installs.
  --skip-display-manager
                     Do not check, prompt, or install a display manager.
  -h, --help         Show this help.

Output uses ANSI colors on a TTY; set NO_COLOR=1 to disable (https://no-color.org/).

After install:
  - Log out and back in (or reboot) so systemd user environment.d picks up WALLPAPER_DIR,
    or run: systemctl --user import-environment WALLPAPER_DIR  (if your session supports it).
  - If a display manager was installed here, reboot (or start that service) so graphical login uses it.
  - Edit ~/.config/sway/config for monitors (output ...) and personal apps ($term, etc.).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) INSTALL_PKGS=0 ;;
    --wallpaper-dir)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing path for --wallpaper-dir"
        exit 1
      fi
      WALLPAPER_DIR_CLI="$2"
      shift
      ;;
    --display-manager)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing name for --display-manager (sddm, lightdm, gdm, ly)"
        exit 1
      fi
      DISPLAY_MANAGER_CLI="${2,,}"
      shift
      ;;
    --skip-display-manager) SKIP_DISPLAY_MANAGER=1 ;;
    -h|--help) usage; exit 0 ;;
    *) ui_err "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

for d in sway waybar wlogout kitty fuzzel; do
  if [[ ! -d "$SCRIPT_DIR/$d" ]]; then
    ui_err "missing directory: $SCRIPT_DIR/$d"
    ui_err "run ./pack.sh on your source machine, or extract a complete archive."
    exit 1
  fi
done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ENV_DIR="$CONFIG/environment.d"
ENV_FILE="$ENV_DIR/99-sway-dotfiles-wallpaper.conf"

ui_banner() {
  local mode="" rule
  rule="$(printf '─%.0s' {1..58})"
  [[ "$DRY_RUN" -eq 1 ]] && mode+="dry-run"
  [[ "$INSTALL_PKGS" -eq 0 ]] && mode+="${mode:+ · }no-packages"
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_CYN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_BLD" "Sway dotfiles installer" "$UI_R" "$UI_CYN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_DIM" "sway · waybar · kitty · fuzzel · wallpaper" "$UI_R" "$UI_CYN" "$UI_R"
  if [[ -n "$mode" ]]; then
    printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_YLW" "$mode" "$UI_R" "$UI_CYN" "$UI_R"
  fi
  printf '%s╰%s╯%s\n' "$UI_CYN" "$rule" "$UI_R"
  printf '\n'
}

ui_section() {
  printf '\n%s▶ %s%s%s\n' "$UI_MAG" "$UI_BLD" "$1" "$UI_R"
  printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
}

ui_info() {
  printf '%s · %s%s\n' "$UI_CYN" "$UI_R" "$*"
}

ui_ok() {
  printf '%s ✓ %s%s\n' "$UI_GRN" "$UI_R" "$*"
}

ui_warn() {
  printf '%s ! %s%s\n' "$UI_YLW" "$UI_R" "$*" >&2
}

ui_footer() {
  local rule
  rule="$(printf '─%.0s' {1..58})"
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_GRN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_BLD" "All set — quick reference" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "Reload Sway: Mod+Shift+c" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "Monitors: ~/.config/sway/config" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "WALLPAPER_DIR: log out/in or import-environment" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_DIM" "Theme (Mod+Shift+t): keep sway/themes from repo" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s╰%s╯%s\n' "$UI_GRN" "$rule" "$UI_R"
  printf '\n'
}

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
    read -r -p "$(printf '%s▶%s Wallpaper directory for picker [ %s%s%s ]: ' "$UI_CYN" "$UI_R" "$UI_DIM" "$default" "$UI_R")" input || true
  fi
  # Non-interactive (piped CI, etc.): use default or pass --wallpaper-dir.
  if [[ -z "${input// }" ]]; then
    normalize_wallpaper_dir ""
  else
    normalize_wallpaper_dir "$input"
  fi
}

ui_banner
WALLPAPER_DIR_RESOLVED="$(resolve_wallpaper_dir)"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s ' "$UI_YLW" "$UI_R"
    printf '%q ' "$@"
    echo
  else
    "$@"
  fi
}

rpm_have() {
  command -v rpm >/dev/null 2>&1 || return 1
  rpm -q "$1" >/dev/null 2>&1
}

any_display_manager_pkg() {
  rpm_have sddm || rpm_have lightdm || rpm_have gdm || rpm_have ly
}

list_installed_display_managers() {
  local parts=()
  rpm_have sddm && parts+=("sddm")
  rpm_have lightdm && parts+=("lightdm")
  rpm_have gdm && parts+=("gdm")
  rpm_have ly && parts+=("ly")
  (IFS=' '; echo "${parts[*]}")
}

normalize_dm_id() {
  case "${1,,}" in
    sddm) echo sddm ;;
    lightdm) echo lightdm ;;
    gdm) echo gdm ;;
    ly) echo ly ;;
    *) return 1 ;;
  esac
}

prompt_display_manager() {
  local choice=""
  while true; do
    printf '\n%s▶ %sDisplay manager%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
    printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
    printf '%s No package found for sddm, lightdm, gdm, or ly.%s\n' "$UI_DIM" "$UI_R"
    printf '%s Pick one to install and enable for graphical login:%s\n\n' "$UI_R" "$UI_R"
    printf '   %s1)%s sddm      %s·%s Wayland / Plasma-style setups\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s2)%s lightdm   %s·%s GTK greeter, lightweight\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s3)%s gdm       %s·%s GNOME display manager\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s4)%s ly        %s·%s TUI (may be missing from Fedora repos)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %sq)%s skip      %s·%s do not install now\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    read -r -p "$(printf '%s▶%s Enter 1–4 or q [q]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    case "$choice" in
      1|sddm) echo sddm; return 0 ;;
      2|lightdm) echo lightdm; return 0 ;;
      3|gdm) echo gdm; return 0 ;;
      4|ly) echo ly; return 0 ;;
      ""|q|Q|skip) return 1 ;;
    esac
    ui_warn "invalid choice — enter 1–4 or q"
  done
}

choose_display_manager_if_needed() {
  CHOSEN_DM=""
  [[ "$SKIP_DISPLAY_MANAGER" -eq 1 ]] && return 0
  if any_display_manager_pkg; then
    ui_ok "display manager already installed ($(list_installed_display_managers))"
    return 0
  fi
  ui_info "no display manager package among: sddm, lightdm, gdm, ly"
  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
      ui_err "--display-manager cannot be used with --no-packages"
      exit 1
    fi
    ui_warn "with --no-packages, install one yourself (e.g. sudo dnf install sddm && sudo systemctl enable sddm)"
    return 0
  fi
  local picked=""
  if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
    if ! picked="$(normalize_dm_id "$DISPLAY_MANAGER_CLI")"; then
      ui_err "invalid --display-manager (use sddm, lightdm, gdm, or ly)"
      exit 1
    fi
    if ! command -v dnf >/dev/null 2>&1; then
      ui_err "--display-manager requires dnf (not found in PATH)"
      exit 1
    fi
    CHOSEN_DM="$picked"
    return 0
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    ui_warn "dnf not found — install a display manager with your package manager and enable its service"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    ui_warn "non-interactive session — skipping display manager (use --display-manager NAME or --skip-display-manager)"
    return 0
  fi
  if picked="$(prompt_display_manager)"; then
    CHOSEN_DM="$picked"
  else
    ui_info "skipping display manager install"
  fi
}

dm_dnf_package_list() {
  case "$1" in
    sddm) echo sddm ;;
    lightdm) echo lightdm lightdm-gtk ;;
    gdm) echo gdm ;;
    ly) echo ly ;;
    *) return 1 ;;
  esac
}

enable_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  local svc="${CHOSEN_DM}.service"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would disable other display managers, enable %s, set-default graphical.target\n' "$UI_YLW" "$UI_R" "$svc"
    return 0
  fi
  run sudo systemctl disable gdm.service sddm.service lightdm.service ly.service 2>/dev/null || true
  run sudo systemctl enable "$svc"
  run sudo systemctl set-default graphical.target 2>/dev/null || true
  ui_ok "enabled $svc (reboot or start the service for graphical login)"
}

install_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  command -v dnf >/dev/null 2>&1 || return 0
  local list
  list="$(dm_dnf_package_list "$CHOSEN_DM")" || return 1
  local -a pkgs=()
  read -r -a pkgs <<< "$list"
  [[ ${#pkgs[@]} -eq 0 ]] && return 1
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${pkgs[*]}"
    enable_chosen_display_manager
    return 0
  fi
  ui_section "Display manager"
  printf '%s · %sInstalling %s%s…%s\n' "$UI_CYN" "$UI_R" "$UI_BLD" "$CHOSEN_DM" "$UI_R"
  run sudo dnf install -y "${pkgs[@]}"
  enable_chosen_display_manager
}

ensure_pavucontrol() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  command -v dnf >/dev/null 2>&1 || return 0
  if rpm_have pavucontrol; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y pavucontrol\n' "$UI_YLW" "$UI_R"
    return 0
  fi
  ui_section "Audio (pavucontrol)"
  printf '%s · %sInstalling PulseAudio / PipeWire volume UI…%s\n' "$UI_CYN" "$UI_R" "$UI_R"
  run sudo dnf install -y pavucontrol
  ui_ok "pavucontrol installed"
}

ensure_lgl_system_loadout() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  command -v dnf >/dev/null 2>&1 || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout\n' "$UI_YLW" "$UI_R"
    printf '%s[dry-run]%s would: sudo dnf install -y lgl-system-loadout\n' "$UI_YLW" "$UI_R"
    return 0
  fi
  ui_section "COPR: lgl-system-loadout"
  printf '%s · %senabling linuxgamerlife/lgl-system-loadout…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout
  printf '%s · %sinstalling lgl-system-loadout…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf install -y lgl-system-loadout
  ui_ok "lgl-system-loadout installed"
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && "$DRY_RUN" -eq 0 ]]; then
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    run mv "$path" "${path}.bak.${ts}"
    ui_ok "backed up → ${path}.bak.${ts}"
  elif [[ -e "$path" ]]; then
    ui_info "would back up: $path"
  fi
}

choose_display_manager_if_needed

ui_section "Paths"
ui_info "config → $CONFIG"
ui_info "wallpapers → $WALLPAPER_DIR_RESOLVED"

if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s · %sInstalling dependencies with dnf (use --no-packages to skip)…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf install -y \
    dnf-plugins-core \
    sway waybar wlogout \
    kitty fuzzel btop \
    grim slurp wl-clipboard \
    python3-gobject gtk3 gettext \
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts \
    || true
  printf '\n%s · optional: pip install --user autotiling · wallpaper picker deps are covered by dnf above%s\n' "$UI_DIM" "$UI_R"
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    ui_warn "dnf not found — install: sway, waybar, wlogout, kitty, fuzzel, btop, grim, slurp, wl-clipboard, python3-gobject, gtk3, gettext, fonts"
  fi
fi

ensure_pavucontrol

ensure_lgl_system_loadout

install_chosen_display_manager

mkdir_p() {
  run mkdir -p "$1"
}

ui_section "Environment"
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
    printf '%s[dry-run]%s would write %s\n' "$UI_YLW" "$UI_R" "$ENV_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '%s[dry-run]%s %s\n' "$UI_YLW" "$UI_R" "$line"
    done <<< "$content"
  else
    printf '%s' "$content" >"$ENV_FILE"
    ui_ok "wrote $ENV_FILE"
  fi
}

write_wallpaper_env

if [[ "$DRY_RUN" -eq 0 ]]; then
  run mkdir -p "$WALLPAPER_DIR_RESOLVED"
fi

ui_section "Dotfiles"
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
  ui_ok "installed sway, waybar, wlogout, kitty, fuzzel → $CONFIG"
fi

# Executable scripts
if [[ "$DRY_RUN" -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    chmod +x "$f"
  done < <(find "$CONFIG/sway" "$CONFIG/waybar" -type f \( -name '*.sh' -o -name 'wallpaper-picker.py' \) -print0 2>/dev/null || true)
  if [[ -f "$CONFIG/sway/theme-switch.sh" ]]; then
    chmod +x "$CONFIG/sway/theme-switch.sh"
  fi
  if [[ -x "$CONFIG/sway/theme-switch.sh" ]] && [[ -d "$CONFIG/sway/themes/palettes" ]] && command -v envsubst >/dev/null 2>&1; then
    "$CONFIG/sway/theme-switch.sh" catppuccin --no-reload 2>/dev/null || true
  elif ! command -v envsubst >/dev/null 2>&1; then
    ui_warn "install gettext (envsubst) for the theme switcher (Mod+Shift+t)"
  elif [[ ! -d "$CONFIG/sway/themes/palettes" ]]; then
    ui_warn "missing ~/.config/sway/themes/ — copy sway/themes from the repo, then: ~/.config/sway/theme-switch.sh catppuccin"
  fi
fi

ui_footer
