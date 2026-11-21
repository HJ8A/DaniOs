# `caelestia/` — personal overrides (DaniOS)

Not part of upstream Caelestia — these are DaniOS's personal overrides,
loaded on top of the base dotfiles.

## Install

```sh
mkdir -p ~/.config/caelestia
cp hypr-user.lua hypr-vars.lua ~/.config/caelestia/
cp shell.json.example ~/.config/caelestia/shell.json
```

Then **edit `hypr-user.lua`** — every section marked `MACHINE-SPECIFIC` is
an example from the original author's laptop (monitor name/resolution,
audio sink name, keyboard layout, screenshot folder) and needs adjusting to
your own hardware. Run `hyprctl monitors` and `pactl list short sinks` to
find your own values.

See [`KEYBINDS.md`](./KEYBINDS.md) for the full list of what changed vs.
vanilla Caelestia's default keybinds.

## What's in here

| File | Purpose |
|---|---|
| `hypr-user.lua` | Hyprland keybind overrides, window rules, monitor/audio/autostart config |
| `hypr-vars.lua` | Keybind variable remaps (which key does what) — see comments for what changed vs. upstream defaults |
| `shell.json.example` | Caelestia Shell config — bar status icons, idle behaviour, launcher favourites, etc. Rename to `shell.json` after copying. |
| `patches/` | Local patches for the system `caelestia-shell` package (see below) |

`shell.json.example` intentionally does **not** set `paths.sessionGif` /
`paths.mediaGif` — those point to personal GIF files that aren't shipped
here. See `../quickshell/wallpaper-picker` for a UI to set your own once
you've dropped some `.gif` files into `~/Pictures/gifs`.

Requires the Hyprland Lua config (upstream migrated away from `.conf` in
August 2026) — if your Hyprland is still on `.conf`, this won't apply
directly.

## Patches for `caelestia-shell` (system package)

### `patches/caelestia-special-ws-ids.patch` — special workspaces in the bar (Hyprland 0.57)

**Bug:** with several special workspaces open (Super+S, Super+R, Super+M…)
every one shows the same icons, icons repeat and the active one is not
highlighted; clicking them does nothing. Hyprland 0.57 no longer gives
special workspaces an `id` in its JSON, Quickshell then reports `-1` for all
of them and the bar matches workspaces by id. Upstream issues (open as of
2026-11-20): caelestia-dots/shell #2235, #2261.

**Fix:** community patch by romanvesely
(<https://gist.github.com/romanvesely/ad4c7e41b3cac561ff06b44c62501d2b>),
reviewed: QML only, 3 files; special workspaces get a stable id derived from
their name and the active one is matched by name. Applies cleanly to 2.5.0.

```sh
sudo patch -p1 -b -d /etc/xdg/quickshell/caelestia -i patches/caelestia-special-ws-ids.patch
caelestia shell -k; caelestia shell -d          # restart the shell
# undo: sudo patch -p1 -R -d /etc/xdg/quickshell/caelestia -i patches/caelestia-special-ws-ids.patch
```

It is system-wide (all users) and is overwritten by the next
`caelestia-shell` update — re-apply it if that update does not include the
official fix.
