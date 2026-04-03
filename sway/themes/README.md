# Theme data

- **`palettes/*.env`** — `export` lines with hex colours (no `#`) and `GTK_THEME` per theme. Edit these to tweak a palette or point GTK at a theme name that exists on your system.
- **`tpl/*.tpl`** — `envsubst` templates consumed by `../theme-switch.sh`. Do not edit generated files under `~/.config/` by hand; change templates or palettes and run the switcher again.

Palette keys: `BASE`, `SURFACE0`–`SURFACE2`, `TEXT`, `SUBTEXT0`, `SUBTEXT1`, `OVERLAY0`, `OVERLAY1`, `ACCENT`, `RED`, `GREEN`, `YELLOW`, `PEACH`, `MAUVE`, `MUTE`, `GTK_THEME`.

Kitty full colour schemes live in **`../../kitty/themes/<name>.conf`** (sibling to `sway/` in this repo).
