#!/usr/bin/env bash
# Phantomat × Caelestia — switch between Caelestia mode and Infinite mode.
#
#   phantomat-mode.sh infinite   hide bar + border, open the canvas
#   phantomat-mode.sh caelestia  close the canvas (windows re-tile), restore bar + border
#   phantomat-mode.sh ungroup|regroup  by hand: record + break up window groups / rebuild them
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

# The bar also takes room when it's open on the screen (Super+F in Caelestia
# mode toggles it, or a drag from the left edge), whatever bar.persistent says.
# Infinite mode closes it and remembers; Caelestia mode opens it again.
bar_open="$state_dir/bar-open"
bar() {
  local open
  open=$(qs -c caelestia ipc call drawers isOpen bar 2>/dev/null || true)
  if [[ $1 == close && $open == 1 ]]; then
    caelestia shell drawers toggle bar >/dev/null 2>&1 && touch "$bar_open"
  elif [[ $1 == reopen && -e $bar_open ]]; then
    [[ $open == 1 ]] || caelestia shell drawers toggle bar >/dev/null 2>&1 || true
    rm -f "$bar_open"
  fi
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

# Window groups (tabs) don't work on the canvas: a group lands there as one
# pile of identical windows and the plugin crashes Hyprland on the way out.
# Entering Infinite mode records every group and breaks it up (still tiled, so
# it's safe); back in Caelestia mode the members still alive are grouped again.
groups_path = os.path.join(os.path.dirname(path), "groups.json")
# Windows of special workspaces that were floating before Infinite mode: the
# canvas floats everything, so on the way back the rest are tiled again.
floats_path = os.path.join(os.path.dirname(path), "floating.json")

def clients_now():
    return {c["address"]: c for c in json.loads(hypr("clients", "-j"))}

def directions(src, dst):
    """Directions to try from src towards dst, most likely first."""
    (sx, sy), (sw, sh) = src["at"], src["size"]
    (dx, dy), (dw, dh) = dst["at"], dst["size"]
    vx, vy = (dx + dw / 2) - (sx + sw / 2), (dy + dh / 2) - (sy + sh / 2)
    h = "right" if vx > 0 else "left"
    v = "down" if vy > 0 else "up"
    first = [h, v] if abs(vx) >= abs(vy) else [v, h]
    return first + [d for d in ("left", "right", "up", "down") if d not in first]

def out_of_group(addr):
    dispatch(f'hl.dsp.window.move({{ out_of_group = true, window = "address:{addr}" }})')

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
    floating = []
    for c in clients:
        ws = c["workspace"]["name"]
        if ws.startswith("special:"):
            rec[c["address"]] = ws
            if c["floating"]:
                floating.append(c["address"])
            move(c["address"], active)
    save(rec)
    json.dump(floating, open(floats_path, "w"))
    # A special left on screen would catch the next new window (it would open
    # there instead of on the canvas): close it.
    for m in json.loads(hypr("monitors", "-j")):
        name = (m.get("specialWorkspace") or {}).get("name", "")
        if name.startswith("special:"):
            dispatch(f'hl.dsp.workspace.toggle_special("{name[8:]}")')
elif action == "back":
    try:
        floating = set(json.load(open(floats_path)))
    except (OSError, ValueError):
        floating = set()
    for addr, ws in rec.items():
        if addr in alive:
            move(addr, ws)
            if addr not in floating and alive[addr]["floating"]:
                dispatch(f'hl.dsp.window.float({{ action = "off", window = "address:{addr}" }})')
    save({})
    if os.path.exists(floats_path):
        os.remove(floats_path)
elif action == "ungroup":
    groups, seen = [], set()
    for c in clients:
        members = c.get("grouped") or []
        if len(members) > 1 and members[0] not in seen:
            seen.update(members)
            groups.append(members)  # tab order, as Hyprland lists it
    if groups:
        json.dump(groups, open(groups_path, "w"))
        was_focused = json.loads(hypr("activewindow", "-j") or "{}").get("address")
        for members in groups:
            for addr in members:
                out_of_group(addr)
        if was_focused:  # taking a window out of a group focuses it: give focus back
            dispatch(f'hl.dsp.focus({{ window = "address:{was_focused}" }})')
elif action == "regroup":
    try:
        groups = json.load(open(groups_path))
    except (OSError, ValueError):
        groups = []
    # into_group only moves the focused window: focus each member in turn, then
    # give focus back and close any special workspace that opened on the way.
    was_focused = json.loads(hypr("activewindow", "-j") or "{}").get("address")
    was_special = {m["name"]: (m.get("specialWorkspace") or {}).get("name", "") for m in json.loads(hypr("monitors", "-j"))}
    for members in groups:
        now = clients_now()
        by_ws = {}
        for addr in members:  # closed windows drop out; the rest regroup per workspace
            if addr in now and not now[addr].get("grouped"):
                by_ws.setdefault(now[addr]["workspace"]["name"], []).append(addr)
        for ws, alive in by_ws.items():
            if len(alive) < 2:
                continue
            lead = alive[0]
            dispatch(f'hl.dsp.group.toggle({{ window = "address:{lead}" }})')
            if lead not in (clients_now()[lead].get("grouped") or []):
                continue  # couldn't start the group: leave them as separate windows
            for addr in alive[1:]:
                dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})')
                for d in directions(clients_now()[addr], clients_now()[lead]):
                    dispatch(f'hl.dsp.window.move({{ into_group = "{d}" }})')
                    joined = clients_now()[addr].get("grouped") or []
                    if lead in joined:
                        break
                    if joined:  # landed in some other group: take it back out
                        out_of_group(addr)
    if groups:
        if was_focused and was_focused in clients_now():
            dispatch(f'hl.dsp.focus({{ window = "address:{was_focused}" }})')
        for m in json.loads(hypr("monitors", "-j")):
            name = (m.get("specialWorkspace") or {}).get("name", "")
            if name.startswith("special:") and name != was_special.get(m["name"], ""):
                dispatch(f'hl.dsp.workspace.toggle_special("{name[8:]}")')
    if os.path.exists(groups_path):
        os.remove(groups_path)
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
  specials ungroup # groups can't live on the canvas: record and break them up while still tiled
  specials out # before the canvas opens, so they join it as normal windows
  chrome hide
  bar close
  sleep 0.6 # let Caelestia apply the new reserved area before the canvas measures the screen
  overview on
  notify "Modo Infinito" "Super+Ctrl+G mapa · Super+Ctrl+I volver"
  ;;
caelestia)
  overview off
  specials back
  sleep 0.4 # let the windows re-tile before grouping them by position
  specials regroup # the groups recorded on the way in, with the members still open
  chrome show
  bar reopen
  notify "Modo Caelestia" "Mosaico y workspaces"
  ;;
ungroup|regroup)
  # by hand: break up / rebuild the recorded window groups (normally done by infinite / caelestia)
  specials "$1"
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
  rm -f "$specials_file" "$state_dir/groups.json" "$state_dir/floating.json" "$bar_open" # they described the old session
  ;;
*)
  echo "usage: $0 infinite|caelestia|ungroup|regroup|adopt <address> <workspace>|restore" >&2
  exit 2
  ;;
esac
