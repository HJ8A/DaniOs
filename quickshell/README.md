# `quickshell/` — custom widgets (DaniOS)

Two standalone Quickshell apps, independent of the main Caelestia Shell
process — each runs as its own `qs -c <name>` instance, toggled by a
keybind.

## Install

```sh
mkdir -p ~/.config/quickshell
cp -r wallpaper-picker keybinds-viewer ~/.config/quickshell/
chmod +x ~/.config/quickshell/wallpaper-picker/toggle.sh \
         ~/.config/quickshell/wallpaper-picker/*.py \
         ~/.config/quickshell/keybinds-viewer/toggle.sh
```

Then add the keybinds from `../caelestia/hypr-user.lua` (`SUPER + I` and
`SUPER + H`), or bind them however you like:

```lua
hl.bind("SUPER + I", hl.dsp.exec_cmd(home .. "/.config/quickshell/wallpaper-picker/toggle.sh"))
hl.bind("SUPER + H", hl.dsp.exec_cmd(home .. "/.config/quickshell/keybinds-viewer/toggle.sh"))
```

## wallpaper-picker (`Super + I`)

5 tabs: **Wallpaper, Color Scheme, Bar, Effects, GIFs**. Reads the live
colour scheme so its own UI stays in sync with whatever wallpaper is
active — no manual re-theming needed.

Needs these folders to exist (create them, drop your own images in):

- `~/Pictures/wallpapers` — for the Wallpaper tab
- `~/Pictures/gifs` — for the GIFs tab (sets `paths.sessionGif` /
  `paths.mediaGif` in `shell.json` — the session-panel GIF and the
  "now playing" media-widget GIF)

Requires: `python3`, `lua5.4`, `hyprctl`, and `thunar` (used by the
"open folder" buttons — swap `"thunar"` for your own file manager in
`shell.qml`'s `openFolder()` if you use something else).

## keybinds-viewer (`Super + H`)

A live cheatsheet of your keybinds, grouped by category, with a search box.
Reads `~/.config/hypr/variables.lua` + `~/.config/caelestia/hypr-vars.lua`
directly (the same merge Hyprland itself does) so it always reflects your
*actual* current keybinds — remap something and the next time you open it,
it's already updated. No manual doc-keeping.

If you add a new named keybind variable in `hypr-vars.lua` that isn't in
`gen_keybinds.lua`'s `MAP` table, it won't show up here — add it to `MAP`
(category + human label). Custom one-off binds written directly with
`hl.bind(key, action, { description = "..." })` in `hypr-user.lua` are
picked up automatically, no `MAP` entry needed.
