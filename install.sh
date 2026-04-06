#!/usr/bin/env bash
# Install Wayland dotfiles (Sway or Hyprland session): waybar, wlogout, kitty, fuzzel, theme switcher, wallpaper picker.
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1
WALLPAPER_DIR_CLI=""
KEYBOARD_LAYOUT_CLI=""
SKIP_DISPLAY_MANAGER=0
DISPLAY_MANAGER_CLI=""
CHOSEN_DM=""
COMPOSITOR_CLI=""
# CHOSEN_SESSION: sway | hyprland (for messaging and optional packages)
CHOSEN_SESSION="sway"
DO_DNF_SWAY=0
DO_DNF_HYPR=0
# Fedora Hyprland from COPR + full walkthrough (netinstall / COPR enable):
URL_FEDORA_HYPR_TUTORIAL="https://discussion.fedoraproject.org/t/tutorial-fedora-43-install-hyprland-from-scratch/168386"
HYPR_FEDORA_COPR_MAIN="solopasha/hyprland"

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
  sed -n '1,135p' <<'EOF'
Usage: install.sh [options]

  Copies sway/, waybar/, wlogout/, kitty/, fuzzel/, and hypr/ (Hyprland starter with Waybar
  exec-once) from this directory into ~/.config/,
  writes WALLPAPER_DIR for wallpaper scripts (systemd user environment.d),
  sets executable bits on scripts, and optionally installs Fedora packages.

  Interactive install (TTY): Step 1 desktop (Hyprland or Sway), Step 2 login manager
  (SDDM, Ly, LightDM, or GDM — chosen unit is enabled as default), Step 3 keyboard (XKB),
  then dependencies/dotfiles, Step 5 LGL system loadout. Non-interactive: use the flags below.

  Shared stack: waybar, wlogout, kitty, fuzzel, grim, slurp, etc.

Options:
  --dry-run          Print actions only; do not copy files or write env.
  --no-packages      Skip dnf install (dependencies must be present).
  --wallpaper-dir PATH
                     Set wallpaper folder (non-interactive). Expands ~.
  --display-manager NAME
                     Set login manager to NAME (sddm, ly, lightdm, gdm). Non-interactive;
                     installs if needed with dnf.
  --skip-display-manager
                     Do not check, prompt, or install a display manager.
  --compositor NAME  Desktop session (sway or hyprland). Non-interactive; installs missing
                     compositor with dnf when combined with package install.
  --keyboard-layout CODE
                     XKB layout for Sway and Hyprland (e.g. us, se, gb, no, de). Use gb for
                     UK English. Non-interactive; default us if omitted in CI.
  -h, --help         Show this help.

Output uses ANSI colors on a TTY; set NO_COLOR=1 to disable (https://no-color.org/).

After install:
  - Log out and back in (or reboot) so systemd user environment.d picks up WALLPAPER_DIR,
    or run: systemctl --user import-environment WALLPAPER_DIR  (if your session supports it).
  - If a display manager was installed here, reboot (or start that service) so graphical login uses it.
  - Sway: edit ~/.config/sway/config for monitors (output ...) and personal apps ($term, etc.).
  - Hyprland: ~/.config/hypr/hyprland.conf is installed when Hyprland is used (Waybar exec-once).
    On Fedora, if hyprland is missing from default repos, the installer may enable COPR
    solopasha/hyprland and retry; see also:
    https://discussion.fedoraproject.org/t/tutorial-fedora-43-install-hyprland-from-scratch/168386
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
        ui_err "missing name for --display-manager (sddm, ly, lightdm, gdm)"
        exit 1
      fi
      DISPLAY_MANAGER_CLI="${2,,}"
      shift
      ;;
    --skip-display-manager) SKIP_DISPLAY_MANAGER=1 ;;
    --compositor)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing name for --compositor (sway or hyprland)"
        exit 1
      fi
      COMPOSITOR_CLI="${2,,}"
      shift
      ;;
    --keyboard-layout)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing code for --keyboard-layout (e.g. us, se, gb, no)"
        exit 1
      fi
      KEYBOARD_LAYOUT_CLI="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) ui_err "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

