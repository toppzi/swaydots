# swaydots (Fedora + Hyprland)

Simple **Hyprland installer** for **Fedora**.

This repo is made to help new users get a working Hyprland desktop quickly with:

- Hyprland
- Waybar
- Kitty
- Fuzzel
- wlogout
- Wallpaper scripts
- Theme switcher

## Copy-paste install (one line)

Paste this into **Terminal** on Fedora, press **Enter**, type your password when `sudo` asks, then follow the installer prompts.

**If `git` is already installed:**

```bash
git clone https://github.com/toppzi/swaydots.git ~/swaydots && cd ~/swaydots && chmod +x install.sh && ./install.sh
```

**Fresh Fedora (installs `git` first, then runs the installer):**

```bash
sudo dnf install -y git && git clone https://github.com/toppzi/swaydots.git ~/swaydots && cd ~/swaydots && chmod +x install.sh && ./install.sh
```

After it finishes, **reboot** and pick the **Hyprland** session at the login screen.

## Who This Is For

- You are on Fedora (fresh install is fine).
- You want a guided install script.
- You want sane defaults and working keybinds.

## Quick Install (Beginner Friendly)

Open Terminal and run:

```bash
cd ~/Downloads
git clone https://github.com/toppzi/swaydots.git
cd swaydots
chmod +x install.sh
./install.sh
```

That is all you need to start.

## What the Installer Does

`install.sh` is **Hyprland-only** and does this automatically:

1. Installs missing dependencies with `dnf` (safe retry pattern included).
2. Lets you choose login manager:
   - `sddm`
   - `lightdm`
3. Lets you choose keyboard layout:
   - `se`, `us`, `no`, `fi`, `fr`, `dk`, `gb`
4. Sets keyboard layout in `~/.config/hypr/hyprland.conf`.
5. Copies configs to your home:
   - `~/.config/hypr`
   - `~/.config/waybar`
   - `~/.config/kitty`
   - `~/.config/fuzzel`
   - `~/.config/wlogout`
6. Sets wallpaper directory automatically to:
   - `~/Pictures/Wallpapers`
7. Creates that wallpaper folder if it does not exist.
8. Installs and enables one selected login manager.
9. Installs `lgl-system-loadout` (LGL).
10. On first Hyprland login:
    - opens LGL once (if installed), or
    - shows a welcome notification with keybinds.

## Safe DNF Behavior (Built In)

The installer already follows a safer install flow:

1. `dnf makecache --refresh`
2. `dnf install ...`
3. If failed:
   - `dnf clean metadata`
   - `dnf makecache --refresh`
   - retry install once
4. If Hyprland package is still unavailable on Fedora:
   - enable COPR `solopasha/hyprland`
   - refresh + retry

## Default Keybinds (Hyprland)

Important defaults:

- `SUPER + Q` -> kill focused app
- `SUPER + Return` -> open terminal
- `SUPER + B` -> open browser
- `SUPER + E` -> open file manager
- `SUPER + A` -> launcher (fuzzel)
- `SUPER + W` -> wallpaper picker
- `SUPER + Shift + T` -> theme switcher
- `SUPER + Shift + E` -> power menu (wlogout)

Also includes useful media/hardware keys:

- volume up/down/mute
- mic mute
- brightness up/down
- media play/next/prev

## After Install

1. Reboot (recommended) or log out.
2. At login screen, choose **Hyprland** session.
3. Log in.
4. If this is first login, LGL opens once automatically.

## Useful Commands

Run installer again safely:

```bash
cd ~/Downloads/swaydots
./install.sh
```

Dry run (show actions only):

```bash
./install.sh --dry-run
```

Help:

```bash
./install.sh --help
```

## Common Problems

### “Missing hyprland-qtutils” (or error at Hyprland login)

Install the Qt helpers Hyprland expects on Fedora, then log in again:

```bash
sudo dnf install -y hyprland-qtutils
```

The installer now pulls this package automatically on new installs.

If package download fails (librepo/dnf errors), run:

```bash
sudo dnf clean all
sudo dnf makecache --refresh
sudo dnf distro-sync --refresh -y
```

Then run installer again.

## Notes

- This project is focused on **Fedora + Hyprland**.
- The `sway/` folder in this repo is still used for shared scripts/themes, but installer target is Hyprland.
