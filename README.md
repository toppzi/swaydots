# swaydots (Fedora + Hyprland)

Minimal dotfiles installer for a **fresh Fedora install** with a Hyprland-focused setup.

## What You Get

- Hyprland-focused install flow
- Waybar + style picker presets
- Kitty + Fuzzel + wlogout
- Wallpaper picker + randomizer + restore on login
- Theme switcher (Waybar/Kitty/Fuzzel/GTK)
- Helium browser install (COPR) + theme-aware launcher

## Quick Install

If `git` is already installed:

```bash
git clone https://github.com/toppzi/swaydots.git ~/swaydots && cd ~/swaydots && chmod +x install.sh && ./install.sh
```

Fresh Fedora (installs `git` first):

```bash
sudo dnf install -y git && git clone https://github.com/toppzi/swaydots.git ~/swaydots && cd ~/swaydots && chmod +x install.sh && ./install.sh
```

## Installer Flow (`install.sh`)

Current interactive steps:

1. **Step 1/3**: choose login manager (`sddm` / `lightdm`) or skip
2. **Step 2/3**: choose keyboard layout (XKB)
3. **Step 3/3**: install/copy dotfiles

### Keyboard layout improvements

Layout input supports:

- number (menu index)
- layout code (example: `us`, `de`, `gb`)
- language name search (example: `swedish`, `german`, `span`)

Supported layout codes:

`se us gb no fi fr dk de es it pt nl pl cz sk hu ro tr ru ua`

## Browser (Helium)

- Helium COPR is enabled during install: `v8v88v8v88/helium`
- Browser keybind (`SUPER + B`) launches:
  - `~/.config/sway/helium-theme-launch.sh`
- Launcher reads active theme and toggles browser dark/light flags.

## Cursor IDE

- No interactive prompt in installer.
- Installs **only** if you pass:

```bash
./install.sh --with-cursor
```

## Waybar

### Style picker

- Keybind: `SUPER + Shift + G`
- Script: `~/.config/sway/waybar-style-picker.sh`
- Presets: `default`, `restore-last`, `minimal`, `glass`, `macios`, `windows`, `sleek`, `chiclets`, `split`, `mono`, `dense`
- Picker applies layout changes robustly (including mixed session config states).

### Media module

- Configured as `custom/media`
- Script: `~/.config/waybar/mediaplayer.py`
- Hidden automatically when no player is active
- Player controls:
  - left click = play/pause
  - right click = stop
  - scroll = next/previous

## Wallpaper

- Default folder: `~/Pictures/wallpapers`
- Picker: `SUPER + W`
- Random wallpaper: `SUPER + Shift + W`
- Last selected wallpaper restores on login/reload

## Useful Commands

Run installer:

```bash
cd ~/swaydots
./install.sh
```

Dry run:

```bash
./install.sh --dry-run
```

Skip package install:

```bash
./install.sh --no-packages
```

Set keyboard non-interactively:

```bash
./install.sh --keyboard-layout de
./install.sh --keyboard-layout swedish
```

Install Cursor explicitly:

```bash
./install.sh --with-cursor
```

## Common Issues

### `hyprland-qtutils` dependency conflict on Fedora 43

This package may break due to Qt ABI mismatch from mixed repos/COPR.  
Installer does **not** require it in base flow.

### Waybar styles not visibly changing

Use `SUPER + Shift + G`, then switch between strongly different presets (`minimal`, `dense`, `windows`).  
If needed, reload Hyprland:

```bash
hyprctl reload
```

### Wallpaper folder case mismatch from older versions

Use lowercase folder:

```bash
mv ~/Pictures/Wallpapers ~/Pictures/wallpapers
```

## Notes

- Project is now **Hyprland-focused** in installer behavior.
- The `sway/` directory still contains shared scripts used by the setup.
