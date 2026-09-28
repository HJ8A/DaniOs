pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
                    Qt.callLater(() => carousel.positionViewAtIndex(idx, ListView.Center))

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
        onExited: Qt.quit()
    }

    Process {
        id: applyScheme
        onExited: root.applyingScheme = false
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
        onExited: Qt.quit()
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

    // ── Overlay window ────────────────────────────────────────────────────────
    PanelWindow {
        id: overlay
        visible: true

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace:     "wallpaper-picker"
        WlrLayershell.exclusiveZone: -1

        anchors { top: true; bottom: true; left: true; right: true }
        color: "#cc000000"

        MouseArea {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()
            onClicked: Qt.quit()
        }

        // ── Main card ─────────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.centerIn: parent
            width:  Math.min(parent.width  * 0.84, 920)
            height: Math.min(parent.height * 0.82, 660)
            radius: 20
            color:  root.clBg

            opacity: 0; scale: 0.95
            NumberAnimation on opacity { running: true; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation on scale   { running: true; to: 1; duration: 220; easing.type: Easing.OutCubic }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 14

                // ── Header ────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle { width: 7; height: 7; radius: 4; color: root.clPrimary }
                    Text {
                        text: "Appearance"
                        font.pixelSize: 19; font.weight: Font.Medium
                        color: root.clOnSurface
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: xBtn.containsMouse ? Qt.alpha(root.clPrimary, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: root.clOnSurfaceV }
                        MouseArea { id: xBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                    }
                }

                // ── Tab bar ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ["Wallpaper", "Color Scheme", "Bar", "Effects", "GIFs"]

                        Rectangle {
                            id: tabRect
                            property bool isActive: index === root.currentTab
                            property bool hov: tabMa.containsMouse
                            height: 34
                            width: tabTxt.implicitWidth + 28
                            radius: 17
                            color: isActive ? Qt.alpha(root.clPrimary, 0.18)
                                           : hov ? Qt.alpha(root.clPrimary, 0.07) : "transparent"
                            border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.40)
                            border.width: 1
                            Behavior on color       { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            Text {
                                id: tabTxt
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 13
                                font.weight: tabRect.isActive ? Font.Medium : Font.Normal
                                color: tabRect.isActive ? root.clPrimary : root.clOnSurfaceV
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = index
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: Qt.alpha(root.clOutline, 0.35)
                }

                // ── Content area ──────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ── TAB 0: Wallpaper carousel ─────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10
                        visible: root.currentTab === 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "WALLPAPER"
                                font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                                color: root.clPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                height: 26
                                width: openWallFolderTxt.implicitWidth + 22
                                radius: 13
                                color: openWallFolderMa.containsMouse ? Qt.alpha(root.clPrimary, 0.15) : "transparent"
                                border.color: Qt.alpha(root.clOutline, 0.40)
                                border.width: 1

                                Text {
                                    id: openWallFolderTxt
                                    anchors.centerIn: parent
                                    text: "📁 Abrir carpeta"
                                    font.pixelSize: 11
                                    color: root.clOnSurfaceV
                                }
                                MouseArea {
                                    id: openWallFolderMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFolder(Quickshell.env("HOME") + "/Pictures/wallpapers")
                                }
                            }
                        }

                        ListView {
                            id: carousel
                            Layout.fillWidth: true; Layout.fillHeight: true
                            orientation: ListView.Horizontal
                            spacing: 10; clip: true; model: wallModel
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                            delegate: Item {
                                id: wallDelegate
                                required property string path
                                required property string thumb
                                required property string name
                                required property bool current
                                required property int index

                                width: 190; height: carousel.height
                                property bool isActive: wallDelegate.path === root.current

                                Rectangle {
                                    id: wallCard
                                    anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
                                    radius: 12; clip: true; color: root.clSurfaceHigh
                                    property bool hov: wallMa.containsMouse

                                    border.color: wallDelegate.isActive ? root.clPrimary
                                                : hov ? Qt.alpha(root.clPrimary, 0.55) : "transparent"
                                    border.width: 2
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    Image {
                                        anchors { fill: parent; margins: 2 }
                                        source: "file://" + wallDelegate.path
                                        sourceSize.width: 420; sourceSize.height: 420
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; smooth: true; mipmap: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: wallCard.hov ? "#14ffffff" : "transparent"
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 44
                                        visible: wallCard.hov || wallDelegate.isActive
                                        gradient: Gradient {
                                            orientation: Gradient.Vertical
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: "#d4000000" }
                                        }
                                        Text {
                                            anchors { bottom: parent.bottom; bottomMargin: 9; horizontalCenter: parent.horizontalCenter }
                                            text: wallDelegate.name.replace(/_/g, " ")
                                            font.pixelSize: 11; color: "white"
                                            elide: Text.ElideRight; width: parent.width - 16
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    Rectangle {
                                        anchors { top: parent.top; right: parent.right; margins: 8 }
                                        width: 20; height: 20; radius: 10; color: root.clPrimary
                                        visible: wallDelegate.isActive
                                        Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; font.weight: Font.Bold; color: root.clBg }
                                    }

                                    MouseArea {
                                        id: wallMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.current = wallDelegate.path
                                            applyWall.command = ["caelestia", "wallpaper", "-f", wallDelegate.path]
                                            applyWall.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }

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

                        Rectangle {
                            Layout.fillWidth: true; height: 52; radius: 10
                            color: root.applyingScheme ? Qt.alpha(root.clPrimary, 0.08) : Qt.alpha(root.clSurface, 0.9)
                            border.color: root.applyingScheme ? Qt.alpha(root.clPrimary, 0.4) : Qt.alpha(root.clOutline, 0.35)
                            border.width: 1
                            Behavior on color       { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            Text {
                                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 16 }
                                text: {
                                    if (root.applyingScheme) return "Applying scheme…"
                                    if (root.hoveredScheme === "") return "Hover over a scheme to see a description"
                                    var s = root.schemes.find(x => x.name === root.hoveredScheme)
                                    return s ? "● " + s.name + "  —  " + s.desc : ""
                                }
                                font.pixelSize: 12
                                color: root.applyingScheme        ? root.clPrimary
                                     : root.hoveredScheme === "" ? Qt.alpha(root.clOnSurfaceV, 0.45)
                                                                 : root.clOnSurface
                                Behavior on color { ColorAnimation { duration: 120 } }
                                wrapMode: Text.WordWrap
                            }
                        }

                        Flow {
                            Layout.fillWidth: true; spacing: 8

                            Repeater {
                                model: root.schemes

                                Rectangle {
                                    id: chip
                                    property bool hov: chipMa.containsMouse
                                    width: chipTxt.implicitWidth + 28; height: 34; radius: 17
                                    color: (hov && !root.applyingScheme)
                                        ? Qt.alpha(root.clPrimary, 0.18) : Qt.alpha(root.clOnSurface, 0.06)
                                    border.color: (hov && !root.applyingScheme)
                                        ? root.clPrimary : Qt.alpha(root.clOutline, 0.55)
                                    border.width: 1
                                    Behavior on color       { ColorAnimation { duration: 130 } }
                                    Behavior on border.color { ColorAnimation { duration: 130 } }

                                    Text {
                                        id: chipTxt; anchors.centerIn: parent
                                        text: modelData.name; font.pixelSize: 13
                                        color: root.applyingScheme ? Qt.alpha(root.clOnSurface, 0.40) : root.clOnSurface
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }

                                    MouseArea {
                                        id: chipMa
                                        anchors.fill: parent; hoverEnabled: true
                                        enabled: !root.applyingScheme
                                        cursorShape: root.applyingScheme ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onEntered: root.hoveredScheme = modelData.name
                                        onExited:  root.hoveredScheme = ""
                                        onClicked: {
                                            root.applyingScheme = true
                                            applyScheme.command = ["caelestia", "scheme", "set", "-n", modelData.name]
                                            applyScheme.running = true
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
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

                    // ── TAB 4: GIFs ────────────────────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10
                        visible: root.currentTab === 4
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "GIFS"
                                font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 2
                                color: root.clPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                height: 26
                                width: openGifFolderTxt.implicitWidth + 22
                                radius: 13
                                color: openGifFolderMa.containsMouse ? Qt.alpha(root.clPrimary, 0.15) : "transparent"
                                border.color: Qt.alpha(root.clOutline, 0.40)
                                border.width: 1

                                Text {
                                    id: openGifFolderTxt
                                    anchors.centerIn: parent
                                    text: "📁 Abrir carpeta"
                                    font.pixelSize: 11
                                    color: root.clOnSurfaceV
                                }
                                MouseArea {
                                    id: openGifFolderMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFolder(Quickshell.env("HOME") + "/Pictures/gifs")
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    { id: "session", label: "Panel de sesión" },
                                    { id: "media",   label: "Reproduciendo música" },
                                ]

                                Rectangle {
                                    required property var modelData
                                    property bool isActive: root.gifSlot === modelData.id
                                    height: 34
                                    width: slotTxt.implicitWidth + 28
                                    radius: 17
                                    color: isActive ? Qt.alpha(root.clPrimary, 0.18) : "transparent"
                                    border.color: isActive ? root.clPrimary : Qt.alpha(root.clOutline, 0.40)
                                    border.width: 1

                                    Text {
                                        id: slotTxt
                                        anchors.centerIn: parent
                                        text: parent.modelData.label
                                        font.pixelSize: 13
                                        color: parent.isActive ? root.clPrimary : root.clOnSurfaceV
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.gifSlot = parent.modelData.id
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: "Carpeta: ~/Pictures/gifs — agregá archivos .gif ahí y aparecen acá"
                            font.pixelSize: 11
                            color: root.clOnSurfaceV
                        }

                        GridView {
                            id: gifGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: 150; cellHeight: 150
                            model: gifModel

                            delegate: Item {
                                required property string path
                                required property string name
                                required property bool isSession
                                required property bool isMedia

                                width: gifGrid.cellWidth; height: gifGrid.cellHeight
                                property bool isCurrentForSlot: root.gifSlot === "session" ? isSession : isMedia

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    radius: 12; clip: true; color: root.clSurfaceHigh
                                    property bool hov: gifMa.containsMouse

                                    border.color: parent.parent.isCurrentForSlot ? root.clPrimary
                                                : hov ? Qt.alpha(root.clPrimary, 0.55) : "transparent"
                                    border.width: 2
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    AnimatedImage {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: "file://" + parent.parent.path
                                        fillMode: AnimatedImage.PreserveAspectCrop
                                        asynchronous: true
                                        playing: true
                                    }

                                    Rectangle {
                                        anchors { top: parent.top; right: parent.right; margins: 8 }
                                        width: 20; height: 20; radius: 10; color: root.clPrimary
                                        visible: parent.parent.isCurrentForSlot
                                        Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; font.weight: Font.Bold; color: root.clBg }
                                    }

                                    MouseArea {
                                        id: gifMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            setGifProc.command = [
                                                "python3",
                                                Qt.resolvedUrl("set_gif.py").toString().replace("file://", ""),
                                                root.gifSlot,
                                                parent.parent.path
                                            ]
                                            setGifProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
