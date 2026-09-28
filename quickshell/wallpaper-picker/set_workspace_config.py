#!/usr/bin/env python3
"""Updates bar.workspaces in caelestia's shell.json and a local state file."""
import json
import os
import sys
from pathlib import Path

config = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
shell_json = config / "caelestia" / "shell.json"
state_file = Path(__file__).parent / "ws_state.json"

# Parse args: --labels icons|numbers  --max-icons N  --shown N
args = sys.argv[1:]
opts = {}
i = 0
while i < len(args):
    if args[i] in ("--labels", "--max-icons", "--shown") and i + 1 < len(args):
        opts[args[i]] = args[i + 1]
        i += 2
    else:
        i += 1

# --- shell.json ---
try:
    data = json.loads(shell_json.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

ws = data.setdefault("bar", {}).setdefault("workspaces", {})

if "--labels" in opts:
    if opts["--labels"] == "numbers":
        ws["label"] = None
        ws["occupiedLabel"] = None
        ws["activeLabel"] = None
    else:  # icons — remove overrides so C++ defaults kick in
        ws.pop("label", None)
        ws.pop("occupiedLabel", None)
        ws.pop("activeLabel", None)

if "--max-icons" in opts:
    n = int(opts["--max-icons"])
    if n == 0:       # hide all app icons
        ws["showWindows"] = False
        ws["maxWindowIcons"] = 0
    elif n == -1:    # unlimited
        ws["showWindows"] = True
        ws["maxWindowIcons"] = 0
    else:            # specific limit
        ws["showWindows"] = True
        ws["maxWindowIcons"] = n

if "--shown" in opts:
    ws["shown"] = int(opts["--shown"])

shell_json.write_text(json.dumps(data, indent=4))

# --- ws_state.json (caelestia never touches this file) ---
try:
    state = json.loads(state_file.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    state = {}

if "--labels" in opts:
    state["labels"] = opts["--labels"]

state_file.write_text(json.dumps(state, indent=4))