for d in sway waybar wlogout kitty fuzzel hypr; do
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
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_BLD" "Wayland dotfiles installer" "$UI_R" "$UI_CYN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_DIM" "Sway / Hyprland · waybar · kitty · fuzzel · wallpaper" "$UI_R" "$UI_CYN" "$UI_R"
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
  local rule reload_line monitor_line
  rule="$(printf '─%.0s' {1..58})"
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    reload_line="Reload Hyprland: hyprctl reload"
    monitor_line="Hyprland: ~/.config/hypr/hyprland.conf (your layout)"
  else
    reload_line="Reload Sway: Mod+Shift+c"
    monitor_line="Monitors: ~/.config/sway/config"
  fi
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_GRN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_BLD" "All set — quick reference" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "$reload_line" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "$monitor_line" "$UI_R" "$UI_GRN" "$UI_R"
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

normalize_keyboard_layout_token() {
  local s="${1//[[:space:]]/}"
  printf '%s' "${s,,}"
}

apply_keyboard_layout_aliases() {
  local s
  s="$(normalize_keyboard_layout_token "$1")"
  case "$s" in
    uk) printf '%s' gb ;;
    *) printf '%s' "$s" ;;
  esac
}

validate_xkb_layout_string() {
  [[ "$1" =~ ^[a-zA-Z0-9_,-]+$ ]]
}

prompt_keyboard_layout() {
  local choice="" custom=""
  while true; do
    # All UI on stderr so stdout stays a single line for KEYBOARD_LAYOUT_RESOLVED="$(…)"
    {
      printf '\n%s▶ %sStep 3/5 — Keyboard layout (XKB)%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Each number sets the same layout code for Sway and Hyprland:%s\n' "$UI_R" "$UI_R"
      printf '%s   %s1=us  2=se  3=gb(UK)  4=no  5=dk  6=fi  7=de  8=fr  9=es  o=other code%s\n\n' "$UI_BLD" "$UI_R"
      printf '   %s1)%s us     %s·%s US English (xkb: us)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s2)%s se     %s·%s Swedish (xkb: se)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s3)%s gb     %s·%s UK English (xkb: gb; you can also type %suk%s)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R" "$UI_BLD" "$UI_R"
      printf '   %s4)%s no     %s·%s Norwegian (xkb: no)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s5)%s dk     %s·%s Danish (xkb: dk)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s6)%s fi     %s·%s Finnish (xkb: fi)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s7)%s de     %s·%s German (xkb: de)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s8)%s fr     %s·%s French (xkb: fr)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s9)%s es     %s·%s Spanish (xkb: es)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %so)%s        %s·%s Other — then type xkb code (e.g. pl, nl, ru, ch)\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type 1–9, o, or Enter for us (layout %sus%s) [us]: ' "$UI_CYN" "$UI_R" "$UI_BLD" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-us}" in
      ""|1|us) printf '%s\n' us; return 0 ;;
      2|se) printf '%s\n' se; return 0 ;;
      3|gb|uk) printf '%s\n' gb; return 0 ;;
      4|no) printf '%s\n' no; return 0 ;;
      5|dk) printf '%s\n' dk; return 0 ;;
      6|fi) printf '%s\n' fi; return 0 ;;
      7|de) printf '%s\n' de; return 0 ;;
      8|fr) printf '%s\n' fr; return 0 ;;
      9|es) printf '%s\n' es; return 0 ;;
      o|other)
        read -r -p "$(printf '%s▶%s XKB layout code: ' "$UI_CYN" "$UI_R")" custom || true
        custom="$(apply_keyboard_layout_aliases "$custom")"
        if validate_xkb_layout_string "$custom"; then
          printf '%s\n' "$custom"
          return 0
        fi
        ui_warn "invalid layout — use letters, digits, commas, hyphen (e.g. us,latam)"
        ;;
      *)
        if validate_xkb_layout_string "$choice"; then
          printf '%s\n' "$(apply_keyboard_layout_aliases "$choice")"
          return 0
        fi
        ui_warn "invalid choice — use 1=us … 9=es, o=other, or a valid xkb code (see map above)"
        ;;
    esac
  done
}

