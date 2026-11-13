#!/usr/bin/env bash
# Phantomat × Caelestia — switch between Caelestia mode and Infinite mode.
#
#   phantomat-mode.sh infinite   hide bar + border, open the canvas
#   phantomat-mode.sh caelestia  close the canvas (windows re-tile), restore bar + border
#   phantomat-mode.sh restore    login safety net: restore bar + border if a
#                                previous session ended while in Infinite mode
#
# The bar/border state is saved before hiding and restored exactly, so the
# switch never ends up inverted. Docs: vault → Phantomat - Escritorio Infinito.
set -euo pipefail

shell_json="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/phantomat"
saved="$state_dir/caelestia-chrome.json"
mkdir -p "$state_dir"

notify() { notify-send -a "Phantomat" -t 1500 "$1" "$2" 2>/dev/null || true; }

# Edit shell.json keeping its exact formatting (indent 4, no trailing newline).
# hide: save current bar.persistent / border.thickness, then hide both.
# show: put the saved values back and forget them.
chrome() {
  python3 - "$shell_json" "$saved" "$1" <<'PY'
import json, os, sys
shell_json, saved, mode = sys.argv[1:]
data = json.load(open(shell_json))

# shell.json keys changed in Infinite mode → value they take there.
#   bar / border: no bar, no frame.
#   dashboard / utilities / osd: no panels popping up when the pointer touches
#   a screen edge (top, bottom-right, right) — they got in the way of the map.
HIDDEN = {
    "bar.persistent": False,
    "bar.showOnHover": False,
    "border.thickness": 0,
}
# dashboard / utilities / osd panels are no longer hidden here: the plugin's
# chrome_animation hides the caelestia-drawers layer only while the map is
# open (spatialoverview.lua), so at 100% they work as usual.
MISSING = "__missing__"  # key was not in shell.json: remove it again on restore
OLD = {"persistent": "bar.persistent", "showOnHover": "bar.showOnHover", "thickness": "border.thickness"}

def get(path):
    node = data
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            return MISSING
        node = node[part]
    return node

def put(path, value):
    *parents, leaf = path.split(".")
    if value == MISSING:
        chain, node = [data], data
        for part in parents:
            if not isinstance(node.get(part), dict):
                return
            node = node[part]
            chain.append(node)
        node.pop(leaf, None)
        # drop sections that only existed to hold the key we added
        for parent, part in zip(reversed(chain[:-1]), reversed(parents)):
            if parent[part] == {}:
                del parent[part]
        return
    node = data
    for part in parents:
        node = node.setdefault(part, {})
    node[leaf] = value

def load_saved():
    try:
        s = json.load(open(saved))
    except (OSError, ValueError):
        return None
    # state written by the first version of this script
    return {OLD.get(k, k): (MISSING if v is None and k == "showOnHover" else v) for k, v in s.items()}

if mode == "hide":
    s = load_saved() or {}
    for path in [p for p in s if p not in HIDDEN]:  # no longer managed: give it back
        put(path, s.pop(path))
    for path, value in HIDDEN.items():
        if path not in s:  # save the real value once, never a hidden one
            s[path] = get(path)
        put(path, value)
    json.dump(s, open(saved, "w"))
else:
    s = load_saved()
    if s is None:
        sys.exit(0)
    for path, value in s.items():
        put(path, value)
    os.remove(saved)

tmp = shell_json + ".phantomat-tmp"
open(tmp, "w").write(json.dumps(data, indent=4, ensure_ascii=False))
os.replace(tmp, shell_json)
PY
}

overview() { hyprctl dispatch "hl.plugin.spatialoverview.overview(\"$1 all\")" >/dev/null; }

