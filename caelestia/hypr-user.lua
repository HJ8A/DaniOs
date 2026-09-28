-- DaniOS — personal Hyprland overrides on top of vanilla Caelestia.
-- Install: copy this file (and hypr-vars.lua) to ~/.config/caelestia/
--
-- The sections marked "MACHINE-SPECIFIC" below are examples from the
-- original author's laptop — edit them to match your own hardware before
-- using this file as-is.

local home = os.getenv("HOME")

-- Re-enable middle click paste (Caelestia disables it in misc.lua)
hl.config({
    misc = {
        middle_click_paste = true,
    },
})

-- MACHINE-SPECIFIC: monitor output/resolution/refresh/scale.
-- Find your output name with `hyprctl monitors`.
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@165",
    position = "0x0",
    scale    = 1.6,
})

-- NVIDIA fix — only needed if you have an NVIDIA GPU
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
})

-- MACHINE-SPECIFIC: keyboard layout(s). Comma-separated to enable switching
-- between them (click the keyboard icon in the bar, or its keybind).
hl.config({
    input = {
        kb_layout  = "us,latam",
        kb_variant = "intl,",
    },
})

-- MACHINE-SPECIFIC: default audio sink. Find your sink name with
-- `pactl list short sinks` — a PipeWire *node ID* (a bare number) is NOT
-- stable across reboots, always use the sink *name* instead.
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 3 && pactl set-default-sink alsa_output.pci-0000_00_1f.3.analog-stereo")
end)

-- Window rules
hl.window_rule({
    match  = { class = "thunar" },
    float  = true,
    size   = "860 560",
    center = true,
})

-- --- Custom keybinds ---

-- Super+I: Wallpaper & colour picker (toggle) — see ../quickshell/wallpaper-picker
hl.bind("SUPER + I", hl.dsp.exec_cmd(home .. "/.config/quickshell/wallpaper-picker/toggle.sh"),
    { description = "Wallpaper & colour picker" })

-- Super+Q: Caelestia launcher
hl.bind("SUPER + Q", hl.dsp.global("caelestia:launcher"),
    { description = "Open launcher" })

-- Super+F: fullscreen + auto-hide bar (replaces default fullscreen bind, see hypr-vars.lua note)
hl.bind("SUPER + F", function()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))
    hl.dispatch(hl.dsp.exec_cmd("caelestia shell drawers toggle bar"))
end, { description = "Fullscreen + auto-hide bar" })

-- Floating window alias (keyboard split-friendly, no Alt needed)
hl.bind("SUPER + Space", hl.dsp.window.float(),
    { description = "Toggle floating" })

-- Layout
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"),
    { description = "Toggle split layout" })
hl.bind("SUPER + TAB", hl.dsp.window.cycle_next(),
    { description = "Cycle next window" })

-- Keybinds cheatsheet (Super+H) — see ../quickshell/keybinds-viewer
hl.bind("SUPER + H", hl.dsp.exec_cmd(home .. "/.config/quickshell/keybinds-viewer/toggle.sh"),
    { description = "Show keybinds cheatsheet" })

-- Screenshots (grim + swappy)
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp -b 1a1a2e80)" - | swappy -f -'),
    { description = "Screenshot region -> Swappy" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd('grim -g "$(slurp -b 1a1a2e80)" - | wl-copy && notify-send "Screenshot" "Copied to clipboard" -t 1000'),
    { description = "Screenshot region -> clipboard" })
-- MACHINE-SPECIFIC: change the save folder to your own (this example uses
-- a localized "Pictures" folder name — adjust to whatever your system uses).
hl.bind("SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp -b 1a1a2e80)" ' .. home .. '/Pictures/Screenshots/save$(date +\'%Y-%m-%d_%H-%M-%S\').png'),
    { description = "Screenshot region -> file" })
