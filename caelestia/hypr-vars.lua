-- DaniOS — personal keybind/variable overrides on top of vanilla Caelestia.
-- Install: copy this file (and hypr-user.lua) to ~/.config/caelestia/

return {
    windowOpacity = 1.0,
    -- Apps
    terminal = "kitty",

    -- Remapped keybinds
    kbTerminal     = "SUPER + RETURN",
    kbCloseWindow  = "SUPER + W",
    kbFileExplorer = "SUPER + E",
    kbSpecialWs    = "SUPER + S",
    kbMoveWinToWs  = "SUPER + SHIFT",

    -- Browser keybind disabled (not used). NOTE: can't just delete this line —
    -- the upstream default for kbBrowser is "SUPER + W", which would collide
    -- with kbCloseWindow below. Must stay set to "" to actually free the key.
    kbBrowser      = "",

    -- Window groups
    kbToggleGroup          = "SUPER + G",             -- was SUPER + ,
    kbUngroup              = "SUPER + SHIFT + G",     -- was SUPER + U
    kbWindowGroupCycleNext = "SUPER + bracketright",  -- was CTRL + ALT + TAB
    kbWindowGroupCyclePrev = "SUPER + bracketleft",   -- was CTRL + SHIFT + ALT + TAB
    -- kbGroupLockActive left at default (SUPER + SHIFT + ,)

    -- Unbinds (empty string = no keybind registered)
    kbMoveWindow           = "",                                        -- redundant with SUPER + mouse:272 (drag)
    kbMoveWinFromWsSpecial = "",
    kbRecord               = "",
    kbRecordSound          = "",
    kbRecordRegion         = "",
    kbWindowFullscreen     = "",                                        -- replaced by custom bind in hypr-user.lua (auto-hides bar too)

    -- Move window to special workspace: now only SUPER + SHIFT + S
    kbMoveWinToWsSpecial = "SUPER + SHIFT + S",
    -- Drop the CTRL + SUPER + SHIFT + arrow alternates, keep the ALT + mouse/PageUp/PageDown ones
    kbMoveWinToWsNext = { "SUPER + ALT + mouse_down", "SUPER + ALT + Page_Down" },
    kbMoveWinToWsPrev = { "SUPER + ALT + mouse_up", "SUPER + ALT + Page_Up" },

    -- kbNextWs / kbPrevWs NOT overridden: upstream defaults already include
    -- SUPER + mouse_down/up, the old workaround for this is obsolete.
}
