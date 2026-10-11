#!/usr/bin/env bash
# run.sh <shell-root> <tag> [seconds] [post-start command...]
# Runs the shell in a nested niri window with an isolated HOME and private session bus.
set -u
S="$(cd "$(dirname "$0")" && pwd)"; root="$(realpath "$1")"; tag="$2"; secs="${3:-25}"; shift 3 2>/dev/null || shift $#
T="$S/t/$tag"; rm -rf "$T"; mkdir -p "$T/home/.config/niri" "$T/shots"
cat > "$T/niri.kdl" <<KDL
hotkey-overlay {
    skip-at-startup
}
prefer-no-csd
layout {
    gaps 8
}
binds {
    Mod+Q { close-window; }
}
KDL
mkdir -p "$T/home/.config/inir" "$T/home/.local/state/quickshell/user"
[[ -n "${SEED:-}" ]] && printf '%s' "$SEED" > "$T/home/.config/inir/config.json"
ln -sfn inir "$T/home/.config/illogical-impulse"
echo greeted > "$T/home/.local/state/quickshell/user/first_run.txt"
mkdir -p "$T/home/.local/share/fonts"; cp "$S"/fonts/*.ttf "$T/home/.local/share/fonts/" 2>/dev/null
cat > "$T/inner.sh" <<INNER
#!/usr/bin/env bash
export NIRI_SOCKET WAYLAND_DISPLAY
echo "NIRI_SOCKET=\$NIRI_SOCKET WAYLAND_DISPLAY=\$WAYLAND_DISPLAY" > "$T/env"
exec qs -p "$root" > "$T/qs.log" 2>&1
INNER
chmod +x "$T/inner.sh"
env -u NIRI_SOCKET -u HYPRLAND_INSTANCE_SIGNATURE HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state" XDG_CACHE_HOME="$T/home/.cache" XDG_DATA_HOME="$T/home/.local/share" XDG_CURRENT_DESKTOP=niri \
  dbus-run-session -- niri -c "$T/niri.kdl" -- "$T/inner.sh" > "$T/niri.log" 2>&1 &
npid=$!
for i in $(seq 1 40); do [[ -s "$T/env" ]] && break; sleep 0.25; done
[[ -s "$T/env" ]] || { echo "niri did not start"; tail -5 "$T/niri.log"; kill $npid 2>/dev/null; exit 1; }
set -a; . "$T/env"; set +a
sleep "$secs"
shot() { # shot <name>
  before=$(find "$T/home/Pictures/Screenshots" -name '*.png' 2>/dev/null | wc -l)
  niri msg action screenshot-screen >/dev/null 2>&1
  for i in $(seq 1 20); do [[ $(find "$T/home/Pictures/Screenshots" -name '*.png' 2>/dev/null | wc -l) -gt $before ]] && break; sleep 0.15; done
  f=$(find "$T/home/Pictures/Screenshots" -name '*.png' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
  [[ -f "$f" ]] && magick "$f" -resize 1000x "$T/$1.png" && rm -f "$f"
}
shot shot
n=0
IFS='|' read -ra steps <<< "${STEPS:-}"
for step in "${steps[@]}"; do
  n=$((n+1)); mark=$(wc -l < "$T/qs.log")
  echo "== step $n: $step" >> "$T/steps.log"
  HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state" XDG_CACHE_HOME="$T/home/.cache" timeout 8 qs -p "$root" ipc call $step >> "$T/steps.log" 2>&1
  sleep "${STEPWAIT:-2.5}"
  shot "step$n"
  tail -n +$((mark+1)) "$T/qs.log" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E 'WARN|ERROR|rror' | grep -v 'load icon\|fileview\|File does not exist\|binary could not be found' | cut -c1-330 >> "$T/steps.log"
done
pkill -P $npid 2>/dev/null; kill $npid 2>/dev/null; sleep 0.5; pkill -f "niri -c $T/niri.kdl" 2>/dev/null; pkill -f "qs -p $root" 2>/dev/null
echo "log lines: $(wc -l < "$T/qs.log")  shots: $(ls "$T/home/Pictures/Screenshots" 2>/dev/null | wc -l)"
