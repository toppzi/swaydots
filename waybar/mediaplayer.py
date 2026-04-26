#!/usr/bin/env python3
import json
import subprocess


def run_playerctl(*args):
    try:
        out = subprocess.check_output(["playerctl", *args], stderr=subprocess.DEVNULL)
        return out.decode("utf-8").strip()
    except Exception:
        return ""


def main():
    status = run_playerctl("status")
    if status not in {"Playing", "Paused"}:
        print(json.dumps({"text": "", "class": "hidden", "alt": "hidden", "tooltip": ""}))
        return

    artist = run_playerctl("metadata", "artist")
    title = run_playerctl("metadata", "title")
    player = run_playerctl("metadata", "playerName")

    icon = "▶" if status == "Playing" else "⏸"
    bars = "▮▯▮▯" if status == "Playing" else "▯▯▯▯"

    parts = []
    if artist:
        parts.append(artist)
    if title:
        parts.append(title)
    track = " - ".join(parts) if parts else "Unknown"
    text = f"│ {bars} {icon} {track}"

    payload = {
        "text": text,
        "alt": status.lower(),
        "class": status.lower(),
        "tooltip": f"{player or 'playerctl'}\n{track}\n{status}",
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
