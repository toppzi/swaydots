# swaydots

Catppuccin-themed [Sway](https://github.com/swaywm/sway) dotfiles for Fedora (and similar setups): window manager, status bar, launcher, terminal, wallpapers, and screenshots.

## What’s included

| Path | Purpose |
|------|---------|
| `sway/` | Main config, Catppuccin window colours, wallpaper scripts + GTK picker, screenshots |
| `waybar/` | Bar layout and style; power module opens `wlogout` |
| `wlogout/` | Layout and style (icons from the system `wlogout` package) |
| `kitty/` | Terminal: Catppuccin Mocha + Noto Sans Mono |
| `fuzzel/` | App launcher: Catppuccin Mocha (blue accent), matches Sway |

Waybar can launch **btop** in Kitty (`kitty -e btop`); the installer installs **btop** when using `dnf`.

## Install

Clone or unpack the repo anywhere (for example `~/Documents/sway-dotfiles`), then:

```bash
cd sway-dotfiles   # or your clone path
chmod +x install.sh pack.sh
./install.sh
```

The script:

- Copies `sway`, `waybar`, `wlogout`, `kitty`, and `fuzzel` into `~/.config/` (existing dirs are backed up with a timestamp).
- On Fedora, runs **`sudo dnf install`** for Sway, Waybar, Kitty, Fuzzel, btop, screenshot/clipboard tools, fonts, and wallpaper-picker dependencies (unless you pass **`--no-packages`**).
- Asks for your **wallpaper directory** (default `~/Pictures/wallpapers`) and writes `WALLPAPER_DIR` to `~/.config/environment.d/99-sway-dotfiles-wallpaper.conf`.
- Creates that wallpaper folder if it does not exist.

### Installer options

```text
./install.sh --dry-run              # print actions only
./install.sh --no-packages          # skip dnf; copy configs only
./install.sh --wallpaper-dir ~/img  # non-interactive wallpaper path (~ expanded)
./install.sh --help
```

After install, **log out and back in** (or reboot) so your session picks up `environment.d` and `WALLPAPER_DIR` for `wallpaper.sh` and `wallpaper-picker.py`.

## After a fresh install

Edit `~/.config/sway/config` for your machine:

- **`output …`** lines for monitors (`swaymsg -t get_outputs`).
- **`$browser`**, **`$filemanager`**, workspace → output bindings if yours differ.
- Optional: **`autotiling`** — `pip install --user autotiling` and ensure `~/.local/bin` is on `PATH` in the Sway session.

Reload Sway: **Mod+Shift+c** (default mod is Super).

## Updating this bundle from your machine

To refresh the repo from your live `~/.config` before committing or archiving:

```bash
./pack.sh
```

`pack.sh` rsyncs `sway`, `waybar`, `wlogout`, and (if present) `kitty` and `fuzzel` from `~/.config` into this directory.

## Requirements

- **Sway** (Wayland compositor).
- Fedora-style **`dnf`** is optional; without it, install the packages yourself (see the installer’s “dnf not found” message or the `dnf install` list in `install.sh`).