resolve_keyboard_layout() {
  local raw="" out=""
  if [[ -n "$KEYBOARD_LAYOUT_CLI" ]]; then
    raw="$(normalize_keyboard_layout_token "$KEYBOARD_LAYOUT_CLI")"
    raw="$(apply_keyboard_layout_aliases "$raw")"
    if ! validate_xkb_layout_string "$raw"; then
      ui_err "invalid --keyboard-layout (use xkb symbols: us, se, gb, no, or combos like us,ru)"
      exit 1
    fi
    printf '%s' "$raw"
    return 0
  fi
  if [[ -t 0 ]]; then
    prompt_keyboard_layout
    return 0
  fi
  ui_warn "non-interactive: using keyboard layout us (pass --keyboard-layout CODE)"
  printf '%s' us
}

ui_banner

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

needs_hypr_dotfiles() {
  [[ "$DO_DNF_HYPR" -eq 1 ]] || rpm_have hyprland
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

normalize_compositor_id() {
  case "${1,,}" in
    sway) echo sway ;;
    hyprland|hypr) echo hyprland ;;
    *) return 1 ;;
  esac
}

# Step 1/5 — Desktop session (order: 1 Hyprland, 2 Sway)
prompt_desktop_choice() {
  local choice=""
  while true; do
    {
      printf '\n%s▶ %sStep 1/5 — Desktop session%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Choose Hyprland or Sway (dotfiles and packages follow this choice):%s\n' "$UI_R" "$UI_R"
      printf '%s   %s1 = hyprland%s  %s·%s dynamic tiling; copies %shypr/%s and Hyprland session packages\n' "$UI_BLD" "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R" "$UI_BLD" "$UI_R"
      printf '%s   %s2 = sway%s       %s·%s i3-like tiling; this repo’s keybinds & theme target Sway\n\n' "$UI_BLD" "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s1)%s hyprland\n' "$UI_CYN" "$UI_R"
      printf '   %s2)%s sway\n' "$UI_CYN" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type %s1%s for hyprland or %s2%s for sway [2]: ' "$UI_CYN" "$UI_R" "$UI_BLD" "$UI_R" "$UI_BLD" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-2}" in
      1|hyprland|hypr) printf '%s\n' hyprland; return 0 ;;
      2|sway) printf '%s\n' sway; return 0 ;;
    esac
    ui_warn "invalid choice — type 1 for hyprland or 2 for sway (see map above)"
  done
}

