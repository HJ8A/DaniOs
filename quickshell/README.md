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

## danios-music (`Super + M`)

A full-screen music player in the spirit of a "desktop skin": the song's
**real music video** (YouTube, video only, synced to Spotify) behind
everything, **neon edges** that react to the music (cava, GPU shader), a big
clock, a glass song card and player bar, and the **queue / playlists** on the
left. It is a real window living in the music special workspace (tiled; Super+F
for full screen); Spotify stays hidden in `special:spotify` as the audio engine.

- **Video:** `yt-dlp` searches 6 candidates and scores them
  (`services/VideoScore.js`: title, artist, "official video", duration; lyric
  videos, audio-only uploads and "- Topic" channels lose). Video only, MP4 over
  https (H.264/AV1, seekable in Qt; WebM is not) with HLS as automatic fallback
  (YouTube sometimes answers 403 to the direct URL). Kept loaded and paused
  while hidden. Sync: one seek on load, then ±10 % playback-rate nudges.
  Letterbox/pillarbox bars are detected once per video (`ffmpeg cropdetect`
  on key frames) and cropped. Cache: `~/.cache/danios-music/videos.json`.
- **Search** (click the centre card or `Ctrl+K`): Zen-style glass bar; results
  with covers grouped as Artists / Songs / Albums / Playlists, from Spotify's
  own internal search (`searchModalResults`; the Web API answers 429 from
  inside the client). Click/Enter plays; a "+" on the selected song adds it to
  the queue.
- **Lyrics** ("Letras" button under the card): synced lyrics in a panel on the
  right (current line highlighted, smooth scroll, click a line to seek).
  Source: Spotify's own lyrics through the extension, then **LRCLIB**
  (lrclib.net, public) — only fetched while the panel is open, cached in
  `~/.cache/danios-music/lyrics/`.
- **One instance only:** launched with `qs -n` (no duplicates, see
  `../caelestia/cli.json.example`), and closing the window quits the app. Before,
  a closed window left the process running with the bridge port taken and
  Super+M started another one that could not connect (no queue/playlists).
- **Players:** only Spotify and the YouTube Music desktop app
  (`players.allowed`); browsers are ignored.
- **Queue and playlists** come from the Spicetify extension
  `spicetify/danios-bridge.js` over a local WebSocket (127.0.0.1:47321):
  `cp spicetify/danios-bridge.js ~/.config/spicetify/Extensions/ &&
  spicetify config extensions danios-bridge.js && spicetify apply`.
- **Settings:** `defaults.json` + `config.json` (only your changes), also
  editable from `Super+I` → Widgets → DaniOS Music.
- **Cost** (measured): visible and playing ≈ 6–8 % CPU (+ Hyprland ≈ 11 %),
  hidden 0.2 %, paused 0 %; ~200–330 MB while open.

Needs `yt-dlp`, `ffmpeg`, `cava`, `qt6-multimedia-ffmpeg`, `qt6-websockets`,
the window/layer rules from `../caelestia/hypr-user.lua`, the toggles from
`../caelestia/cli.json.example` and the Super+M / Super+Alt+M binds in
`../phantomat/spatialoverview.lua`.

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
