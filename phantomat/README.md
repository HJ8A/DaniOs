# `phantomat/` — Infinite desktop mode (DaniOS)

A second desktop mode on top of Caelestia: every window floats on one
endless 2D canvas, you zoom out to see everything (map + type-to-search),
and pan around it like a whiteboard. One key switches between the normal
**Caelestia mode** (tiling + workspaces, bar, frame) and **Infinite mode**
— no restart, windows go back to tiling when you leave.

The canvas itself is the [Phantomat](https://github.com/kaolti/phantomat)
Hyprland plugin by kaolti. DaniOS uses a fork with a few changes
(**[HJ8A/phantomat](https://github.com/HJ8A/phantomat)**); this folder is
only the integration with Caelestia.

| Hyprland | Fork branch | Base |
|---|---|---|
| **0.57** | **`caelestia-h-057`** | [djeddi-yacine's 0.57 port](https://github.com/djeddi-yacine/phantomat) of kaolti's plugin (upstream doesn't build on 0.57 yet, kaolti/phantomat#20) |
| 0.56 | `caelestia-h` | kaolti/phantomat `a1e8a08` |

## What's in here

| File | Install to | Purpose |
|---|---|---|
| `spatialoverview.lua` | `~/.config/hypr/spatialoverview.lua` | Plugin settings + every keybind that behaves differently per mode |
| `phantomat-mode.sh` | `~/.config/phantomat/phantomat-mode.sh` | The switch: hides/restores the bar and frame, moves special-workspace windows onto the canvas and back, opens/closes the canvas |

## Install

Needs Hyprland 0.57 (or 0.56, see the table above) with the Lua config, `g++ ≥ 15` and Hyprland's
headers (`sudo pacman -S --needed base-devel hyprland hyprgraphics pango lua`).

```sh
# 1. the integration first: the plugin's installer keeps an existing
#    spatialoverview.lua instead of copying its Omarchy example
install -Dm644 spatialoverview.lua ~/.config/hypr/spatialoverview.lua
install -Dm755 phantomat-mode.sh   ~/.config/phantomat/phantomat-mode.sh

# 2. build + install the plugin (adds a marked block to hyprland.lua)
git clone -b caelestia-h-057 https://github.com/HJ8A/phantomat.git ~/Proyectos/phantomat
cd ~/Proyectos/phantomat && scripts/install.sh

# 3. the installer may open the canvas on its own: go back to Caelestia mode
~/.config/phantomat/phantomat-mode.sh caelestia
```

**After every Hyprland update** the plugin has to be rebuilt:
`cd ~/Proyectos/phantomat && git pull && scripts/install.sh`, then step 3.
If it doesn't build yet for the new Hyprland, Caelestia mode keeps working
(`spatialoverview.lua` does nothing while the plugin isn't loaded).

**If the new build doesn't take over** (the installer says it could not unload
the running Phantomat safely — its `safe-unload` helper doesn't work on 0.57
yet): with the canvas closed (Caelestia mode), reload it by hand:

```sh
hyprctl plugin unload ~/.local/share/spatial-overview/spatialoverview.so
hyprctl plugin load   ~/.local/share/spatial-overview/spatialoverview.so
hyprctl reload
```

**Uninstall:** `cd ~/Proyectos/phantomat && scripts/uninstall.sh`.

## Keys

| Key | Caelestia mode | Infinite mode |
|---|---|---|
| `Super + Ctrl + I` | → Infinite mode | → Caelestia mode |
| `Super + Ctrl + G` | — | Map (zoomed out + search) ↔ normal view |
| `Super + T` | — | Fill the screen (with gaps) / back |
| `Super + O` | — | Pin window to the screen / back to the canvas |
| `Super + arrows` | Move focus | Window on that side (camera follows) |
| `Super + Shift + arrows` | Move window | Nudge window one grid step |
| `Super + Tab` | Next window | Toggle with the previous window |
| `Alt + Tab` | Cycle windows | Recent windows (hold `Alt` for the list) |
| `Super + F` | Fullscreen + hide bar | Fullscreen only |
| `Super + Space`, `Super + G`, `Super + J`, `Super + 1–0`, `Super + Shift + 1–0`, special workspaces | As usual | Nothing (no tiling, groups or workspaces on the canvas) |
| `Super` + middle-drag | — | Pan the canvas (plain middle click still pastes) |

In the map: type to search, arrows to select, `Enter` to go, `Delete`
closes the selected window, `Ctrl + A` tidies everything up, `Ctrl + ,`
tunes the look, `F1` lists every key.

## How the two modes stay in sync

- The mode is decided by `phantomat-mode.sh`, not by asking the plugin: it
  writes `~/.local/state/phantomat/caelestia-chrome.json` when entering
  Infinite mode (with the original `shell.json` values) and deletes it on
  the way out. A fullscreen window makes the plugin step its canvas aside,
  so asking the plugin would look like Caelestia mode.
- Bar and frame are hidden by editing `shell.json` (`bar.persistent`,
  `bar.showOnHover`, `border.thickness`) — Caelestia applies it live — and
  restored byte for byte.
- Caelestia's edge panels (volume/brightness, utilities, dashboard) fade
  out only while the map is open (`chrome_animation` on the
  `caelestia-drawers` layer); at 100 % they work as usual.
- Special workspaces don't work on the canvas: their windows join the
  canvas when entering Infinite mode and go back to their special
  workspace when leaving (`~/.local/state/phantomat/specials.json`).
- A session always starts in Caelestia mode; if one ended in Infinite mode,
  `hyprland.start` restores bar and frame.

## Fork changes (`HJ8A/phantomat`, branch `caelestia-h-057`)

- `canvas.open_filled`: new windows open filled, in the first free
  screen-sized slot of a fixed ring around the canvas centre (centre,
  right, up, left, down, diagonals, next ring) — the canvas fills from the
  centre out instead of drifting after the camera. A window that opens
  maximized (apps that remember it, e.g. kitty, browsers) has the maximize
  dropped: on the canvas maximized reads as fullscreen.
- Windows opened while the canvas is up tile again when it closes (on the
  0.57 port they stayed floating).
- `scripts/install.sh` works with Hyprland 0.57's `hyprctl clients` JSON.
- Plain middle click goes to the window (paste); `Super` + middle-drag pans.
- `Delete` in the map closes the selected window.
- `Ctrl + A` keeps screen-sized windows at the exact fill size (it used to
  round them to the grid, losing the side margins).