choose_compositor_if_needed() {
  DO_DNF_SWAY=0
  DO_DNF_HYPR=0
  CHOSEN_SESSION="sway"

  local has_s=0 has_h=0
  if rpm_have sway; then has_s=1; fi
  if rpm_have hyprland; then has_h=1; fi

  # Non-interactive: --compositor
  if [[ -n "$COMPOSITOR_CLI" ]]; then
    if ! CHOSEN_SESSION="$(normalize_compositor_id "$COMPOSITOR_CLI")"; then
      ui_err "invalid --compositor (use sway or hyprland)"
      exit 1
    fi
    if [[ "$INSTALL_PKGS" -eq 0 ]]; then
      if [[ "$CHOSEN_SESSION" == "sway" && "$has_s" -eq 0 ]]; then
        ui_err "sway is not installed; install it first or re-run without --no-packages"
        exit 1
      fi
      if [[ "$CHOSEN_SESSION" == "hyprland" && "$has_h" -eq 0 ]]; then
        ui_err "hyprland is not installed; install it first or re-run without --no-packages"
        exit 1
      fi
    fi
    if [[ "$CHOSEN_SESSION" == "sway" && "$has_s" -eq 0 ]]; then
      DO_DNF_SWAY=1
    fi
    if [[ "$CHOSEN_SESSION" == "hyprland" && "$has_h" -eq 0 ]]; then
      DO_DNF_HYPR=1
    fi
    if [[ "$DO_DNF_SWAY" -eq 1 || "$DO_DNF_HYPR" -eq 1 ]] && ! command -v dnf >/dev/null 2>&1; then
      ui_err "--compositor install path requires dnf (not found in PATH)"
      exit 1
    fi
    return 0
  fi

  # Dry-run: deterministic defaults, no prompts
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$has_s" -eq 1 && "$has_h" -eq 1 ]]; then
      CHOSEN_SESSION=sway
    elif [[ "$has_s" -eq 1 ]]; then
      CHOSEN_SESSION=sway
    elif [[ "$has_h" -eq 1 ]]; then
      CHOSEN_SESSION=hyprland
    else
      CHOSEN_SESSION=sway
      DO_DNF_SWAY=1
    fi
    return 0
  fi

  # Non-interactive (no TTY): pick installed session or default sway + install
  if [[ ! -t 0 ]]; then
    if [[ "$has_s" -eq 1 && "$has_h" -eq 1 ]]; then
      CHOSEN_SESSION=sway
      ui_warn "non-interactive: both Sway and Hyprland installed — using sway (pass --compositor hyprland for Hyprland)"
      return 0
    fi
    if [[ "$has_s" -eq 1 ]]; then
      CHOSEN_SESSION=sway
      return 0
    fi
    if [[ "$has_h" -eq 1 ]]; then
      CHOSEN_SESSION=hyprland
      return 0
    fi
    if [[ "$INSTALL_PKGS" -eq 0 ]]; then
      ui_warn "non-interactive: no compositor installed — install sway or hyprland, or pass --compositor and packages"
      return 0
    fi
    if ! command -v dnf >/dev/null 2>&1; then
      ui_warn "dnf not found — install sway or hyprland with your package manager"
      return 0
    fi
    ui_warn "non-interactive session — defaulting to sway (pass --compositor hyprland if needed)"
    CHOSEN_SESSION=sway
    DO_DNF_SWAY=1
    return 0
  fi

  # Interactive: always ask (Step 1/5)
  local pick=""
  pick="$(prompt_desktop_choice)"
  CHOSEN_SESSION="$pick"
  if [[ "$pick" == "sway" ]]; then
    [[ "$has_s" -eq 0 ]] && DO_DNF_SWAY=1
  else
    [[ "$has_h" -eq 0 ]] && DO_DNF_HYPR=1
  fi

  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if [[ "$pick" == "sway" && "$has_s" -eq 0 ]]; then
      ui_err "Sway is not installed — re-run without --no-packages or install sway first"
      exit 1
    fi
    if [[ "$pick" == "hyprland" && "$has_h" -eq 0 ]]; then
      ui_err "Hyprland is not installed — re-run without --no-packages or install hyprland first"
      exit 1
    fi
    return 0
  fi

  if [[ "$DO_DNF_SWAY" -eq 1 || "$DO_DNF_HYPR" -eq 1 ]] && ! command -v dnf >/dev/null 2>&1; then
    ui_err "dnf is required to install the selected desktop (not found in PATH)"
    exit 1
  fi
}

build_system_pkgs_array() {
  SYSTEM_PKGS=(
    dnf-plugins-core
    waybar wlogout
    kitty fuzzel btop
    grim slurp wl-clipboard
    python3-gobject gtk3 gettext
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts
  )
  # Sway: compositor + lock/idle/wallpaper helpers, wlroots portal, systemd session glue, shared Wayland session bits.
  local -a sway_pkgs=(
    sway
    swaylock
    swayidle
    swaybg
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    mate-polkit
    qt6-qtwayland
    wireplumber
    sway-systemd
  )
  if [[ "$DO_DNF_SWAY" -eq 1 ]]; then
    SYSTEM_PKGS+=("${sway_pkgs[@]}")
  elif [[ "$CHOSEN_SESSION" == "sway" ]]; then
    # Sway RPM already present; still ensure lock, portals, polkit, PipeWire session, etc.
    SYSTEM_PKGS+=("${sway_pkgs[@]:1}")
  fi
  # Hyprland: compositor + Wayland session basics (portals, polkit prompts, Qt on Wayland).
  local -a hypr_pkgs=(
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    mate-polkit
    qt6-qtwayland
    wireplumber
  )
  if [[ "$DO_DNF_HYPR" -eq 1 ]]; then
    SYSTEM_PKGS+=("${hypr_pkgs[@]}")
  elif [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    # Already had Hyprland RPM; still ensure session packages are present.
    SYSTEM_PKGS+=("${hypr_pkgs[@]:1}")
  fi
}

verify_chosen_compositor_installed() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  command -v rpm >/dev/null 2>&1 || return 0
  if [[ "$DO_DNF_SWAY" -eq 1 ]] && ! rpm_have sway; then
    ui_err "sway did not install — check dnf errors above, then: sudo dnf install sway"
    exit 1
  fi
  if [[ "$DO_DNF_HYPR" -eq 1 ]] && ! rpm_have hyprland; then
    ui_err "hyprland did not install — check dnf errors above."
    printf '%s  Fedora: sudo dnf copr enable %s && sudo dnf install hyprland%s\n' "$UI_DIM" "$HYPR_FEDORA_COPR_MAIN" "$UI_R" >&2
    printf '%s  Walkthrough: %s%s\n' "$UI_DIM" "$URL_FEDORA_HYPR_TUTORIAL" "$UI_R" >&2
    exit 1
  fi
}

