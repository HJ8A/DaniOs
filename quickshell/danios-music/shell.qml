// DaniOS Music — reproductor a pantalla completa (fase 1).
//
//   qs -c danios-music
//
// Ventana real ("DaniOS Music") que vive en el workspace especial de música:
// Super + M la abre la primera vez y luego la muestra u oculta al instante
// (toggles de Caelestia en ~/.config/caelestia/cli.json). Se puede mover a
// cualquier workspace. Esc = ocultar · Ctrl + Q = cerrar del todo.
//
// Fondo = videoclip de la canción (YouTube, sin audio, sincronizado) o la
// portada desenfocada; hora gigante; tarjeta de la canción; barra de vidrio.
// El audio lo reproduce Spotify (escondido en special:spotify, Super + Alt + M);
// se controla por MPRIS. La música no depende de esta ventana.
// Mientras no se ve, el video se detiene y se descarga (0 % CPU, sin red).
// Docs: vault EverSystemOs → 02-PROYECTOS/Activos/DaniOS Music.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "components"
import "services"
import "dw/common" as DW
import "dw/services" as DWS

ShellRoot {
    id: root

    // ── Opciones: defaults.json + config.json (services/Settings.qml) ────────
    Settings { id: settings }
    readonly property var opts: settings.cfg

    DW.Theme { id: appTheme }

    // Cola y biblioteca de Spotify (extensión de Spicetify, fase 3)
    // Id distinto del nombre de la propiedad de los componentes (`bridge`):
    // `bridge: bridge` se resolvía a la propia propiedad y quedaba vacío.
    SpotifyBridge { id: bridgeSvc }

    DWS.Media {
        id: mediaSvc
        preferred: root.opts.preferred || ""
        allowed: (root.opts.players || {}).allowed || []
    }

    VideoResolver {
        id: resolver
        player: mediaSvc.active
        enabled: root.opts.video.enabled === true
        maxHeight: root.opts.video.maxHeight || 1080
        onlyMusicVideos: root.opts.video.onlyMusicVideos !== false
    }

    // Spotify es el motor de audio: si no está abierto, se arranca (la regla
    // de hypr-user.lua lo manda escondido a special:spotify).
    Process {
        running: true
        command: ["bash", "-c", "pgrep -x spotify >/dev/null || exec setsid spotify-launcher >/dev/null 2>&1"]
    }

    // ¿Se ve la ventana? Su workspace es el especial abierto, o el workspace
    // activo de su monitor sin especial encima. Es un binding: se recalcula
    // solo cuando Hyprland entrega datos nuevos (nada de temporizadores; así
    // no queda un valor viejo si la ventana se abre ya visible).
    readonly property var me: Hyprland.toplevels.values.find(t => t.title === "DaniOS Music") ?? null
    readonly property bool fullscreen: (me?.lastIpcObject?.fullscreen ?? 0) > 0
    readonly property bool shown: {
        const ws = me?.workspace
        if (!ws)
            return true
        const mon = ws.monitor
        const special = mon?.lastIpcObject?.specialWorkspace?.name ?? ""
        return ws.name.startsWith("special:") ? special === ws.name
                                              : (special === "" && mon?.activeWorkspace === ws)
    }

    // Hyprland no actualiza solo `lastIpcObject`: se pide en cada cambio
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activespecial", "workspace", "focusedmon", "movewindow", "movewindowv2", "openwindow", "closewindow", "fullscreen"].includes(event.name)) {
                Hyprland.refreshMonitors()
                Hyprland.refreshToplevels()
            }
        }
    }
    Component.onCompleted: {
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
    }

    // Letras (fase 4b): solo se buscan con el panel abierto y la ventana visible
    readonly property bool lyricsOpen: (root.opts.lyrics || {}).visible === true
    LyricsService {
        id: lyricsSvc
        player: mediaSvc.active
        bridge: bridgeSvc
        active: root.lyricsOpen && root.shown
    }

    // Espectro para los bordes: solo mientras se ve la ventana y suena música
    DWS.Cava {
        id: cavaSvc
        active: root.shown && mediaSvc.playing && root.opts.edges.enabled === true
        bars: root.opts.edges.bars || 48
        framerate: root.opts.edges.framerate || 30
        stereo: true
    }

    FloatingWindow {
        id: win

        title: "DaniOS Music"
        // Cerrar la ventana (p. ej. el atajo de cerrar ventana) cierra el programa:
        // si no, el proceso seguía sin ventana con la conexión de Spotify ocupada
        // y Super+M abría otro que ya no podía conectarse (visto: 3 a la vez).
        onVisibleChanged: if (!visible) Qt.quit()
        color: "black"
        implicitWidth: 1280
        implicitHeight: 800

        readonly property color accent: card.vivid ?? appTheme.primary
        readonly property color textColor: "#f4f4f6"
        readonly property color subColor: Qt.rgba(1, 1, 1, 0.72)

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            // Buscador (fase 4a): Ctrl+K o clic en la tarjeta central
            property bool searchOpen: false
            function openSearch() { searchOpen = true }
            function closeSearch() {
                searchOpen = false
                stage.forceActiveFocus()
            }

            Keys.onPressed: event => {
                const p = mediaSvc.active
                if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))
                    stage.openSearch()
                else if (event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier))
                    Qt.quit()
                else if (event.key === Qt.Key_Escape) {
                    // Ocultar = cerrar el especial donde está (en un workspace normal no hace nada)
                    const ws = Hyprland.toplevels.values.find(t => t.title === "DaniOS Music")?.workspace
                    if (ws && ws.name.startsWith("special:"))
                        Hyprland.dispatch('hl.dsp.workspace.toggle_special("' + ws.name.slice(8) + '")')
                }
                else if (p && event.key === Qt.Key_Space && p.canTogglePlaying)
                    p.togglePlaying()
                else if (p && event.key === Qt.Key_Right && p.canGoNext)
                    p.next()
                else if (p && event.key === Qt.Key_Left && p.canGoPrevious)
                    p.previous()
                else
                    return
                event.accepted = true
            }

            VideoBackground {
                id: bg
                anchors.fill: parent
                player: mediaSvc.active
                videoUrl: resolver.url
                artUrl: card.artUrl
                dim: root.opts.video.dim ?? 0.35
                crop: root.opts.video.cropBars !== false ? resolver.crop : null
                onFailed: resolver.fallback()
                active: root.shown
            }

            // Bordes de luz: encima del video, debajo de los paneles
            EdgeGlow {
                anchors.fill: parent
                visible: root.opts.edges.enabled === true
                values: cavaSvc.values
                accent: win.accent
                fallback: appTheme.primary
                cornerRadius: root.fullscreen ? 0 : 15     // decoration:rounding de Hyprland
                intensity: root.opts.edges.intensity ?? 1
                reachFraction: root.opts.edges.reach || 0.11
            }

            BigClock {
                id: clock
                opacity: stage.searchOpen ? 0.18 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.05
                size: parent.height * 0.24
                color: win.accent
                fontFamily: root.opts.clock.font || "Open Sans Condensed"
                format24: root.opts.clock.format24 === true
                Behavior on color { ColorAnimation { duration: 600 } }
            }

            NowCard {
                id: card
                opacity: stage.searchOpen ? 0.18 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
                onClicked: stage.openSearch()
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clock.bottom
                anchors.topMargin: parent.height * 0.02
                backdrop: bg
                media: mediaSvc
                coverSize: Math.round(parent.height * 0.2)
                textColor: win.textColor
                subColor: win.subColor
            }

            // Cola y playlists (fase 3), a la izquierda como en la referencia
            QueuePanel {
                id: queuePanel
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.045
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.52
                width: Math.min(330, parent.width * 0.23)
                // Inclinado como en la referencia: el lado izquierdo más cerca
                // y el derecho hacia dentro (rotación 3D con perspectiva)
                transform: Rotation {
                    origin.x: 0
                    origin.y: queuePanel.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 16
                }
                visible: parent.width > 1050
                backdrop: bg
                bridge: bridgeSvc
                accent: win.accent
                textColor: win.textColor
                subColor: win.subColor
            }

            PlayerBar {
                id: bar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.045
                width: Math.min(parent.width * 0.62, 980)
                backdrop: bg
                media: mediaSvc
                accent: win.accent
                // Estado combinado: buscando (yt-dlp) → cargando (reproductor) → en pantalla
                videoState: resolver.status === "ready" ? (bg.videoShown ? "playing" : "loading") : resolver.status
                onVideoToggled: settings.set("video.enabled", !(root.opts.video.enabled === true))
                textColor: win.textColor
                subColor: win.subColor
            }

            // Botón "Letras" bajo la tarjeta (como en la referencia)
            Glass {
                id: lyricsBtn
                anchors.horizontalCenter: card.horizontalCenter
                anchors.top: card.bottom
                anchors.topMargin: 14
                backdrop: bg
                height: 34
                width: lyricsRow.implicitWidth + 26
                radius: height / 2
                opacity: stage.searchOpen ? 0.18 : 1
                tint: root.lyricsOpen ? Qt.alpha(win.accent, 0.22) : Qt.rgba(1, 1, 1, lyricsMa.containsMouse ? 0.12 : 0.06)
                borderColor: root.lyricsOpen ? Qt.alpha(win.accent, 0.6) : Qt.rgba(1, 1, 1, 0.16)
                Row {
                    id: lyricsRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lyrics"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 17
                        color: root.lyricsOpen ? win.accent : win.subColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Letras"
                        color: root.lyricsOpen ? win.accent : win.textColor
                        font.family: "Rubik"
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: lyricsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settings.set("lyrics.visible", !root.lyricsOpen)
                }
            }

            // Panel de letras a la derecha, simétrico a la cola
            LyricsPanel {
                id: lyricsPanel
                visible: root.lyricsOpen && parent.width > 1050
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.045
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.52
                width: Math.min(360, parent.width * 0.25)
                player: mediaSvc.active
                lyrics: lyricsSvc
                backdrop: bg
                accent: win.accent
                textColor: win.textColor
                subColor: win.subColor
                // inclinado hacia el otro lado: el borde derecho más cerca
                transform: Rotation {
                    origin.x: lyricsPanel.width
                    origin.y: lyricsPanel.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: -16
                }
            }

            // Buscador: solo existe mientras está abierto
            Loader {
                anchors.fill: parent
                active: stage.searchOpen
                sourceComponent: SearchOverlay {
                    bridge: bridgeSvc
                    backdrop: bg
                    accent: win.accent
                    textColor: win.textColor
                    subColor: win.subColor
                    onClosed: stage.closeSearch()
                }
            }

            // Sin reproductor
            Text {
                anchors.centerIn: parent
                visible: !mediaSvc.active
                text: "Abre Spotify o reproduce algo para empezar"
                color: win.subColor
                font.family: "Rubik"
                font.pixelSize: 18
            }
        }
    }
}
