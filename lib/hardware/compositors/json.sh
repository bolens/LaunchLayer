# shellcheck shell=bash
# lib/hardware/compositors/json.sh

[[ -n "${LAUNCHLAYER_COMPOSITORS_JSON_LOADED:-}" ]] && return 0
LAUNCHLAYER_COMPOSITORS_JSON_LOADED=1

# parse_json_focused_monitor — Extract "width height refresh name" from compositor JSON.
parse_json_focused_monitor() {
	command -v python3 >/dev/null 2>&1 || return 1
	python3 -c '
import json, sys

def focused(m):
    for key in ("focused", "is_focused", "IsFocused"):
        val = m.get(key)
        if val in (True, "true", "yes", 1):
            return True
    return False

def dims(m):
    logical = m.get("logical") or {}
    mode = m.get("current_mode") or m.get("mode") or {}
    w = m.get("width") or logical.get("width") or mode.get("width")
    h = m.get("height") or logical.get("height") or mode.get("height")
    r = m.get("refreshRate") or m.get("refresh") or mode.get("refresh")
    if r is not None:
        r = float(r)
        if r > 1000:
            r /= 1000
    name = m.get("name") or m.get("identifier") or ""
    return w, h, r, name

data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get("outputs", data.get("monitors", []))
if not isinstance(items, list):
    items = [data]
for m in items:
    if not focused(m):
        continue
    w, h, r, name = dims(m)
    if w and h:
        rate = str(int(r)) if r else ""
        print(f"{w} {h} {rate} {name}".rstrip())
        break
' 2>/dev/null
}

# parse_json_focused_vrr — Print 1 when the focused monitor has VRR/adaptive sync on.
parse_json_focused_vrr() {
	command -v python3 >/dev/null 2>&1 || return 1
	python3 -c '
import json, sys

def focused(m):
    for key in ("focused", "is_focused", "IsFocused"):
        val = m.get(key)
        if val in (True, "true", "yes", 1):
            return True
    return False

def vrr_on(m):
    for key in ("vrr", "vrr_enabled", "adaptive_sync", "adaptiveSync"):
        val = m.get(key)
        if val in (True, "true", "yes", 1, "enabled", "on"):
            return True
    return False

data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get("outputs", data.get("monitors", []))
if not isinstance(items, list):
    items = [data]
for m in items:
    if focused(m) and vrr_on(m):
        print(1)
        break
' 2>/dev/null | grep -q 1
}
