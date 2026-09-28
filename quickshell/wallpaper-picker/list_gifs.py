#!/usr/bin/env python3
"""Outputs JSON with the .gif files in ~/Pictures/gifs, plus which one is
currently set for each Caelestia gif slot (session panel / media widget)."""
import json
import os
from pathlib import Path

home = Path.home()
config = Path(os.getenv("XDG_CONFIG_HOME", home / ".config"))

gifs_dir = home / "Pictures" / "gifs"

shell_json_path = config / "caelestia" / "shell.json"
shell_data = {}
try:
    shell_data = json.loads(shell_json_path.read_text())
except (OSError, json.JSONDecodeError):
    pass

paths = shell_data.get("paths", {})
current_session = paths.get("sessionGif", "")
current_media = paths.get("mediaGif", "")

gifs = []
if gifs_dir.is_dir():
    for f in sorted(gifs_dir.iterdir()):
        if not f.is_file() or f.suffix.lower() != ".gif":
            continue
        gifs.append({
            "path": str(f),
            "name": f.stem,
            "isSession": str(f) == current_session,
            "isMedia": str(f) == current_media,
        })

print(json.dumps({
    "gifs": gifs,
    "currentSession": current_session,
    "currentMedia": current_media,
}))
