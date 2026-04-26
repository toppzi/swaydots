# swaydots (Fedora + Hyprland / Sway)

Simple guided installer for **Hyprland or Sway** on **Fedora**.

This repo helps you get a working Wayland desktop quickly with:

- Hyprland or Sway (you choose)
- Waybar
- Kitty
- Fuzzel
- wlogout
- Wallpaper scripts/picker
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

After it finishes, **reboot** and pick the session you installed (**Hyprland** or **Sway**) at the login screen.

## Who This Is For

- You are on Fedora (fresh install is fine).
- You want a guided install script.
- You want sane defaults and working keybinds.
- You want one setup that supports both Sway and Hyprland.

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

`install.sh` does this automatically:

1. Installs missing dependencies with `dnf` (safe retry pattern included).
2. Lets you choose login manager:
   - `sddm`
   - `lightdm`
3. Lets you choose compositor/session:
   - `hyprland`
   - `sway`
4. Lets you choose keyboard layout:
   - `se`, `us`, `no`, `fi`, `fr`, `dk`, `gb`
5. Sets keyboard layout in the installed config(s).
6. Copies configs to your home:
   - `~/.config/hypr`
   - `~/.config/waybar`
   - `~/.config/kitty`
   - `~/.config/fuzzel`
   - `~/.config/wlogout`
7. Sets wallpaper directory automatically to:
   - `~/Pictures/wallpapers`
8. Creates that wallpaper folder if it does not exist.
9. Installs and enables one selected login manager (unless skipped).
10. Installs Helium browser (Fedora COPR: `v8v88v8v88/helium`).
11. Adds `linutil` alias in `~/.bashrc` and `~/.zshrc`:
    - `linutil` -> `curl -fsSL https://christitus.com/linux | sh`
12. Optional prompts:
    - LGL (`lgl-system-loadout`) — default **No**
    - Cursor IDE from official RPM URL — default **No**
13. On first Hyprland login:
   - opens LGL once **only if** you installed it (end prompt, `--with-lgl`, or manual `dnf install`), or
   - shows a welcome notification with keybinds.

### Wallpaper support

Wallpaper scripts are shared and now work in both sessions:

- **Sway** uses `swaymsg output * bg ...`
- **Hyprland** uses `swaybg` backend
- `SUPER + W` (picker) and `SUPER + Shift + W` (random) work in both

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

The installer also enables Helium COPR before package install:

- `v8v88v8v88/helium`

## Default Keybinds

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
2. At login screen, choose the installed session (**Hyprland** or **Sway**).
3. Log in.
4. If this is first login and LGL is installed, it may open once; otherwise you get a short welcome notification.

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

Optional **LGL** (only if you want it — may hit Qt conflicts):

```bash
./install.sh --with-lgl
```

Install **Cursor** without prompt:

```bash
./install.sh --with-cursor
```

Skip Cursor prompt:

```bash
./install.sh --skip-cursor
```

Choose compositor non-interactively:

```bash
./install.sh --compositor hyprland
./install.sh --compositor sway
```

## Common Problems

### “Missing hyprland-qtutils” (or error at Hyprland login)

Install the Qt helpers Hyprland expects on Fedora, then log in again:

```bash
sudo dnf install -y hyprland-qtutils
```

The installer tries this package as an optional step when it is safe to do so; if install fails, use the command above.

### Wallpaper folder mismatch (`Wallpapers` vs `wallpapers`)

Current default is:

```bash
~/Pictures/wallpapers
```

If you still have an old uppercase folder from earlier versions, migrate once:

```bash
mv ~/Pictures/Wallpapers ~/Pictures/wallpapers
```

### `lgl-system-loadout` fails — “conflicting requests” / Qt6 (`libQt6Core`)

**LGL** (linuxgamerlife COPR) and **Hyprland** (solopasha COPR) often want **different Qt6** versions. The installer **skips LGL by default** so you should not see this during a normal `./install.sh`.

**If you choose LGL in the end prompt (or use `--with-lgl`) and `dnf` conflicts:**

- **You do not need LGL** for Hyprland. Use the dotfiles install without it.
- Installer now auto-skips known `hyprland-qt-support` conflict cases to avoid breaking the run.
- Optional: align packages, then retry:

```bash
sudo dnf upgrade --refresh
sudo dnf install lgl-system-loadout
```

If it still conflicts, wait for COPR rebuilds or skip LGL entirely.

If package download fails (librepo/dnf errors), run:

```bash
sudo dnf clean all
sudo dnf makecache --refresh
sudo dnf distro-sync --refresh -y
```

Then run installer again.

## Thanks

**Thank you** to the [LinuxGamerLife **LGL System Loadout**](https://github.com/linuxgamerlife/lgl-system-loadout) project. It is a graphical Fedora setup wizard that helps you pick software for gaming, content creation, development, and more—without living in the terminal. This dotfiles installer only offers **optional** integration with their `lgl-system-loadout` package; the app, packaging, and roadmap are theirs. We are glad it exists and that it is shared under the MIT license.

## Notes

- This project is focused on **Fedora + Wayland (Hyprland/Sway)**.
- The `sway/` folder contains shared scripts/themes used by both sessions.
