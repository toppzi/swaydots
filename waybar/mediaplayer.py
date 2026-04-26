#!/usr/bin/env python3
import json
import subprocess


def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


status = run(["playerctl", "status"])
title = run(["playerctl", "metadata", "--format", "{{ title }}"])
artist = run(["playerctl", "metadata", "--format", "{{ artist }}"])

if status not in {"Playing", "Paused"}:
    print(json.dumps({"text": "", "class": "hidden", "tooltip": ""}))
    raise SystemExit(0)

icon = "▶" if status == "Paused" else "⏸"
bars = "▮▯▮▯"
meta = " - ".join(x for x in [artist, title] if x).strip()
if not meta:
    meta = "Media"
if len(meta) > 44:
    meta = meta[:41] + "..."

text = f"{bars} │ {icon} {meta}"
print(json.dumps({"text": text, "class": "custom-media", "tooltip": meta}))
