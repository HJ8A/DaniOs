#!/usr/bin/env python3
"""Outputs JSON with wallpaper list + caelestia thumbnail paths + current scheme colors."""
import hashlib
import json
import os
import subprocess
from pathlib import Path

home = Path.home()
config = Path(os.getenv("XDG_CONFIG_HOME", home / ".config"))
cache = Path(os.getenv("XDG_CACHE_HOME", home / ".cache"))
state = Path(os.getenv("XDG_STATE_HOME", home / ".local/state"))

wallpapers_dir = home / "Pictures" / "wallpapers"
wallpapers_cache = cache / "caelestia" / "wallpapers"
scheme_path = state / "caelestia" / "scheme.json"
current_path = state / "caelestia" / "wallpaper" / "path.txt"

VALID_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".tif", ".tiff"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


current = ""
try:
    current = current_path.read_text().strip()
except OSError:
    pass

scheme_colors = {}
try:
    scheme_data = json.loads(scheme_path.read_text())
    scheme_colors = scheme_data.get("colours", {})
except (OSError, json.JSONDecodeError):
    pass

wallpapers = []
if wallpapers_dir.is_dir():
    for f in sorted(wallpapers_dir.iterdir()):
        if not f.is_file() or f.suffix.lower() not in VALID_EXT:
            continue
        try:
            h = sha256(f)
            thumb = wallpapers_cache / h / "thumbnail.jpg"
            wallpapers.append({
                "path": str(f),
                "thumb": str(thumb) if thumb.exists() else str(f),
                "name": f.stem,
                "current": str(f) == current,
            })
        except OSError:
            pass

active_window_addr = ""
active_window_class = ""
try:
    res = subprocess.run(
        ["hyprctl", "activewindow", "-j"],
        capture_output=True, text=True, timeout=2,
    )
    aw = json.loads(res.stdout)
    active_window_addr = aw.get("address", "")
    active_window_class = aw.get("class", "")
except Exception:
    pass

shell_json_path = config / "caelestia" / "shell.json"
shell_data = {}
try:
    shell_data = json.loads(shell_json_path.read_text())
except (OSError, json.JSONDecodeError):
    pass

bar_data = shell_data.get("bar", {})
bar_config = {
    "persistent": bar_data.get("persistent", True),
    "showOnHover": bar_data.get("showOnHover", True),
}
ws_config = bar_data.get("workspaces", {})

ws_state_path = Path(__file__).parent / "ws_state.json"
ws_state = {"labels": "numbers"}  # default: numbers (Opción A)
try:
    ws_state = json.loads(ws_state_path.read_text())
except (OSError, json.JSONDecodeError):
    pass

print(json.dumps({
    "wallpapers": wallpapers,
    "current": current,
    "colors": scheme_colors,
    "bar": bar_config,
    "workspace_config": ws_config,
    "ws_state": ws_state,
    "active_window_addr": active_window_addr,
    "active_window_class": active_window_class,
}))
