#!/usr/bin/env python3
"""Writes bar.persistent / bar.showOnHover to caelestia's shell.json."""
import json
import os
import sys
from pathlib import Path

config = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
shell_json = config / "caelestia" / "shell.json"
mode = sys.argv[1]  # "always" | "hover" | "hidden"

try:
    data = json.loads(shell_json.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

bar = data.setdefault("bar", {})

if mode == "always":
    bar["persistent"] = True
    bar.pop("showOnHover", None)
elif mode == "hover":
    bar["persistent"] = False
    bar["showOnHover"] = True
elif mode == "hidden":
    bar["persistent"] = False
    bar["showOnHover"] = False

shell_json.write_text(json.dumps(data, indent=4))
