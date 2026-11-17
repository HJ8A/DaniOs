# `quickshell/` — custom widgets (DaniOS)

Three standalone Quickshell apps, independent of the main Caelestia Shell
process — each runs as its own `qs -c <name>` instance. The picker and the
keybinds viewer are toggled by a keybind; the desktop widgets run always.

## Install

```sh
mkdir -p ~/.config/quickshell
cp -a wallpaper-picker keybinds-viewer desktop-widgets ~/.config/quickshell/
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

6 tabs: **Wallpaper, Color Scheme, Bar, Effects, GIFs, Widgets**. Reads the live
colour scheme so its own UI stays in sync with whatever wallpaper is
active — no manual re-theming needed.

- **Wallpaper / GIFs:** a full-width infinite carousel of tall
  parallelogram tiles floating over the screen. `←`/`→` (or the mouse
  wheel, or drag) move it, `Enter` (or a click on the centre tile) applies
  with a pop/flash animation, `Esc` closes. In GIFs, `↑`/`↓` switch the
  target slot and only the centre GIF animates.
- **Color Scheme:** one card per scheme, painted with that scheme's own
  palette (background, text and 5 swatches) read live from
  `caelestia scheme list` — every scheme the CLI ships shows up, plus
  flavour pills for schemes that have several (mocha/latte, …). The
  active one has a ✓; applying recolours the picker itself at once.

Needs these folders to exist (create them, drop your own images in):

- `~/Pictures/wallpapers` — for the Wallpaper tab
- `~/Pictures/gifs` — for the GIFs tab (sets `paths.sessionGif` /
  `paths.mediaGif` in `shell.json` — the session-panel GIF and the
  "now playing" media-widget GIF)

Requires: `python3`, `lua5.4`, `hyprctl`, and `thunar` (used by the
"open folder" buttons — swap `"thunar"` for your own file manager in
`shell.qml`'s `openFolder()` if you use something else).

The **Widgets** tab configures `desktop-widgets` (below). It is loaded only
while open, and reaches the clocks through the `wallpaper-picker/dw`
symlink (Quickshell refuses imports from outside the config folder), so
keep both folders side by side in `~/.config/quickshell/`.

## desktop-widgets (always on, autostarted by `hypr-user.lua`)

One clock on the desktop (`WlrLayer.Bottom`, click-through), drawn on the
GPU and updated once per minute:

- **analog** — floating numerals (arabic/roman), optional seconds hand.
- **sunmoon** — sun/moon by real solar elevation (or a day arc), sunrise,
  sunset and moon phase; computed offline (NOAA algorithm).
- **earth** — a GLSL globe centred on your city with the real day/night
  line, city lights, sun and moon orbiting in their real directions; spins
  while hovered. Textures: NASA (public domain, see `assets/CREDITS.md`).

Settings: `defaults.json` holds every option; `~/.config/quickshell/desktop-widgets/config.json`
(optional) holds only what you change — normally written by the Widgets
tab, watched and applied live. Set `location` to your city's latitude and
longitude. To rebuild the shader: `qsb --glsl "100es,120,150" --hlsl 50
--msl 12 -o shaders/earth.frag.qsb shaders/earth.frag`.

### Music player + cava

Shown only while something is playing (MPRIS: Spotify, YouTube/YouTube Music in
the browser, VLC, mpv… — no accounts or APIs), bottom-left by default:

- **card** — cover, title, artist, progress (click = seek), ⏮ ⏯ ⏭, the
  *app's* own volume (PipeWire stream; mouse wheel too) and player switcher.
- **vinyl** — the cover is the sleeve with ⏮ ⏯ ⏭ on it; while playing the
  record slides out, spins (only the label turns, at 30 steps/s) and the
  tonearm drops; below, a small frosted-glass pill with title, progress and
  volume.
- **cava** (separate `cava` process, stereo) drawn entirely on the GPU
  (`shaders/spectrum.frag`): bars / wave / dots on the bottom (or top and
  bottom) screen edge — replacing Caelestia's background visualiser, so set
  `background.visualiser.enabled = false` — or around the card / record.
  It only runs while music plays and the desktop is visible (hidden behind
  tiled windows), ~5 % CPU while playing, 0 % paused.

Needs `cava`, the *Material Symbols Rounded* and *Rubik* fonts, and the
`desktop-widgets-*` layer rules from `../caelestia/hypr-user.lua`. Keep the
player's bottom margin ≥ 90 px: on an empty desktop Caelestia grabs the mouse
in an ~87 px band along every screen edge (drag-to-open panels).

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
