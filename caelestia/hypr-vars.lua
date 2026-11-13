-- DaniOS — personal keybind/variable overrides on top of vanilla Caelestia.
-- Install: copy this file (and hypr-user.lua) to ~/.config/caelestia/

return {
    windowOpacity = 1.0,
    -- Apps
    terminal = "kitty",

    -- Audio
    volumeStep = 5, -- upstream default is 10

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
    kbScreenshotFreeze     = "",                                        -- was SUPER+SHIFT+S, collided with kbMoveWinToWsSpecial below

    -- More unbinds (empty string = bind not registered). To re-enable one,
    -- delete its line and it falls back to the upstream default shown.
    kbScreenshot           = "",  -- default Print: fired together with the custom Print bind in hypr-user.lua
    kbScreenshotRegion     = "",  -- default SUPER+SHIFT+ALT+S: not used
    kbLauncher             = "",  -- default SUPER (tap): launcher only opens with SUPER+Q (hypr-user.lua)
    kbEditor               = "",  -- default SUPER+C: not used
    kbAudioSettings        = "",  -- default CTRL+ALT+V: not used (opens pwvucontrol)
    kbToggleWindowFloating = "",  -- default SUPER+ALT+Space: duplicate of SUPER+Space (hypr-user.lua)
    kbWindowBorderedFullscreen = "", -- default SUPER+ALT+F: not used
    kbClipboardPasteLatest = "",  -- default CTRL+SHIFT+ALT+V: needs ydotool
    kbMediaStop            = "",  -- default CTRL+SUPER+Backspace: not used (XF86AudioStop still works)

    -- Delete clipboard entry: a split keyboard without an ALT key can still reach it
    kbClipboardDel         = "SUPER + SHIFT + V",  -- default SUPER+ALT+V

    -- Resize: keep SUPER (+SHIFT) + Minus/Equal, drop the SUPER + ALT + arrows alternates
    kbWindowDecreaseWidth  = "SUPER + Minus",
    kbWindowIncreaseWidth  = "SUPER + Equal",
    kbWindowDecreaseHeight = "SUPER + SHIFT + Minus",
    kbWindowIncreaseHeight = "SUPER + SHIFT + Equal",

    -- Move window to special workspace: now only SUPER + SHIFT + S
    kbMoveWinToWsSpecial = "SUPER + SHIFT + S",
    -- Drop the CTRL + SUPER + SHIFT + arrow alternates, keep the ALT + mouse/PageUp/PageDown ones
    kbMoveWinToWsNext = { "SUPER + ALT + mouse_down", "SUPER + ALT + Page_Down" },
    kbMoveWinToWsPrev = { "SUPER + ALT + mouse_up", "SUPER + ALT + Page_Up" },

    -- kbNextWs / kbPrevWs NOT overridden: upstream defaults already include
    -- SUPER + mouse_down/up, the old workaround for this is obsolete.
}
