#!/usr/bin/env python3
"""
Visual wallpaper picker: thumbnail grid from WALLPAPER_DIR, click to apply (swaymsg).
Requires: python3-gobject, gtk3 (Fedora: python3-gobject gtk3).

Thumbnails are cached under $XDG_CACHE_HOME/sway-wallpaper-picker/thumbnails/ so later
opens skip re-decoding huge originals from disk. Set WALLPAPER_PICKER_NO_CACHE=1 to disable.
UI uses Catppuccin colors (GTK CSS); set WALLPAPER_PICKER_THEME=mocha|macchiato|frappe|latte to match your flavor.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
from collections import deque

try:
    import gi

    # Gdk must be pinned before Gtk, or Gdk 4 loads first and Gtk3 import fails on Fedora.
    gi.require_version("Gdk", "3.0")
    gi.require_version("Gtk", "3.0")
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, Pango

    # Some PyGObject builds omit PRIORITY_LOW_IDLE (e.g. certain Python 3.14 packages).
    _THUMB_LOAD_PRIORITY = getattr(
        GLib,
        "PRIORITY_LOW_IDLE",
        getattr(GLib, "PRIORITY_DEFAULT_IDLE", 200),
    )
except (ImportError, ValueError) as e:
    print(f"wallpaper-picker: GTK import failed: {e}", file=sys.stderr)
    print("Install: sudo dnf install python3-gobject gtk3", file=sys.stderr)
    sys.exit(1)

WALLPAPER_DIR = os.environ.get("WALLPAPER_DIR", "/mnt/HDD/Wallpapers")
WALLPAPER_MODE = os.environ.get("WALLPAPER_MODE", "fill")
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "sway"
)
STATE_FILE = os.path.join(STATE_DIR, "last-wallpaper")
EXT = {".jpg", ".jpeg", ".png", ".webp", ".jxl", ".bmp", ".gif"}
THUMB_W, THUMB_H = 280, 170
THUMB_CACHE_VERSION = "1"

# Catppuccin (https://github.com/catppuccin/catppuccin) — window / tile chrome only.
# Set WALLPAPER_PICKER_THEME to mocha | macchiato | frappe | latte (default: mocha).
_CATPPUCCIN: dict[str, dict[str, str]] = {
    "mocha": {
        "base": "#1e1e2e",
        "mantle": "#181825",
        "surface0": "#313244",
        "surface1": "#45475a",
        "surface2": "#585b70",
        "text": "#cdd6f4",
        "subtext1": "#bac2de",
        "overlay1": "#7f849c",
        "accent": "#89b4fa",
        "accent_muted": "#74c7ec",
    },
    "macchiato": {
        "base": "#24273a",
        "mantle": "#1e2030",
        "surface0": "#363a4f",
        "surface1": "#494d64",
        "surface2": "#5b6078",
        "text": "#cad3f5",
        "subtext1": "#b8c0e0",
        "overlay1": "#8087a2",
        "accent": "#8aadf4",
        "accent_muted": "#7dc4e4",
    },
    "frappe": {
        "base": "#303446",
        "mantle": "#292c3c",
        "surface0": "#414559",
        "surface1": "#51576d",
        "surface2": "#626880",
        "text": "#c6d0f5",
        "subtext1": "#b5bfe2",
        "overlay1": "#838ba7",
        "accent": "#8caaee",
        "accent_muted": "#85c1dc",
    },
    "latte": {
        "base": "#eff1f5",
        "mantle": "#e6e9ef",
        "surface0": "#ccd0da",
        "surface1": "#bcc0cc",
        "surface2": "#acb0be",
        "text": "#4c4f69",
        "subtext1": "#5c5f77",
        "overlay1": "#8c8fa1",
        "accent": "#1e66f5",
        "accent_muted": "#209fb5",
    },
}


def _apply_catppuccin_theme() -> None:
    flavor = os.environ.get("WALLPAPER_PICKER_THEME", "mocha").strip().lower()
    c = _CATPPUCCIN.get(flavor, _CATPPUCCIN["mocha"])
    css = f"""
    window {{
      background-color: {c["base"]};
      color: {c["text"]};
    }}
    scrolledwindow {{
      background-color: {c["base"]};
    }}
    flowbox {{
      background-color: {c["base"]};
    }}
    label {{
      color: {c["subtext1"]};
    }}
    button {{
      background-color: {c["surface0"]};
      background-image: none;
      border: 1px solid {c["surface1"]};
      border-radius: 8px;
      padding: 6px;
      box-shadow: none;
    }}
    button:hover {{
      background-color: {c["surface1"]};
      border-color: {c["surface2"]};
    }}
    button:active {{
      background-color: {c["surface2"]};
    }}
    scrollbar {{
      background-color: {c["mantle"]};
      border: none;
    }}
    scrollbar slider {{
      background-color: {c["surface1"]};
      border-radius: 8px;
      min-height: 24px;
      min-width: 12px;
    }}
    scrollbar slider:hover {{
      background-color: {c["surface2"]};
    }}
    """
    provider = Gtk.CssProvider()
    provider.load_from_data(css.encode("utf-8"))
    screen = Gdk.Screen.get_default()
    Gtk.StyleContext.add_provider_for_screen(
        screen,
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )


def _thumb_cache_enabled() -> bool:
    return os.environ.get("WALLPAPER_PICKER_NO_CACHE", "").strip() not in (
        "1",
        "true",
        "yes",
    )


def _thumb_cache_dir() -> str:
    return os.path.join(
        os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
        "sway-wallpaper-picker",
        "thumbnails",
        f"v{THUMB_CACHE_VERSION}-{THUMB_W}x{THUMB_H}",
    )


def _thumb_cache_path(source_path: str, st: os.stat_result) -> str:
    ap = os.path.abspath(source_path)
    try:
        mt = str(st.st_mtime_ns)
    except AttributeError:
        mt = str(int(st.st_mtime))
    key = f"{ap}\0{mt}\0{st.st_size}\0{THUMB_W}\0{THUMB_H}".encode()
    name = hashlib.sha256(key).hexdigest() + ".png"
    return os.path.join(_thumb_cache_dir(), name)


def _write_thumb_cache(pb: GdkPixbuf.Pixbuf, cache_path: str) -> None:
    parent = os.path.dirname(cache_path)
    os.makedirs(parent, mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".png", dir=parent)
    os.close(fd)
    try:
        pb.savev(tmp, "png", [], [])
        os.replace(tmp, cache_path)
    except (GLib.Error, OSError):
        try:
            os.unlink(tmp)
        except OSError:
            pass


def list_images(root: str) -> list[str]:
    out: list[str] = []
    try:
        for dirpath, _, files in os.walk(root):
            for f in files:
                if os.path.splitext(f.lower())[1] in EXT:
                    out.append(os.path.join(dirpath, f))
    except OSError as e:
        print(e, file=sys.stderr)
    return sorted(out)


def save_wallpaper_state(path: str, mode: str) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        f.write(f"{path}\n{mode}\n")


def set_wallpaper(path: str) -> None:
    esc = path.replace("'", "'\\''")
    subprocess.run(["swaymsg", f"output * bg '{esc}' {WALLPAPER_MODE}"], check=False)
    save_wallpaper_state(path, WALLPAPER_MODE)


def load_thumb(path: str) -> GdkPixbuf.Pixbuf | None:
    try:
        st = os.stat(path)
    except OSError:
        return None

    cache_path = _thumb_cache_path(path, st) if _thumb_cache_enabled() else None

    if cache_path and os.path.isfile(cache_path):
        try:
            return GdkPixbuf.Pixbuf.new_from_file(cache_path)
        except GLib.Error:
            try:
                os.unlink(cache_path)
            except OSError:
                pass

    try:
        pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, THUMB_W, THUMB_H, True)
    except GLib.Error:
        return None

    if cache_path is not None:
        try:
            _write_thumb_cache(pb, cache_path)
        except OSError:
            pass

    return pb


# How many thumbnails to decode per main-loop idle slice (HDD-friendly, keeps UI responsive).
THUMB_BATCH = 6


def make_tile(
    path: str,
    on_pick,
    thumb_queue: deque[tuple[Gtk.Image, str]],
) -> Gtk.Widget:
    btn = Gtk.Button()
    btn.set_relief(Gtk.ReliefStyle.NONE)

    vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    img = Gtk.Image()
    # Placeholder until async loader fills in the real thumbnail.
    img.set_from_icon_name("image-x-generic", Gtk.IconSize.DIALOG)
    img.set_size_request(THUMB_W, THUMB_H)

    thumb_queue.append((img, path))

    name = os.path.basename(path)
    if len(name) > 36:
        name = name[:33] + "…"
    lbl = Gtk.Label(label=name)
    lbl.set_max_width_chars(36)
    lbl.set_ellipsize(Pango.EllipsizeMode.END)
    lbl.set_line_wrap(False)

    vbox.pack_start(img, False, False, 0)
    vbox.pack_start(lbl, False, False, 0)
    btn.add(vbox)
    btn.connect("clicked", lambda _b: on_pick(path))
    btn.set_tooltip_text(path)
    return btn


def main() -> None:
    _apply_catppuccin_theme()

    if not os.path.isdir(WALLPAPER_DIR):
        d = Gtk.MessageDialog(
            transient_for=None,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Wallpaper folder not found",
        )
        d.format_secondary_text(WALLPAPER_DIR)
        d.run()
        d.destroy()
        sys.exit(1)

    paths = list_images(WALLPAPER_DIR)
    if not paths:
        d = Gtk.MessageDialog(
            transient_for=None,
            flags=Gtk.DialogFlags.MODAL,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK,
            text="No images in folder",
        )
        d.format_secondary_text(WALLPAPER_DIR)
        d.run()
        d.destroy()
        sys.exit(1)

    def on_pick(path: str) -> None:
        set_wallpaper(path)
        Gtk.main_quit()

    thumb_queue: deque[tuple[Gtk.Image, str]] = deque()
    total = len(paths)

    win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    win.set_title(f"Wallpaper — loading tiles… 0/{total}")
    win.set_default_size(1100, 720)
    win.set_border_width(12)

    scroll = Gtk.ScrolledWindow()
    scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
    scroll.set_min_content_height(600)

    flow = Gtk.FlowBox()
    flow.set_valign(Gtk.Align.START)
    flow.set_max_children_per_line(20)
    flow.set_min_children_per_line(2)
    flow.set_row_spacing(12)
    flow.set_column_spacing(12)
    flow.set_selection_mode(Gtk.SelectionMode.NONE)
    flow.set_homogeneous(False)

    for p in paths:
        flow.add(make_tile(p, on_pick, thumb_queue))

    scroll.add(flow)
    win.add(scroll)

    loaded = 0

    def pump_thumbs() -> bool:
        nonlocal loaded
        for _ in range(THUMB_BATCH):
            if not thumb_queue:
                win.set_title(f"Wallpaper — {WALLPAPER_DIR} ({total})")
                return False
            img, path = thumb_queue.popleft()
            pb = load_thumb(path)
            if pb is not None:
                img.set_from_pixbuf(pb)
            loaded += 1
        win.set_title(f"Wallpaper — loading… {loaded}/{total}")
        return True

    def on_key(_w: Gtk.Widget, ev: Gdk.EventKey) -> bool:
        if ev.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    win.connect("key-press-event", on_key)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()

    GLib.idle_add(pump_thumbs, priority=_THUMB_LOAD_PRIORITY)

    Gtk.main()


if __name__ == "__main__":
    main()