dnf_install_system_packages() {
  if run sudo dnf install -y "$@"; then
    return 0
  fi
  if [[ "$DO_DNF_HYPR" -eq 1 ]] && rpm -q fedora-release &>/dev/null; then
    ui_warn "dnf failed — Hyprland on Fedora is often packaged via COPR ($HYPR_FEDORA_COPR_MAIN); see $URL_FEDORA_HYPR_TUTORIAL"
    ui_warn "Enabling COPR $HYPR_FEDORA_COPR_MAIN and retrying install…"
    run sudo dnf copr enable -y "$HYPR_FEDORA_COPR_MAIN"
    run sudo dnf install -y "$@"
    return 0
  fi
  ui_err "dnf install failed — see output above"
  return 1
}

# Step 2/5 — Login manager (order: 1 SDDM, 2 Ly, 3 LightDM, 4 GDM)
prompt_display_manager() {
  local choice=""
  while true; do
    {
      printf '\n%s▶ %sStep 2/5 — Login manager (graphical greeter)%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Pick which display manager should be installed (if needed) and set as the active default.%s\n' "$UI_R" "$UI_R"
      if any_display_manager_pkg; then
        printf '%s Installed now: %s%s%s\n' "$UI_DIM" "$UI_BLD" "$(list_installed_display_managers)" "$UI_R"
      else
        printf '%s No sddm / ly / lightdm / gdm detected — one will be installed with dnf.%s\n' "$UI_DIM" "$UI_R"
      fi
      printf '%s   %s1=sddm  2=ly  3=lightdm  4=gdm  q=skip%s\n\n' "$UI_BLD" "$UI_CYN" "$UI_R"
      printf '   %s1)%s sddm      %s·%s Wayland / Plasma-style setups\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s2)%s ly        %s·%s TUI greeter (Fedora: enables fnux/ly COPR if needed)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s3)%s lightdm   %s·%s GTK greeter, lightweight\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s4)%s gdm       %s·%s GNOME display manager\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %sq)%s skip      %s·%s do not change / install a display manager now\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type 1–4 (see map above), Enter for SDDM, or q to skip [1]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-1}" in
      q|skip) return 1 ;;
      1|sddm) printf '%s\n' sddm; return 0 ;;
      2|ly) printf '%s\n' ly; return 0 ;;
      3|lightdm) printf '%s\n' lightdm; return 0 ;;
      4|gdm) printf '%s\n' gdm; return 0 ;;
    esac
    ui_warn "invalid choice — type 1=sddm, 2=ly, 3=lightdm, 4=gdm, Enter=SDDM, or q (see map above)"
  done
}

