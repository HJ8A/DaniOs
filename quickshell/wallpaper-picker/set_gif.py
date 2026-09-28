#!/usr/bin/env python3
"""Writes paths.sessionGif or paths.mediaGif to caelestia's shell.json."""
import json
import os
import sys
from pathlib import Path

config = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
shell_json = config / "caelestia" / "shell.json"
slot = sys.argv[1]   # "session" | "media"
path = sys.argv[2]

try:
    data = json.loads(shell_json.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

paths = data.setdefault("paths", {})

if slot == "session":
    paths["sessionGif"] = path
elif slot == "media":
    paths["mediaGif"] = path

shell_json.write_text(json.dumps(data, indent=4))