# Special workspaces (music, todo, ...) don't work on the canvas. In Infinite
# mode their windows live on the canvas; back in Caelestia mode they return to
# their special workspace. Record: $specials_file = {address: "special:name"}.
specials_file="$state_dir/specials.json"
specials() {
  python3 - "$specials_file" "$@" <<'PY'
import json, os, subprocess, sys
path, action, *args = sys.argv[1:]

def hypr(*a):
    return subprocess.run(["hyprctl", *a], capture_output=True, text=True).stdout

def dispatch(expr):
    hypr("dispatch", expr)

def move(addr, ws):
    dispatch(f'hl.dsp.window.move({{ workspace = "{ws}", follow = false, window = "address:{addr}" }})')

def load():
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return {}

def save(rec):
    if rec:
        json.dump(rec, open(path, "w"))
    elif os.path.exists(path):
        os.remove(path)

active = json.loads(hypr("activeworkspace", "-j"))["name"]
clients = json.loads(hypr("clients", "-j"))
alive = {c["address"]: c for c in clients}
rec = load()

def option(name):
    out = hypr("getoption", name)
    return out.split("\n")[0].split(":", 1)[1].strip() if ":" in out else ""

def place_in_ring(addr):
    """Same rule as the plugin's canvas.open_filled (branch caelestia-h): the
    window fills the screen (minus gaps_out and border) in the first free
    screen-sized slot of a fixed ring around the canvas origin: centre,
    right, up, left, down, diagonals, next ring."""
    import math
    mon = json.loads(hypr("monitors", "-j"))[0]
    scale = mon["scale"]
    w, h = mon["width"] / scale, mon["height"] / scale
    r = mon["reserved"]  # left, top, right, bottom
    gaps = [int(float(x)) for x in option("general:gaps_out").replace("css gap data:", "").split()] or [0]
    gt, gr, gb, gl = (gaps * 4)[:4] if len(gaps) == 1 else (gaps + gaps)[:4]
    border = int(option("general:border_size").split()[-1] or 0)
    gap = int(option("plugin:spatialoverview:canvas:placement_gap").split()[-1] or 40)
    ax = mon["x"] + r[0] + gl + border
    ay = mon["y"] + r[1] + gt + border
    aw = w - r[0] - r[2] - gl - gr - 2 * border
    ah = h - r[1] - r[3] - gt - gb - 2 * border
    sx, sy = aw + gap, ah + gap

    now = json.loads(hypr("clients", "-j"))
    others = [c for c in now if c["address"] != addr and c["workspace"]["name"] == active and c["mapped"]]
    def free(x, y):
        m = gap * 0.25
        for c in others:
            (cx, cy), (cw, ch) = c["at"], c["size"]
            if cx + m < x + aw and x < cx + cw - m and cy + m < y + ah and y < cy + ch - m:
                return False
        return True

    R = 6
    slots = [(dx, dy) for dy in range(-R, R + 1) for dx in range(-R, R + 1)]
    ang = lambda s: math.atan2(-s[1], s[0]) % (2 * math.pi)
    slots.sort(key=lambda s: (s[0] ** 2 + s[1] ** 2, ang(s)))
    for dx, dy in slots:
        x, y = ax + dx * sx, ay + dy * sy
        if free(x, y):
            dispatch(f'hl.dsp.window.resize({{ x = {int(aw)}, y = {int(ah)}, window = "address:{addr}" }})')
            dispatch(f'hl.dsp.window.move({{ x = {int(x)}, y = {int(y)}, relative = false, window = "address:{addr}" }})')
            return

if action == "out":
    for c in clients:
        ws = c["workspace"]["name"]
        if ws.startswith("special:"):
            rec[c["address"]] = ws
            move(c["address"], active)
    save(rec)
    # A special left on screen would catch the next new window (it would open
    # there instead of on the canvas): close it.
    for m in json.loads(hypr("monitors", "-j")):
        name = (m.get("specialWorkspace") or {}).get("name", "")
        if name.startswith("special:"):
            dispatch(f'hl.dsp.workspace.toggle_special("{name[8:]}")')
elif action == "back":
    for addr, ws in rec.items():
        if addr in alive:
            move(addr, ws)
    save({})
elif action == "adopt":
    addr, ws = args
    rec[addr] = ws
    save(rec)
    move(addr, active)
    dispatch(f'hl.dsp.window.float({{ action = "on", window = "address:{addr}" }})')
    place_in_ring(addr)
    dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})')
PY
}

case "${1:-}" in
infinite)
  specials out # before the canvas opens, so they join it as normal windows
  chrome hide
  sleep 0.6 # let Caelestia apply the new reserved area before the canvas measures the screen
  overview on
  notify "Modo Infinito" "Super+Ctrl+G mapa · Super+Ctrl+I volver"
  ;;
caelestia)
  overview off
  specials back
  chrome show
  notify "Modo Caelestia" "Mosaico y workspaces"
  ;;
adopt)
  # A window that opened in a special workspace (window rule) while in
  # Infinite mode: bring it onto the canvas and remember where it belongs.
  specials adopt "${2:?address}" "${3:?workspace}"
  ;;
chrome)
  # re-apply the Infinite-mode shell.json values (after editing HIDDEN)
  chrome hide
  ;;
restore)
  chrome show
  rm -f "$specials_file" # the windows it listed died with the old session
  ;;
*)
  echo "usage: $0 infinite|caelestia|adopt <address> <workspace>|restore" >&2
  exit 2
  ;;
esac