choose_display_manager_if_needed() {
  CHOSEN_DM=""
  [[ "$SKIP_DISPLAY_MANAGER" -eq 1 ]] && return 0

  if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
    local picked=""
    if ! picked="$(normalize_dm_id "$DISPLAY_MANAGER_CLI")"; then
      ui_err "invalid --display-manager (use sddm, ly, lightdm, or gdm)"
      exit 1
    fi
    CHOSEN_DM="$picked"
    if [[ "$INSTALL_PKGS" -eq 0 ]]; then
      if ! rpm_have "$picked"; then
        ui_err "package for --display-manager $picked is not installed; install it first or re-run without --no-packages"
        exit 1
      fi
    elif ! command -v dnf >/dev/null 2>&1; then
      ui_err "--display-manager install path requires dnf (not found in PATH)"
      exit 1
    fi
    return 0
  fi

  [[ "$DRY_RUN" -eq 1 ]] && return 0

  if [[ ! -t 0 ]]; then
    ui_warn "non-interactive session — skipping display manager (use --display-manager NAME or --skip-display-manager)"
    return 0
  fi

  local picked=""
  if picked="$(prompt_display_manager)"; then
    CHOSEN_DM="$picked"
    if [[ "$INSTALL_PKGS" -eq 0 ]] && ! rpm_have "$picked"; then
      ui_err "$picked is not installed — install it first or re-run without --no-packages"
      exit 1
    fi
    if [[ "$INSTALL_PKGS" -eq 1 ]] && ! command -v dnf >/dev/null 2>&1; then
      if ! rpm_have "$picked"; then
        ui_err "dnf not found — install $picked with your package manager, then re-run"
        exit 1
      fi
      ui_warn "dnf not found — will only enable $picked if the package is already present"
    fi
  else
    ui_info "skipping display manager"
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

ly_postinstall_fix_tty() {
  [[ "$CHOSEN_DM" != "ly" ]] && return 0
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  # Ly uses tty2 by default; agetty on tty2 prevents the greeter from showing.
  if systemctl list-unit-files 'getty@tty2.service' &>/dev/null; then
    run sudo systemctl disable getty@tty2.service 2>/dev/null || true
    ui_ok "Ly: stopped competing login on tty2 (getty@tty2 disabled — reboot to use Ly)"
  fi
}

install_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if rpm_have "$CHOSEN_DM"; then
      ui_section "Display manager"
      printf '%s · %sSetting %s as the active login manager (packages already present)…%s\n' "$UI_CYN" "$UI_R" "$UI_BLD$CHOSEN_DM$UI_R" "$UI_R"
      enable_chosen_display_manager
      ly_postinstall_fix_tty
    fi
    return 0
  fi
  command -v dnf >/dev/null 2>&1 || return 0
  local list
  list="$(dm_dnf_package_list "$CHOSEN_DM")" || return 1
  local -a pkgs=()
  read -r -a pkgs <<< "$list"
  [[ ${#pkgs[@]} -eq 0 ]] && return 1
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${pkgs[*]}"
    if [[ "$CHOSEN_DM" == "ly" ]]; then
      printf '%s[dry-run]%s would enable COPR fnux/ly if ly is missing from repos, then retry install\n' "$UI_YLW" "$UI_R"
      printf '%s[dry-run]%s would: sudo systemctl disable getty@tty2.service (Ly needs tty2)\n' "$UI_YLW" "$UI_R"
    fi
    enable_chosen_display_manager
    return 0
  fi
  ui_section "Display manager"
  printf '%s · %sInstalling %s%s…%s\n' "$UI_CYN" "$UI_R" "$UI_BLD" "$CHOSEN_DM" "$UI_R"
  if [[ "$CHOSEN_DM" == "ly" ]]; then
    if ! run sudo dnf install -y "${pkgs[@]}"; then
      ui_warn "Ly is not in Fedora default repos — enabling COPR fnux/ly, then installing again"
      run sudo dnf copr enable -y fnux/ly
      run sudo dnf install -y "${pkgs[@]}"
    fi
    if ! rpm_have ly; then
      ui_err "Ly still not installed — see dnf output above (COPR: fnux/ly)"
      exit 1
    fi
  else
    run sudo dnf install -y "${pkgs[@]}"
  fi
  enable_chosen_display_manager
  ly_postinstall_fix_tty
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
  ui_section "Step 5/5 — LGL system loadout (COPR)"
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

choose_compositor_if_needed

choose_display_manager_if_needed

KEYBOARD_LAYOUT_RESOLVED="$(resolve_keyboard_layout)"
# One-line token only (wizard UI must go to stderr, not stdout)
KEYBOARD_LAYOUT_RESOLVED="$(printf '%s' "$KEYBOARD_LAYOUT_RESOLVED" | tr -d '\r\n' | sed -n '1p')"
if ! validate_xkb_layout_string "$KEYBOARD_LAYOUT_RESOLVED"; then
  ui_err "invalid keyboard layout after resolve — use --keyboard-layout CODE"
  exit 1
fi
WALLPAPER_DIR_RESOLVED="$(resolve_wallpaper_dir)"

ui_section "Paths"
ui_info "config → $CONFIG"
ui_info "wallpapers → $WALLPAPER_DIR_RESOLVED"
ui_info "keyboard (xkb) → $KEYBOARD_LAYOUT_RESOLVED"
ui_info "compositor → $CHOSEN_SESSION (packages as detected or selected)"

build_system_pkgs_array
if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s · %sInstalling dependencies with dnf (use --no-packages to skip)…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  if ! dnf_install_system_packages "${SYSTEM_PKGS[@]}"; then
    exit 1
  fi
  verify_chosen_compositor_installed
  if [[ "$CHOSEN_SESSION" == "sway" ]] || rpm_have sway; then
    printf '\n%s · optional: pip install --user autotiling · wallpaper picker deps are covered by dnf above%s\n' "$UI_DIM" "$UI_R"
  fi
elif [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 1 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${SYSTEM_PKGS[*]}"
  if [[ "$DO_DNF_HYPR" -eq 1 ]]; then
    printf '%s[dry-run]%s if that failed on Fedora: would enable COPR %s then retry (see %s)\n' "$UI_YLW" "$UI_R" "$HYPR_FEDORA_COPR_MAIN" "$URL_FEDORA_HYPR_TUTORIAL"
  fi
  if [[ "$CHOSEN_SESSION" == "sway" ]] || [[ "$DO_DNF_SWAY" -eq 1 ]]; then
    printf '%s · optional (Sway): pip install --user autotiling%s\n' "$UI_DIM" "$UI_R"
  fi
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    ui_warn "dnf not found — install: sway or hyprland, waybar, wlogout, kitty, fuzzel, btop, grim, slurp, wl-clipboard, python3-gobject, gtk3, gettext, fonts"
  fi
fi

ensure_pavucontrol

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

write_keyboard_layout_configs() {
  local layout="$1"
  local sway_f="$CONFIG/sway/config.d/10-xkb-layout.conf"
  local hypr_f="$CONFIG/hypr/hyprland.conf"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would write %s (xkb_layout %s)\n' "$UI_YLW" "$UI_R" "$sway_f" "$layout"
    if [[ -f "$hypr_f" ]] || needs_hypr_dotfiles; then
      printf '%s[dry-run]%s would set kb_layout = %s in %s\n' "$UI_YLW" "$UI_R" "$layout" "$hypr_f"
    fi
    return 0
  fi
  mkdir_p "$CONFIG/sway/config.d"
  printf '%s\n' \
    '# Written by install.sh — keyboard layout (xkb)' \
    'input type:keyboard {' \
    "    xkb_layout $layout" \
    '    xkb_model pc105' \
    '}' >"$sway_f"
  ui_ok "keyboard layout → $layout ($sway_f)"
  if [[ -f "$hypr_f" ]]; then
    if grep -qE '^[[:space:]]*kb_layout[[:space:]]*=' "$hypr_f"; then
      local tmp
      tmp="$(mktemp "${TMPDIR:-/tmp}/swaydots-hyprkbd.XXXXXX")"
      if awk -v l="$layout" '
        /^[[:space:]]*kb_layout[[:space:]]*=/ {
          print "    kb_layout = " l
          next
        }
        { print }
      ' "$hypr_f" >"$tmp"; then
        mv -f "$tmp" "$hypr_f"
        ui_ok "keyboard layout → $layout ($hypr_f)"
      else
        rm -f "$tmp"
        ui_err "failed to patch kb_layout in $hypr_f"
        exit 1
      fi
    else
      ui_warn "no kb_layout line in $hypr_f — add: input { kb_layout = $layout }"
    fi
  fi
}

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

ui_section "Step 4/5 — Dotfiles"
for name in sway waybar wlogout kitty fuzzel; do
  dest="$CONFIG/$name"
  if [[ -e "$dest" ]]; then
    backup_if_exists "$dest"
  fi
done
if needs_hypr_dotfiles; then
  if [[ -e "$CONFIG/hypr" ]]; then
    backup_if_exists "$CONFIG/hypr"
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  run cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if needs_hypr_dotfiles; then
    run cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
  fi
else
  cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if needs_hypr_dotfiles; then
    cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
    ui_ok "installed sway, waybar, wlogout, kitty, fuzzel, hypr (Hyprland: Waybar exec-once) → $CONFIG"
  else
    ui_ok "installed sway, waybar, wlogout, kitty, fuzzel → $CONFIG"
  fi
fi

write_keyboard_layout_configs "$KEYBOARD_LAYOUT_RESOLVED"

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

ensure_lgl_system_loadout

ui_footer
