pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

ShellRoot {
    id: root

    // ── Colors (populated from caelestia's scheme.json) ──────────────────────
    property color clBg:          "#131317"
    property color clSurface:     "#201f23"
    property color clSurfaceHigh: "#2a292e"
    property color clPrimary:     "#c2c1ff"
    property color clOnSurface:   "#e5e1e7"
    property color clOnSurfaceV:  "#c8c5d1"
    property color clOutline:     "#47464f"

    // ── State ─────────────────────────────────────────────────────────────────
    property string _buf:          ""
    property string current:       ""
    property int    currentTab:    0
    property string barMode:       "always"
    property string hoveredScheme: ""
    property bool   applying:      false

    // ── Effects state ─────────────────────────────────────────────────────────
    property string activeWindowAddr:  ""
    property string activeWindowClass: ""
    property bool   windowNoblur:      false  // true = blur OFF for this window
    property bool   windowOpaque:      false  // true = opacity 1.0 forced
    property bool   blurEnabled:       true
    property real   globalOpacity:     0.95
    property bool   applyingScheme:    false

    // ── Workspace config state ────────────────────────────────────────────────
    property string wsLabels:   "icons"   // "icons" | "numbers"
    property int    wsMaxIcons: -1        // -1=unlimited  0=hidden  1-N=limit
    property int    wsShown:    5
    property bool   wsApplying: false

    // Opacity presets 100%→0% de 10 en 10
    readonly property var opacityLevels: [
        { label: "100%", value: 1.00 },
        { label: "90%",  value: 0.90 },
        { label: "80%",  value: 0.80 },
        { label: "70%",  value: 0.70 },
        { label: "60%",  value: 0.60 },
        { label: "50%",  value: 0.50 },
        { label: "40%",  value: 0.40 },
        { label: "30%",  value: 0.30 },
        { label: "20%",  value: 0.20 },
        { label: "10%",  value: 0.10 },
        { label: "0%",   value: 0.00 },
    ]

    ListModel { id: wallModel }
    ListModel { id: gifModel }
    property string gifSlot: "session" // "session" | "media"
    property string currentSessionGif: ""
    property string currentMediaGif: ""

    // Guard against empty/short hex strings from scheme.json
    function c(hex) { return (hex && hex.length >= 6) ? "#" + hex.slice(-6) : "#888888" }

    // ── Scheme catalog ────────────────────────────────────────────────────────
    readonly property var schemes: [
        { name: "dynamic",    desc: "Adapts automatically to the dominant color of the current wallpaper." },
        { name: "caelestia",  desc: "Caelestia's official palette — soft purples and balanced contrast." },
        { name: "catppuccin", desc: "Pastel soft tones, very popular in the ricing / customization community." },
        { name: "dracula",    desc: "Deep dark background with vivid purple and pink accents." },
        { name: "everblush",  desc: "Green and rose tones, inspired by forest aesthetics." },
        { name: "everforest", desc: "Warm greens inspired by natural woodlands. Easy on the eyes." },
        { name: "gruvbox",    desc: "Retro warm palette with earthy tones and orange/yellow highlights." },
        { name: "nord",       desc: "Arctic minimalist style — cold blues, whites and muted tones." },
        { name: "oldworld",   desc: "Classic dark scheme inspired by vintage terminal color palettes." },
        { name: "onedark",    desc: "Based on Atom One Dark — balanced and widely loved by developers." },
        { name: "rosepine",   desc: "Soft rose and pine tones, elegant and romantic aesthetic." },
        { name: "tokyonight", desc: "Urban Japanese night vibes — deep blues and soft purples." },
        { name: "darkgreen",  desc: "Dark, muted greens — calm and low contrast." },
        { name: "shadotheme", desc: "Dark theme with soft, desaturated accents." },
        { name: "solarized",  desc: "Ethan Schoonover's classic precision palette — teal base, warm accents." },
    ]

    // ── Bar mode definitions ──────────────────────────────────────────────────
    readonly property var barModes: [
        { mode: "always", icon: "▐▐", title: "Always Visible",
          desc: "The bar stays visible at all times\nand reserves screen space." },
        { mode: "hover",  icon: "◁▐", title: "Show on Hover",
          desc: "Hidden by default, slides in\nwhen the mouse nears the left edge." },
        { mode: "hidden", icon: "▏ ", title: "Always Hidden",
          desc: "Completely hidden. Accessible\nby dragging from the left edge." },
    ]

    // ── Data loader ───────────────────────────────────────────────────────────
    Process {
        id: dataProc
        command: ["python3",
                  Qt.resolvedUrl("list_wallpapers.py").toString().replace("file://", "")]
        running: true

        stdout: SplitParser {
            onRead: data => root._buf += data + "\n"
        }

        onExited: {
            try {
                var d = JSON.parse(root._buf.trim())
                root.current = d.current || ""

                var bar = d.bar || {}
                if (bar.persistent === true)      root.barMode = "always"
                else if (bar.showOnHover === true) root.barMode = "hover"
                else                              root.barMode = "hidden"

                var cl = d.colors || {}
                if (cl.background)           root.clBg          = root.c(cl.background)
                if (cl.surfaceContainerHigh) root.clSurfaceHigh = root.c(cl.surfaceContainerHigh)
                if (cl.surfaceContainer)     root.clSurface     = root.c(cl.surfaceContainer)
                if (cl.primary)              root.clPrimary     = root.c(cl.primary)
                if (cl.onSurface)            root.clOnSurface   = root.c(cl.onSurface)
                if (cl.onSurfaceVariant)     root.clOnSurfaceV  = root.c(cl.onSurfaceVariant)
                if (cl.outlineVariant)       root.clOutline     = root.c(cl.outlineVariant)

                root.activeWindowAddr  = d.active_window_addr  || ""
                root.activeWindowClass = d.active_window_class || ""

                var wsConf  = d.workspace_config || {}
                var wsState = d.ws_state        || {}
                root.wsShown  = wsConf.shown || 5
                root.wsLabels = wsState.labels || "numbers"
                if (wsConf.showWindows === false)           root.wsMaxIcons = 0
                else if ((wsConf.maxWindowIcons || 0) > 0) root.wsMaxIcons = wsConf.maxWindowIcons
                else                                       root.wsMaxIcons = -1

                var walls = d.wallpapers || []
                for (var i = 0; i < walls.length; i++)
                    wallModel.append(walls[i])

                var idx = -1
                for (var j = 0; j < walls.length; j++) {
                    if (walls[j].path === root.current) { idx = j; break }
                }
                if (idx >= 0)
                    Qt.callLater(() => {
                        wallCarousel.currentIndex = idx
                        wallCarousel.positionViewAtIndex(idx, PathView.Center)
                    })

            } catch(e) { console.log("wallpaper-picker parse error:", e) }
        }
    }

    // Read current blur and opacity state on startup
    Process {
        id: loadBlurProc
        command: ["hyprctl", "getoption", "decoration:blur:enabled", "-j"]
        running: true
        property string _buf: ""
        stdout: SplitParser { onRead: data => loadBlurProc._buf += data }
        onExited: {
            try { root.blurEnabled = JSON.parse(loadBlurProc._buf.trim()).int === 1 } catch(e) {}
        }
    }

    Process {
        id: loadOpacityFromVarsProc
        command: ["lua5.4", Qt.resolvedUrl("read_window_opacity.lua").toString().replace("file://", "")]
        running: true
        property string _buf: ""
        stdout: SplitParser { onRead: data => loadOpacityFromVarsProc._buf += data }
        onExited: {
            try {
                var val = parseFloat(loadOpacityFromVarsProc._buf.trim())
                if (val > 0 && val <= 1.0) root.globalOpacity = Math.round(val * 100) / 100
            } catch(e) {}
        }
    }


    // ── Processes ─────────────────────────────────────────────────────────────
    Process {
        id: applyWall
        onExited: root.finish()
    }

    Process {
        id: applyScheme
        onExited: (code) => root.schemeApplied(code)
    }

    // ── Scheme palettes (from `caelestia scheme list`) ────────────────────────
    property var    schemePalettes:       ({})   // name -> { flavour -> colours }
    property var    schemeOrder:          []
    property string currentSchemeName:    ""
    property string currentSchemeFlavour: ""
    property var    flavourChoice:        ({})   // name -> flavour picked in the UI
    property var    pendingScheme:        null

    Process {
        id: schemeListProc
        command: ["caelestia", "scheme", "list"]
        running: true
        property string _buf: ""
        stdout: SplitParser { onRead: data => schemeListProc._buf += data }
        onExited: {
            try {
                var d = JSON.parse(schemeListProc._buf.trim())
                root.schemePalettes = d
                var names = Object.keys(d).filter(n => n !== "dynamic")
                root.schemeOrder = (d.dynamic ? ["dynamic"] : []).concat(names)
            } catch (e) { console.log("scheme list parse error:", e) }
        }
    }

    Process {
        id: schemeStateProc
        command: ["cat", Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"]
        running: true
        property string _buf: ""
        stdout: SplitParser { onRead: data => schemeStateProc._buf += data }
        onExited: {
            try {
                var d = JSON.parse(schemeStateProc._buf.trim())
                root.currentSchemeName    = d.name    || ""
                root.currentSchemeFlavour = d.flavour || ""
            } catch (e) {}
        }
    }

    // Flavour shown/applied when the user hasn't picked one: the active one for
    // the current scheme, otherwise a sensible dark default.
    function defaultFlavour(name) {
        var fl = Object.keys(root.schemePalettes[name] || {})
        if (name === root.currentSchemeName && fl.indexOf(root.currentSchemeFlavour) >= 0)
            return root.currentSchemeFlavour
        var pref = ["medium", "default", "main", "mocha"]
        for (var i = 0; i < pref.length; i++)
            if (fl.indexOf(pref[i]) >= 0) return pref[i]
        return fl[0] || ""
    }

    function setFlavour(name, flavour) {
        var c = Object.assign({}, root.flavourChoice)
        c[name] = flavour
        root.flavourChoice = c
    }

    function applySchemeChoice(name, flavour) {
        if (root.applyingScheme) return
        root.applyingScheme = true
        root.pendingScheme = { name: name, flavour: flavour }
        applyScheme.command = ["caelestia", "scheme", "set", "-n", name, "-f", flavour]
        applyScheme.running = true
    }

    function setColorsFrom(cl) {
        if (cl.background)           root.clBg          = root.c(cl.background)
        if (cl.surfaceContainerHigh) root.clSurfaceHigh = root.c(cl.surfaceContainerHigh)
        if (cl.surfaceContainer)     root.clSurface     = root.c(cl.surfaceContainer)
        if (cl.primary)              root.clPrimary     = root.c(cl.primary)
        if (cl.onSurface)            root.clOnSurface   = root.c(cl.onSurface)
        if (cl.onSurfaceVariant)     root.clOnSurfaceV  = root.c(cl.onSurfaceVariant)
        if (cl.outlineVariant)       root.clOutline     = root.c(cl.outlineVariant)
    }

    // After applying: mark it current and recolour the picker itself live
    function schemeApplied(code) {
        root.applyingScheme = false
        if (code !== 0 || !root.pendingScheme) return
        var p = root.pendingScheme
        root.currentSchemeName    = p.name
        root.currentSchemeFlavour = p.flavour
        root.setColorsFrom(((root.schemePalettes[p.name] || {})[p.flavour]) || {})
        root.pendingScheme = null
    }

    Process {
        id: setBarMode
        onExited: shellRestart.running = true
    }

    Process {
        id: setGifProc
        onExited: shellRestart.running = true
    }

    function openFolder(path) {
        // execDetached (not a QML Process) so thunar survives after this
        // overlay closes, and we close right away so thunar isn't left
        // behind our WlrLayer.Overlay panel.
        Quickshell.execDetached(["thunar", path])
        Qt.quit()
    }

    Process {
        id: loadGifsProc
        command: ["python3", Qt.resolvedUrl("list_gifs.py").toString().replace("file://", "")]
        running: true
        property string _buf: ""
        stdout: SplitParser { onRead: data => loadGifsProc._buf += data }
        onExited: {
            try {
                var d = JSON.parse(loadGifsProc._buf.trim())
                root.currentSessionGif = d.currentSession || ""
                root.currentMediaGif = d.currentMedia || ""
                var gifs = d.gifs || []
                for (var i = 0; i < gifs.length; i++)
                    gifModel.append(gifs[i])

                var cur = root.gifSlot === "session" ? root.currentSessionGif : root.currentMediaGif
                for (var j = 0; j < gifs.length; j++) {
                    if (gifs[j].path === cur) {
                        var gi = j
                        Qt.callLater(() => {
                            gifCarousel.currentIndex = gi
                            gifCarousel.positionViewAtIndex(gi, PathView.Center)
                        })
                        break
                    }
                }
            } catch (e) {}
        }
    }

    Process {
        id: setWsConfig
        onExited: shellRestart.running = true
    }

    Process {
        id: shellRestart
        command: ["/bin/bash", "-c", "caelestia shell -k && sleep 1 && caelestia shell -d"]
        onExited: root.finish()
    }

    // Effects processes
    // Global blur — hyprctl keyword decoration:blur:enabled true/false
    Process {
        id: toggleGlobalBlurProc
        onExited: root.blurEnabled = !root.blurEnabled
    }

    // Global opacity — hyprctl --batch to set active + inactive together
    Process { id: setGlobalOpacityProc }

    // Per-window opacity — adds a windowrule for the captured class (stacks, last match wins)
    // Hyprland 0.55: setprop and toggleopaque are not available, windowrule keyword is the only option
    Process {
        id: setWindowOpaqueProc
        onExited: root.windowOpaque = !root.windowOpaque
    }

    // Per-window blur — adds a windowrule no_blur true/false for the captured class
    Process {
        id: setWindowBlurProc
        onExited: root.windowNoblur = !root.windowNoblur
    }


    // ── Carousel apply flow ───────────────────────────────────────────────────
    property bool   carouselApplying: false
    property double applyStartedAt:   0

    function applyWallpaper(path) {
        if (root.carouselApplying) return
        root.carouselApplying = true
        root.applyStartedAt = Date.now()
        root.current = path
        applyWall.command = ["caelestia", "wallpaper", "-f", path]
        applyWall.running = true
    }

    function applyGif(path) {
        if (root.carouselApplying) return
        root.carouselApplying = true
        root.applyStartedAt = Date.now()
        if (root.gifSlot === "session") root.currentSessionGif = path
        else                            root.currentMediaGif   = path
        setGifProc.command = [
            "python3",
            Qt.resolvedUrl("set_gif.py").toString().replace("file://", ""),
            root.gifSlot,
            path
        ]
        setGifProc.running = true
    }

    // Let the apply animation play for at least ~0.9s, then fade out and quit
    function finish() {
        closeTimer.interval = Math.max(1, 900 - (Date.now() - root.applyStartedAt))
        closeTimer.start()
    }
    Timer { id: closeTimer; onTriggered: stageOut.start() }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (!root.carouselApplying) Qt.quit()
            event.accepted = true
            return
        }
        if (root.carouselApplying) { event.accepted = true; return }

        var pv = root.currentTab === 0 ? wallCarousel
               : root.currentTab === 4 ? gifCarousel : null
        if (!pv) return

        switch (event.key) {
        case Qt.Key_Left:
            pv.decrementCurrentIndex(); event.accepted = true; break
        case Qt.Key_Right:
            pv.incrementCurrentIndex(); event.accepted = true; break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            pv.activateCurrent(); event.accepted = true; break
        case Qt.Key_Up:
        case Qt.Key_Down:
            if (root.currentTab === 4) {
                root.gifSlot = root.gifSlot === "session" ? "media" : "session"
                event.accepted = true
            }
            break
        }
    }

    // ── Infinite carousel with skewed (parallelogram) tiles ──────────────────
    // Used by the Wallpaper and GIFs tabs. Inline components can't see ids of
    // the outer file, so colours/state come in as properties.
    component SkewCarousel: PathView {
        id: pv

        property bool   animated:   false   // true → AnimatedImage (GIFs)
        property bool   applying:   false
        property string activePath: ""      // item currently in use (✓ badge)
        property color  accent:     "#c2c1ff"
        property color  surface:    "#2a292e"
        property color  badgeText:   "#131317"
        signal activated(string path)

        // Tile geometry: taller than wide, top edge shifted right (/ /)
        readonly property real tileH: Math.min(height * 0.9, 560)
        readonly property real tileW: tileH * 0.62
        readonly property real skew:  tileW * 0.24
        readonly property real step:  tileW * 0.86
        readonly property real span:  step * pathItemCount
        readonly property real near:  Math.min(step, span / 2 - 1)

        function activateCurrent() { if (currentItem) activated(currentItem.path) }

        pathItemCount:           Math.max(1, Math.min(count, 9))
        preferredHighlightBegin: 0.5
        preferredHighlightEnd:   0.5
        highlightRangeMode:      PathView.StrictlyEnforceRange
        snapMode:                PathView.SnapOneItem
        highlightMoveDuration:   320
        interactive:             !applying
        cacheItemCount:          4

        // Mouse wheel / touchpad: one step per notch (accumulated for touchpads)
        property real _wheelAcc: 0
        WheelHandler {
            enabled: !pv.applying
            onWheel: (event) => {
                pv._wheelAcc += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                while (pv._wheelAcc <= -120) { pv.incrementCurrentIndex(); pv._wheelAcc += 120 }
                while (pv._wheelAcc >=  120) { pv.decrementCurrentIndex(); pv._wheelAcc -= 120 }
            }
        }

        path: Path {
            startX: pv.width / 2 - pv.span / 2; startY: pv.height / 2
            PathAttribute { name: "itemScale";   value: 0.55 }
            PathAttribute { name: "itemOpacity"; value: 0.10 }
            PathAttribute { name: "itemZ";       value: 0 }
            PathLine { x: pv.width / 2 - pv.near; y: pv.height / 2 }
            PathAttribute { name: "itemScale";   value: 0.80 }
            PathAttribute { name: "itemOpacity"; value: 0.80 }
            PathAttribute { name: "itemZ";       value: 5 }
            PathLine { x: pv.width / 2; y: pv.height / 2 }
            PathAttribute { name: "itemScale";   value: 1.0 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathAttribute { name: "itemZ";       value: 10 }
            PathLine { x: pv.width / 2 + pv.near; y: pv.height / 2 }
            PathAttribute { name: "itemScale";   value: 0.80 }
            PathAttribute { name: "itemOpacity"; value: 0.80 }
            PathAttribute { name: "itemZ";       value: 5 }
            PathLine { x: pv.width / 2 + pv.span / 2; y: pv.height / 2 }
            PathAttribute { name: "itemScale";   value: 0.55 }
            PathAttribute { name: "itemOpacity"; value: 0.10 }
            PathAttribute { name: "itemZ";       value: 0 }
        }

        delegate: Item {
            id: tile
            required property string path
            required property string name
            required property int    index

            readonly property bool isCur:    PathView.isCurrentItem
            readonly property bool isActive: path === pv.activePath

            property real boost: 1      // apply "pop"
            property real glow:  0.55   // outline glow strength
            property real fade:  (pv.applying && !isCur) ? 0 : 1
            Behavior on fade { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

            width:   pv.tileW
            height:  pv.tileH
            z:       PathView.itemZ !== undefined ? PathView.itemZ : 0
            scale:   (PathView.itemScale !== undefined ? PathView.itemScale : 1) * boost
            opacity: (PathView.itemOpacity !== undefined ? PathView.itemOpacity : 1) * fade

            // Parallelogram mask
            Shape {
                id: maskShape
                anchors.fill: parent
                visible: false
                layer.enabled: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "white"; strokeColor: "transparent"; strokeWidth: 0
                    startX: pv.skew; startY: 0
                    PathLine { x: tile.width;           y: 0 }
                    PathLine { x: tile.width - pv.skew; y: tile.height }
                    PathLine { x: 0;                    y: tile.height }
                    PathLine { x: pv.skew;              y: 0 }
                }
            }

            Item {
                id: content
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled:      true
                    maskSource:       maskShape
                    maskThresholdMin: 0.5
                    maskSpreadAtMin:  1.0
                }

                Rectangle { anchors.fill: parent; color: pv.surface }

                Image {
                    anchors.fill: parent
                    visible: !pv.animated
                    source: pv.animated ? "" : "file://" + tile.path
                    sourceSize.height: 900
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; smooth: true; mipmap: true
                }

                AnimatedImage {
                    anchors.fill: parent
                    visible: pv.animated
                    source: pv.animated ? "file://" + tile.path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    playing: tile.isCur
                }

                // Dim everything but the centre tile
                Rectangle {
                    anchors.fill: parent; color: "black"
                    opacity: tile.isCur ? 0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }

                Rectangle { id: flash; anchors.fill: parent; color: "white"; opacity: 0 }
            }

            // Outline (+ glow on the centre tile)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                layer.enabled: tile.isCur
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: pv.accent
                    shadowBlur: 1.0
                    blurMax: 40
                    shadowOpacity: tile.glow
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: tile.isCur    ? pv.accent
                               : tile.isActive ? Qt.alpha(pv.accent, 0.55) : "#1affffff"
                    strokeWidth: tile.isCur ? 3 : 1.5
                    joinStyle: ShapePath.MiterJoin
                    startX: pv.skew; startY: 0
                    PathLine { x: tile.width;           y: 0 }
                    PathLine { x: tile.width - pv.skew; y: tile.height }
                    PathLine { x: 0;                    y: tile.height }
                    PathLine { x: pv.skew;              y: 0 }
                }
            }

            // ✓ badge for the item currently in use
            Rectangle {
                visible: tile.isActive
                x: tile.width - 48; y: 16
                width: 24; height: 24; radius: 12
                color: pv.accent
                Text {
                    anchors.centerIn: parent
                    text: "✓"; font.pixelSize: 12; font.weight: Font.Bold
                    color: pv.badgeText
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !pv.applying
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (tile.isCur) pv.activated(tile.path)
                    else            pv.currentIndex = tile.index
                }
            }

            // Apply animation: pop + flash, then a pulsing glow until we close
            SequentialAnimation {
                id: applyAnim
                ParallelAnimation {
                    NumberAnimation { target: tile; property: "boost"; to: 1.1; duration: 420; easing.type: Easing.OutBack }
                    SequentialAnimation {
                        NumberAnimation { target: flash; property: "opacity"; to: 0.55; duration: 110 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0;    duration: 450; easing.type: Easing.OutCubic }
                    }
                }
                SequentialAnimation {
                    loops: Animation.Infinite
                    NumberAnimation { target: tile; property: "glow"; to: 1.0;  duration: 450; easing.type: Easing.InOutSine }
                    NumberAnimation { target: tile; property: "glow"; to: 0.35; duration: 450; easing.type: Easing.InOutSine }
                }
            }
            Connections {
                target: pv
                function onApplyingChanged() { if (pv.applying && tile.isCur) applyAnim.start() }
            }
        }
    }

    // ── Overlay window ────────────────────────────────────────────────────────
    PanelWindow {
        id: overlay
        visible: true

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace:     "wallpaper-picker"
        WlrLayershell.exclusiveZone: -1

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Item {
            id: stage
            anchors.fill: parent
            opacity: 0
            NumberAnimation on opacity { running: true; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation {
                id: stageOut
                target: stage; property: "opacity"; to: 0
                duration: 260; easing.type: Easing.InCubic
                onFinished: Qt.quit()
            }

            // En la pestaña Widgets el fondo se aclara para ver el reloj real cambiar
            Rectangle {
                anchors.fill: parent
                color: root.currentTab === 5 ? "#66000000" : "#d9000000"
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Click on empty space closes; also owns keyboard focus
            MouseArea {
                anchors.fill: parent
                focus: true
                onClicked: if (!root.carouselApplying) Qt.quit()
                Keys.onPressed: (event) => root.handleKey(event)
            }

            // ── Floating header: title + tabs ─────────────────────────────────
            Rectangle {
                id: header
                anchors { top: parent.top; topMargin: 36; horizontalCenter: parent.horizontalCenter }
                width:  headerRow.implicitWidth + 24
                height: 66
                radius: 33
                color: Qt.alpha(root.clBg, 0.94)
                border.color: Qt.alpha(root.clOutline, 0.45); border.width: 1

                MouseArea { anchors.fill: parent; onClicked: {} }

                RowLayout {
                    id: headerRow
                    anchors.centerIn: parent
                    spacing: 8

                    Item { width: 6 }
                    Rectangle { width: 8; height: 8; radius: 4; color: root.clPrimary }
                    Text {
                        text: "Appearance"
                        font.pixelSize: 17; font.weight: Font.Medium
                        color: root.clOnSurface
                    }
                    Item { width: 10 }

                    Repeater {
                        model: ["Wallpaper", "Color Scheme", "Bar", "Effects", "GIFs", "Widgets"]

                        Rectangle {
                            id: tabRect
                            property bool isActive: index === root.currentTab
                            property bool hov: tabMa.containsMouse
                            height: 48
                            width: tabTxt.implicitWidth + 40
                            radius: 24
                            color: isActive ? Qt.alpha(root.clPrimary, 0.20)
                                           : hov ? Qt.alpha(root.clPrimary, 0.08) : "transparent"
                            border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.40)
                            border.width: 1
                            Behavior on color        { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            Text {
                                id: tabTxt
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 15
                                font.weight: tabRect.isActive ? Font.Medium : Font.Normal
                                color: tabRect.isActive ? root.clPrimary : root.clOnSurfaceV
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.carouselApplying
                                onClicked: root.currentTab = index
                            }
                        }
                    }

                    Item { width: 6 }

                    // Open folder (Wallpaper / GIFs only)
                    Rectangle {
                        visible: root.currentTab === 0 || root.currentTab === 4
                        height: 48
                        width: folderTxt.implicitWidth + 36
                        radius: 24
                        color: folderMa.containsMouse ? Qt.alpha(root.clPrimary, 0.15) : "transparent"
                        border.color: Qt.alpha(root.clOutline, 0.40); border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: folderTxt
                            anchors.centerIn: parent
                            text: "📁  Carpeta"
                            font.pixelSize: 14
                            color: root.clOnSurfaceV
                        }
                        MouseArea {
                            id: folderMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openFolder(Quickshell.env("HOME")
                                + (root.currentTab === 4 ? "/Pictures/gifs" : "/Pictures/wallpapers"))
                        }
                    }

                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: xBtn.containsMouse ? Qt.alpha(root.clPrimary, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 16; color: root.clOnSurfaceV }
                        MouseArea { id: xBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                    }
                    Item { width: 2 }
                }
            }

            // ── Full-width carousels (Wallpaper / GIFs) ───────────────────────
            Item {
                id: carouselArea
                anchors {
                    top: header.bottom; topMargin: 12
                    bottom: parent.bottom; bottomMargin: 28
                    left: parent.left; right: parent.right
                }
                visible: root.currentTab === 0 || root.currentTab === 4

                SkewCarousel {
                    id: wallCarousel
                    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: info.top; bottomMargin: 6 }
                    visible: root.currentTab === 0
                    model: wallModel
                    activePath: root.current
                    applying: root.carouselApplying
                    accent: root.clPrimary; surface: root.clSurfaceHigh; badgeText: root.clBg
                    onActivated: (path) => root.applyWallpaper(path)
                }

                SkewCarousel {
                    id: gifCarousel
                    anchors { top: parent.top; left: parent.left; right: parent.right; bottom: info.top; bottomMargin: 6 }
                    visible: root.currentTab === 4
                    animated: true
                    model: gifModel
                    activePath: root.gifSlot === "session" ? root.currentSessionGif : root.currentMediaGif
                    applying: root.carouselApplying
                    accent: root.clPrimary; surface: root.clSurfaceHigh; badgeText: root.clBg
                    onActivated: (path) => root.applyGif(path)
                }

                Column {
                    id: info
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    spacing: 12

                    // GIF target slot
                    Row {
                        visible: root.currentTab === 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Aplicar a"
                            font.pixelSize: 13
                            color: root.clOnSurfaceV
                            rightPadding: 4
                        }
                        Repeater {
                            model: [
                                { id: "session", label: "Panel de sesión" },
                                { id: "media",   label: "Reproduciendo música" },
                            ]
                            Rectangle {
                                required property var modelData
                                property bool isActive: root.gifSlot === modelData.id
                                height: 40
                                width: slotTxt.implicitWidth + 36
                                radius: 20
                                color: isActive ? Qt.alpha(root.clPrimary, 0.20) : Qt.alpha(root.clBg, 0.6)
                                border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.40)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: slotTxt
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: 14
                                    color: parent.isActive ? root.clPrimary : root.clOnSurfaceV
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.carouselApplying
                                    onClicked: root.gifSlot = parent.modelData.id
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        property var cur: (root.currentTab === 4 ? gifCarousel : wallCarousel).currentItem
                        text: cur ? cur.name.replace(/_/g, " ") : ""
                        font.pixelSize: 19; font.weight: Font.Medium
                        color: root.clOnSurface
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.carouselApplying ? "Aplicando…"
                            : root.currentTab === 4 ? "←  →  mover      ↑ ↓  destino      ⏎  aplicar      esc  cerrar"
                            :                         "←  →  mover      ⏎  aplicar      esc  cerrar"
                        font.pixelSize: 13; font.letterSpacing: 0.5
                        color: root.carouselApplying ? root.clPrimary : Qt.alpha(root.clOnSurfaceV, 0.75)
                        SequentialAnimation on opacity {
                            running: root.carouselApplying
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 450 }
                            NumberAnimation { to: 1.0;  duration: 450 }
                        }
                    }
                }
            }

            // ── TAB 5: Widgets (se carga solo mientras está abierta) ──────────
            Rectangle {
                id: widgetsCard
                visible: root.currentTab === 5
                anchors { top: header.bottom; topMargin: 20; horizontalCenter: parent.horizontalCenter }
                width:  Math.min(parent.width * 0.84, 920)
                height: Math.min(parent.height - header.height - 36 - 20 - 36, 660)
                radius: 20
                color:  Qt.alpha(root.clBg, 0.96)

                MouseArea { anchors.fill: parent; onClicked: {} }

                Loader {
                    anchors.fill: parent
                    anchors.margins: 28
                    active: root.currentTab === 5
                    source: "WidgetsTab.qml"
                    onLoaded: {
                        item.cBg = Qt.binding(() => root.clBg)
                        item.cSurface = Qt.binding(() => root.clSurface)
                        item.cSurfaceHigh = Qt.binding(() => root.clSurfaceHigh)
                        item.cPrimary = Qt.binding(() => root.clPrimary)
                        item.cText = Qt.binding(() => root.clOnSurface)
                        item.cTextV = Qt.binding(() => root.clOnSurfaceV)
                        item.cOutline = Qt.binding(() => root.clOutline)
                    }
                }
            }

            // ── Card for the other tabs (Color Scheme / Bar / Effects) ────────
            Rectangle {
                id: card
                visible: root.currentTab >= 1 && root.currentTab <= 3
                anchors { top: header.bottom; topMargin: 20; horizontalCenter: parent.horizontalCenter }
                width:  Math.min(parent.width * 0.84, 920)
                height: Math.min(parent.height - header.height - 36 - 20 - 36, 660)
                radius: 20
                color:  root.clBg

                MouseArea { anchors.fill: parent; onClicked: {} }

                Item {
                    anchors.fill: parent
                    anchors.margins: 28

                    // ── TAB 1: Color scheme ───────────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 14
                        visible: root.currentTab === 1
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            text: "COLOR SCHEME"
                            font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                            color: root.clPrimary
                        }

                        // Description / status bar
                        Rectangle {
                            Layout.fillWidth: true; height: 52; radius: 14
                            color: root.applyingScheme ? Qt.alpha(root.clPrimary, 0.08) : Qt.alpha(root.clSurface, 0.9)
                            border.color: root.applyingScheme ? Qt.alpha(root.clPrimary, 0.4) : Qt.alpha(root.clOutline, 0.35)
                            border.width: 1
                            Behavior on color        { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            Text {
                                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 16 }
                                text: {
                                    if (root.applyingScheme) return "Applying scheme…"
                                    if (root.hoveredScheme === "") return "Hover over a scheme to see a description — click to apply"
                                    var s = root.schemes.find(x => x.name === root.hoveredScheme)
                                    return "● " + root.hoveredScheme + "  —  " + (s ? s.desc : "")
                                }
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                color: root.applyingScheme ? root.clPrimary : root.clOnSurfaceV
                            }
                        }

                        // Scheme cards — each one painted with its own palette
                        GridView {
                            id: schemeGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            cellWidth:  Math.floor(width / 3)
                            cellHeight: 136
                            model: root.schemeOrder
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Item {
                                id: sc
                                required property string modelData
                                readonly property string name:     modelData
                                readonly property var    flavours: Object.keys(root.schemePalettes[name] || {})
                                readonly property string flavour:  root.flavourChoice[name] || root.defaultFlavour(name)
                                readonly property var    pal:      (root.schemePalettes[name] || {})[flavour] || {}
                                readonly property bool   isCurrent: name === root.currentSchemeName
                                                                 && flavour === root.currentSchemeFlavour

                                width: schemeGrid.cellWidth
                                height: schemeGrid.cellHeight

                                Rectangle {
                                    id: scCard
                                    anchors { fill: parent; margins: 7 }
                                    radius: 18
                                    property bool hov: scMa.containsMouse
                                    color: root.c(sc.pal.background)
                                    border.color: sc.isCurrent ? root.c(sc.pal.primary)
                                                : hov ? Qt.alpha(root.c(sc.pal.primary), 0.7)
                                                : Qt.alpha(root.c(sc.pal.outline), 0.45)
                                    border.width: sc.isCurrent ? 2 : 1
                                    scale: hov && !root.applyingScheme ? 1.03 : 1
                                    opacity: root.applyingScheme && !sc.isCurrent ? 0.55 : 1
                                    Behavior on scale        { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    Behavior on opacity      { NumberAnimation { duration: 160 } }
                                    Behavior on color        { ColorAnimation  { duration: 160 } }
                                    Behavior on border.color { ColorAnimation  { duration: 140 } }

                                    MouseArea {
                                        id: scMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !root.applyingScheme
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.hoveredScheme = sc.name
                                        onExited:  if (root.hoveredScheme === sc.name) root.hoveredScheme = ""
                                        onClicked: root.applySchemeChoice(sc.name, sc.flavour)
                                    }

                                    ColumnLayout {
                                        anchors { fill: parent; margins: 14 }
                                        spacing: 9

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: sc.name
                                                font.pixelSize: 15; font.weight: Font.Medium
                                                color: root.c(sc.pal.onSurface)
                                            }
                                            Text {
                                                visible: sc.flavours.length <= 1 && sc.flavour !== "default"
                                                text: sc.flavour
                                                font.pixelSize: 11
                                                color: root.c(sc.pal.onSurfaceVariant)
                                            }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                visible: sc.isCurrent
                                                width: 22; height: 22; radius: 11
                                                color: root.c(sc.pal.primary)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✓"; font.pixelSize: 11; font.weight: Font.Bold
                                                    color: root.c(sc.pal.onPrimary)
                                                }
                                            }
                                        }

                                        // Palette swatches
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Repeater {
                                                model: ["primary", "secondary", "tertiary", "error", "surfaceContainerHighest"]
                                                Rectangle {
                                                    required property string modelData
                                                    Layout.fillWidth: true
                                                    height: 22; radius: 11
                                                    color: root.c(sc.pal[modelData])
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }

                                        // Flavour pills (only for schemes with more than one)
                                        Row {
                                            visible: sc.flavours.length > 1
                                            spacing: 5
                                            Repeater {
                                                model: sc.flavours
                                                Rectangle {
                                                    required property string modelData
                                                    property bool active: modelData === sc.flavour
                                                    height: 22
                                                    width: flTxt.implicitWidth + 16
                                                    radius: 11
                                                    color: active ? Qt.alpha(root.c(sc.pal.primary), 0.25) : "transparent"
                                                    border.color: active ? root.c(sc.pal.primary) : Qt.alpha(root.c(sc.pal.outline), 0.6)
                                                    border.width: 1
                                                    Text {
                                                        id: flTxt
                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        font.pixelSize: 11
                                                        color: parent.active ? root.c(sc.pal.primary) : root.c(sc.pal.onSurfaceVariant)
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: !root.applyingScheme
                                                        cursorShape: Qt.PointingHandCursor
                                                        onEntered: root.hoveredScheme = sc.name
                                                        onClicked: root.setFlavour(sc.name, parent.modelData)
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }
                        }
                    }

                    // ── TAB 2: Bar behavior ───────────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12
                        visible: root.currentTab === 2
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            text: "LEFT BAR BEHAVIOR"
                            font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                            color: root.clPrimary
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 12

                            Repeater {
                                model: root.barModes

                                Rectangle {
                                    id: modeCard
                                    Layout.fillWidth: true; height: 130; radius: 14
                                    property bool isActive: modelData.mode === root.barMode
                                    property bool hov: modeMa.containsMouse && !root.applying

                                    color: isActive ? Qt.alpha(root.clPrimary, 0.13)
                                                   : hov ? Qt.alpha(root.clSurface, 0.9) : Qt.alpha(root.clSurface, 0.5)
                                    border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.35)
                                    border.width: isActive ? 2 : 1
                                    Behavior on color       { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Column {
                                        anchors.centerIn: parent; spacing: 8
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.icon; font.pixelSize: 24; font.family: "monospace"
                                            color: modeCard.isActive ? root.clPrimary : root.clOnSurfaceV
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title; font.pixelSize: 13; font.weight: Font.Medium
                                            color: modeCard.isActive ? root.clPrimary : root.clOnSurface
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.desc; font.pixelSize: 11
                                            color: Qt.alpha(root.clOnSurfaceV, 0.75)
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    Rectangle {
                                        anchors { top: parent.top; right: parent.right; margins: 10 }
                                        width: 8; height: 8; radius: 4; color: root.clPrimary
                                        visible: modeCard.isActive
                                    }

                                    MouseArea {
                                        id: modeMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: root.applying ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        enabled: !root.applying
                                        onClicked: {
                                            if (modelData.mode === root.barMode) return
                                            root.barMode = modelData.mode
                                            root.applying = true
                                            setBarMode.command = [
                                                "python3",
                                                Qt.resolvedUrl("set_bar_mode.py").toString().replace("file://", ""),
                                                modelData.mode
                                            ]
                                            setBarMode.running = true
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: infoText.implicitHeight + 20; radius: 10
                            color: root.applying ? Qt.alpha(root.clPrimary, 0.08) : Qt.alpha(root.clSurface, 0.45)
                            border.color: root.applying ? Qt.alpha(root.clPrimary, 0.4) : Qt.alpha(root.clOutline, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                id: infoText
                                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 16 }
                                text: root.applying
                                    ? "Restarting bar… the picker will close automatically."
                                    : "Changing bar mode restarts the shell (~1 s). Other panels cannot be repositioned — their positions are fixed in caelestia's system files."
                                font.pixelSize: 11
                                color: root.applying ? root.clPrimary : Qt.alpha(root.clOnSurfaceV, 0.60)
                                wrapMode: Text.WordWrap
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        // ── Divider ───────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true; height: 1
                            color: Qt.alpha(root.clOutline, 0.30)
                        }

                        // ── Workspaces ────────────────────────────────────────
                        Text {
                            text: "WORKSPACES"
                            font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                            color: root.clPrimary
                        }

                        // Label style: Icons vs Numbers
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12

                            Repeater {
                                model: [
                                    { id: "icons",   title: "Icons",   preview: "● ◉ ○" },
                                    { id: "numbers", title: "Numbers", preview: "1  2  3" }
                                ]

                                Rectangle {
                                    id: wsLabelCard
                                    Layout.fillWidth: true; height: 72; radius: 14
                                    property bool isActive: root.wsLabels === modelData.id
                                    property bool hov: wsLabelMa.containsMouse && !root.wsApplying
                                    color: isActive ? Qt.alpha(root.clPrimary, 0.13)
                                                   : hov ? Qt.alpha(root.clSurface, 0.9) : Qt.alpha(root.clSurface, 0.5)
                                    border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.35)
                                    border.width: isActive ? 2 : 1
                                    Behavior on color       { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Column {
                                        anchors.centerIn: parent; spacing: 5
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title; font.pixelSize: 13; font.weight: Font.Medium
                                            color: wsLabelCard.isActive ? root.clPrimary : root.clOnSurface
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.preview; font.pixelSize: 11
                                            color: Qt.alpha(root.clOnSurfaceV, 0.75)
                                        }
                                    }

                                    Rectangle {
                                        anchors { top: parent.top; right: parent.right; margins: 10 }
                                        width: 8; height: 8; radius: 4; color: root.clPrimary
                                        visible: wsLabelCard.isActive
                                    }

                                    MouseArea {
                                        id: wsLabelMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: root.wsApplying ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        enabled: !root.wsApplying
                                        onClicked: {
                                            if (root.wsLabels === modelData.id) return
                                            root.wsLabels = modelData.id
                                            root.wsApplying = true
                                            setWsConfig.command = [
                                                "python3",
                                                Qt.resolvedUrl("set_workspace_config.py").toString().replace("file://", ""),
                                                "--labels", modelData.id
                                            ]
                                            setWsConfig.running = true
                                        }
                                    }
                                }
                            }
                        }

                        // App icons per workspace
                        Rectangle {
                            Layout.fillWidth: true
                            height: wsIconsCol.implicitHeight + 20; radius: 12
                            color: Qt.alpha(root.clSurface, 0.5)
                            border.color: Qt.alpha(root.clOutline, 0.35); border.width: 1

                            Column {
                                id: wsIconsCol
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                                spacing: 10

                                RowLayout {
                                    width: parent.width
                                    Text { text: "App icons per workspace"; font.pixelSize: 13; font.weight: Font.Medium; color: root.clOnSurface }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.wsMaxIcons === 0 ? "hidden" : root.wsMaxIcons === -1 ? "∞" : root.wsMaxIcons.toString()
                                        font.pixelSize: 13; font.weight: Font.Medium; color: root.clPrimary
                                    }
                                }

                                Row {
                                    width: parent.width; spacing: 6

                                    Repeater {
                                        model: [
                                            { label: "0", value: 0  },
                                            { label: "1", value: 1  },
                                            { label: "2", value: 2  },
                                            { label: "3", value: 3  },
                                            { label: "5", value: 5  },
                                            { label: "∞", value: -1 }
                                        ]

                                        Rectangle {
                                            property bool isActive: root.wsMaxIcons === modelData.value
                                            property bool hov: wsIconMa.containsMouse && !root.wsApplying
                                            width: (wsIconsCol.width - 5 * 6) / 6
                                            height: 30; radius: 8
                                            color: isActive ? Qt.alpha(root.clPrimary, 0.22)
                                                           : hov ? Qt.alpha(root.clSurface, 0.9) : Qt.alpha(root.clSurfaceHigh, 0.6)
                                            border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.35)
                                            border.width: isActive ? 2 : 1
                                            Behavior on color       { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label; font.pixelSize: 12
                                                font.weight: isActive ? Font.Medium : Font.Normal
                                                color: isActive ? root.clPrimary : root.clOnSurfaceV
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                            }

                                            MouseArea {
                                                id: wsIconMa
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: root.wsApplying ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                enabled: !root.wsApplying
                                                onClicked: {
                                                    if (root.wsMaxIcons === modelData.value) return
                                                    root.wsMaxIcons = modelData.value
                                                    root.wsApplying = true
                                                    setWsConfig.command = [
                                                        "python3",
                                                        Qt.resolvedUrl("set_workspace_config.py").toString().replace("file://", ""),
                                                        "--max-icons", modelData.value.toString()
                                                    ]
                                                    setWsConfig.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Workspaces shown
                        Rectangle {
                            Layout.fillWidth: true
                            height: wsShownCol.implicitHeight + 20; radius: 12
                            color: Qt.alpha(root.clSurface, 0.5)
                            border.color: Qt.alpha(root.clOutline, 0.35); border.width: 1

                            Column {
                                id: wsShownCol
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                                spacing: 10

                                RowLayout {
                                    width: parent.width
                                    Text { text: "Workspaces shown"; font.pixelSize: 13; font.weight: Font.Medium; color: root.clOnSurface }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.wsShown.toString()
                                        font.pixelSize: 13; font.weight: Font.Medium; color: root.clPrimary
                                    }
                                }

                                Row {
                                    width: parent.width; spacing: 6

                                    Repeater {
                                        model: [3, 4, 5, 6, 7, 8, 10]

                                        Rectangle {
                                            property bool isActive: root.wsShown === modelData
                                            property bool hov: wsShownMa.containsMouse && !root.wsApplying
                                            width: (wsShownCol.width - 6 * 6) / 7
                                            height: 30; radius: 8
                                            color: isActive ? Qt.alpha(root.clPrimary, 0.22)
                                                           : hov ? Qt.alpha(root.clSurface, 0.9) : Qt.alpha(root.clSurfaceHigh, 0.6)
                                            border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.35)
                                            border.width: isActive ? 2 : 1
                                            Behavior on color       { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.toString(); font.pixelSize: 12
                                                font.weight: isActive ? Font.Medium : Font.Normal
                                                color: isActive ? root.clPrimary : root.clOnSurfaceV
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                            }

                                            MouseArea {
                                                id: wsShownMa
                                                anchors.fill: parent; hoverEnabled: true
                                                cursorShape: root.wsApplying ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                enabled: !root.wsApplying
                                                onClicked: {
                                                    if (root.wsShown === modelData) return
                                                    root.wsShown = modelData
                                                    root.wsApplying = true
                                                    setWsConfig.command = [
                                                        "python3",
                                                        Qt.resolvedUrl("set_workspace_config.py").toString().replace("file://", ""),
                                                        "--shown", modelData.toString()
                                                    ]
                                                    setWsConfig.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Info
                        Rectangle {
                            Layout.fillWidth: true
                            height: wsInfoText.implicitHeight + 20; radius: 10
                            color: root.wsApplying ? Qt.alpha(root.clPrimary, 0.08) : Qt.alpha(root.clSurface, 0.45)
                            border.color: root.wsApplying ? Qt.alpha(root.clPrimary, 0.4) : Qt.alpha(root.clOutline, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                id: wsInfoText
                                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 16 }
                                text: root.wsApplying
                                    ? "Restarting bar… the picker will close automatically."
                                    : "Workspace changes restart the shell (~1 s)."
                                font.pixelSize: 11
                                color: root.wsApplying ? root.clPrimary : Qt.alpha(root.clOnSurfaceV, 0.60)
                                wrapMode: Text.WordWrap
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ── TAB 3: Effects ────────────────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 14
                        visible: root.currentTab === 3
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        /* ── Active window (disabled — per-window toggle not reliable in Hyprland 0.55) ──
                        Text {
                            text: "ACTIVE WINDOW"
                            ...
                        }
                        ── end active window ── */

                        // ── Global effects ────────────────────────────────────
                        Text {
                            text: "GLOBAL EFFECTS"
                            font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                            color: root.clPrimary
                        }

                        // Global blur toggle row
                        Rectangle {
                            Layout.fillWidth: true; height: 56; radius: 12
                            color: Qt.alpha(root.clSurface, 0.5)
                            border.color: Qt.alpha(root.clOutline, 0.35); border.width: 1

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12

                                Column {
                                    spacing: 3
                                    Text { text: "Background blur"; font.pixelSize: 13; font.weight: Font.Medium; color: root.clOnSurface }
                                    Text { text: "All windows — resets on next launch"; font.pixelSize: 10; color: Qt.alpha(root.clOnSurfaceV, 0.55) }
                                }
                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 48; height: 26; radius: 13
                                    color: root.blurEnabled ? Qt.alpha(root.clPrimary, 0.25) : Qt.alpha(root.clOutline, 0.20)
                                    border.color: root.blurEnabled ? root.clPrimary : Qt.alpha(root.clOutline, 0.5)
                                    border.width: 1
                                    Behavior on color       { ColorAnimation { duration: 160 } }
                                    Behavior on border.color { ColorAnimation { duration: 160 } }

                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: root.blurEnabled ? parent.width - width - 4 : 4
                                        color: root.blurEnabled ? root.clPrimary : Qt.alpha(root.clOnSurfaceV, 0.7)
                                        Behavior on x     { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            toggleGlobalBlurProc.command = [
                                                "hyprctl", "eval",
                                                "hl.config({ decoration = { blur = { enabled = " +
                                                (root.blurEnabled ? "false" : "true") + " } } })"
                                            ]
                                            toggleGlobalBlurProc.running = true
                                        }
                                    }
                                }
                            }
                        }

                        // Global opacity row
                        Rectangle {
                            Layout.fillWidth: true
                            height: opacityCol.implicitHeight + 24; radius: 12
                            color: Qt.alpha(root.clSurface, 0.5)
                            border.color: Qt.alpha(root.clOutline, 0.35); border.width: 1

                            Column {
                                id: opacityCol
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
                                spacing: 10

                                RowLayout {
                                    width: parent.width
                                    Text { text: "Window opacity"; font.pixelSize: 13; font.weight: Font.Medium; color: root.clOnSurface }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(root.globalOpacity * 100) + "%"
                                        font.pixelSize: 13; font.weight: Font.Medium; color: root.clPrimary
                                    }
                                }

                                Grid {
                                    id: opacityGrid
                                    width: parent.width
                                    columns: 6; rowSpacing: 7; columnSpacing: 7

                                    Repeater {
                                        model: root.opacityLevels

                                        Rectangle {
                                            property bool isActive: Math.abs(root.globalOpacity - modelData.value) < 0.01
                                            property bool hov: lvlMa.containsMouse
                                            width: (opacityGrid.width - 5 * 7) / 6
                                            height: 30; radius: 8
                                            color: isActive ? Qt.alpha(root.clPrimary, 0.22)
                                                           : hov ? Qt.alpha(root.clSurface, 0.9) : Qt.alpha(root.clSurfaceHigh, 0.6)
                                            border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.35)
                                            border.width: isActive ? 2 : 1
                                            Behavior on color       { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label; font.pixelSize: 12
                                                font.weight: isActive ? Font.Medium : Font.Normal
                                                color: isActive ? root.clPrimary : root.clOnSurfaceV
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                            }

                                            MouseArea {
                                                id: lvlMa
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.globalOpacity = modelData.value
                                                    setGlobalOpacityProc.command = [
                                                        Qt.resolvedUrl("set_opacity.sh").toString().replace("file://", ""),
                                                        modelData.value.toFixed(2)
                                                    ]
                                                    setGlobalOpacityProc.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
