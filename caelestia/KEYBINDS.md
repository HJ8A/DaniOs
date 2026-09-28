# DaniOS — differences from vanilla Caelestia keybinds

Only what changed. Everything not listed here is still the upstream
default — see the [main Caelestia README](https://github.com/caelestia-dots/caelestia#keybinds)
for the full default list.

## Remapped

| Action | Upstream default | DaniOS |
|---|---|---|
| Terminal | `Super + T` | `Super + Return` |
| Close window | `Super + Q` | `Super + W` |
| Move window to workspace (modifier) | `Super + Alt` | `Super + Shift` |
| Toggle window group | `Super + ,` | `Super + G` |
| Ungroup window | `Super + U` | `Super + Shift + G` |
| Cycle next in group | `Ctrl + Alt + Tab` | `Super + ]` |
| Cycle previous in group | `Ctrl + Shift + Alt + Tab` | `Super + [` |
| Move window to special workspace | `Super + Alt + S` or `Ctrl + Super + Shift + Up` | `Super + Shift + S` (single combo) |

## Disabled (freed up / redundant)

| Action | Upstream default | Why disabled |
|---|---|---|
| Browser | `Super + Alt + B` | Not used |
| Move window (keyboard) | `Super + Z` | Redundant with `Super + drag` (mouse) |
| Move window out of special workspace | `Ctrl + Super + Shift + Down` | Not used |
| Record screen / with sound / region | `Ctrl + Alt + R` / `Super + Alt + R` / `Super + Shift + Alt + R` | Not used |
| Fullscreen (default dispatcher) | `Super + F` | Replaced — see custom bind below, same key, different behaviour |
| Screenshot (frozen) | `Super + Shift + S` | Freed to avoid colliding with "move to special workspace" above |
| Move window to next/prev workspace, `Ctrl+Super+Shift+arrow` variants | — | Kept the mouse-scroll/PageUp/PageDown alternatives only |

## New / custom

| Keybind | Action |
|---|---|
| `Super + I` | [Wallpaper Picker](../quickshell/wallpaper-picker) — wallpaper, colour scheme, bar mode, effects, GIFs |
| `Super + H` | [Keybinds Viewer](../quickshell/keybinds-viewer) — this list, live, in a searchable overlay |
| `Super + Q` | Open launcher (freed up since Close Window moved to `Super + W`) |
| `Super + F` | Fullscreen **and** auto-hide the bar in one action |
| `Super + Space` | Toggle floating (extra alias — the default `Super + Alt + Space` still works too) |
| `Super + J` | Toggle split layout (`togglesplit`) |
| `Super + Tab` | Cycle next window (extra alias of the default `Alt + Tab`) |
| `Print` | Screenshot region → Swappy |
| `Super + Print` | Screenshot region → clipboard |
| `Shift + Print` | Screenshot region → file |

## Known gotcha this fixed

`kbMoveWinToWsSpecial` was remapped to `Super + Shift + S` without
noticing that's also the upstream default for `kbScreenshotFreeze` —
Hyprland happily registers both, so pressing it fired **two** actions at
once. Fixed by explicitly disabling `kbScreenshotFreeze`. If you remap a
keybind variable here, always check it doesn't already belong to something
else — [Keybinds Viewer](../quickshell/keybinds-viewer) (`Super + H`) is
the easiest way to check what's already bound to a combo before reusing it.
