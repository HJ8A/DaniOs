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

## What's in here

| File | Purpose |
|---|---|
| `hypr-user.lua` | Hyprland keybind overrides, window rules, monitor/audio/autostart config |
| `hypr-vars.lua` | Keybind variable remaps (which key does what) — see comments for what changed vs. upstream defaults |
| `shell.json.example` | Caelestia Shell config — bar status icons, idle behaviour, launcher favourites, etc. Rename to `shell.json` after copying. |

`shell.json.example` intentionally does **not** set `paths.sessionGif` /
`paths.mediaGif` — those point to personal GIF files that aren't shipped
here. See `../quickshell/wallpaper-picker` for a UI to set your own once
you've dropped some `.gif` files into `~/Pictures/gifs`.

Requires the Hyprland Lua config (upstream migrated away from `.conf` in
August 2026) — if your Hyprland is still on `.conf`, this won't apply
directly.
