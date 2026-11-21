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
    SpotifyBridge { id: bridge }

    DWS.Media {
        id: mediaSvc
        preferred: root.opts.preferred || ""
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

            Keys.onPressed: event => {
                const p = mediaSvc.active
                if (event.key === Qt.Key_Q && (event.modifiers & Qt.ControlModifier))
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
                bridge: bridge
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
