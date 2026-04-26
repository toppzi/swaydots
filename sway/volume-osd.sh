#!/usr/bin/env bash
set -euo pipefail

SINK="${WPCTL_SINK:-@DEFAULT_AUDIO_SINK@}"
STEP="${VOLUME_STEP:-5}"
LIMIT="${VOLUME_LIMIT:-1.5}"
ACTION="${1:-}"

case "$ACTION" in
  up)
    wpctl set-volume -l "$LIMIT" "$SINK" "${STEP}%+"
    ;;
  down)
    wpctl set-volume "$SINK" "${STEP}%-"
    ;;
  mute)
    wpctl set-mute "$SINK" toggle
    ;;
  *)
    echo "usage: $0 {up|down|mute}" >&2
    exit 1
    ;;
esac

# Optional visual OSD bar if wob exists.
if ! command -v wob >/dev/null 2>&1; then
  exit 0
fi

status="$(wpctl get-volume "$SINK" 2>/dev/null || true)"
vol="$(awk '{print $2}' <<<"$status")"
muted=0
[[ "$status" == *"[MUTED]"* ]] && muted=1

# Convert 0.00-1.00+ to percent for wob.
pct="$(awk -v v="${vol:-0}" 'BEGIN { p=int((v*100)+0.5); if (p<0) p=0; if (p>150) p=150; print p }')"
if [[ "$muted" -eq 1 ]]; then
  pct=0
fi

printf '%s\n' "$pct" | wob -a bottom -M 150 -t 900 >/dev/null 2>&1 &
