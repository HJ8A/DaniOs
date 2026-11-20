// desktop-widgets — widgets propios en el escritorio (DaniOS sobre Caelestia).
//
//   qs -c desktop-widgets        (lo arranca hypr-user.lua al iniciar Hyprland)
//
// config.json solo necesita los valores que se quieran cambiar: todo lo demás
// sale de `defaults` (abajo). El archivo se vigila, así que un cambio (a mano o
// desde la futura pestaña "Widgets" de Super + I) se aplica al instante.
//
// Un solo reloj a la vez: clock.style elige cuál ("analog"; "sunmoon" y
// "earth" quedan reservados para los relojes 2 y 3).
// Docs: vault EverSystemOs → 02-PROYECTOS/Activos/Widgets de Escritorio.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"
import "widgets"
import "services"

ShellRoot {
    id: root

    // ── Valores por defecto: defaults.json (una sola fuente, también la lee la
    //    pestaña "Widgets" de Super + I). Documentados en el vault. ───────────
    // Esqueleto con la misma forma, para que nada lea `undefined` antes de cargar.
    property var defaults: ({ clock: { analog: {}, sunmoon: {}, earth: {} }, player: { cava: {}, colors: {}, vinyl: {} }, location: {} })

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("defaults.json").toString().replace("file://", "")
        blockLoading: true
        onLoaded: {
            try {
                root.defaults = JSON.parse(text())
            } catch (e) {
                console.warn("desktop-widgets: defaults.json inválido:", e)
            }
        }
    }

    // Configuración efectiva = defaults.json + config.json (solo lo que cambia).
    // Si config.json tiene un error se conserva la última configuración válida.
    property var cfg: defaults
    property var userConfig: ({})
    // Las ventanas se crean solo cuando defaults.json ya está cargado
    // (defaults.json leído; config.json puede llegar antes y dejar huecos)
    readonly property bool ready: root.cfg.clock?.marginY !== undefined && root.cfg.player?.marginY !== undefined
                                  && root.cfg.location?.latitude !== undefined

    function merge(base, over) {
        if (over === null || over === undefined || typeof over !== "object" || Array.isArray(over))
            return over === undefined ? base : over
        const out = {}
        for (const k in base)
            out[k] = base[k]
        for (const k in over)
            out[k] = (base && typeof base[k] === "object" && !Array.isArray(base[k])) ? merge(base[k], over[k]) : over[k]
        return out
    }

    FileView {
        id: configFile
        path: Qt.resolvedUrl("config.json").toString().replace("file://", "")
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.userConfig = JSON.parse(text())
            } catch (e) {
                console.warn("desktop-widgets: config.json inválido, conservo la última configuración válida:", e)
            }
        }
        onLoadFailed: root.userConfig = ({})
    }

    // Se recalcula cuando cambia cualquiera de las dos fuentes
    Binding {
        target: root
        property: "cfg"
        value: root.merge(root.defaults, root.userConfig)
    }

    Theme {
        id: appTheme
    }

    // ── Música: reproductor activo + cava (uno para todas las pantallas) ─────
    Media {
        id: mediaSvc
        preferred: root.cfg.player.preferred || ""
    }

    // Se oculta sin música; en pausa espera `hideAfterPaused` s (−1 = nunca)
    property bool pausedLong: false
    readonly property int hideAfterPaused: root.cfg.player.hideAfterPaused ?? 300

    function updatePaused() {
        if (mediaSvc.playing || !mediaSvc.active) {
            pausedTimer.stop()
            pausedLong = false
        } else if (hideAfterPaused === 0) {
            pausedLong = true
        } else if (hideAfterPaused > 0 && !pausedTimer.running && !pausedLong) {
            pausedTimer.restart()
        }
    }

    Timer {
        id: pausedTimer
        interval: Math.max(1, root.hideAfterPaused) * 1000
        onTriggered: root.pausedLong = true
    }

    Connections {
        target: mediaSvc
        function onPlayingChanged() { root.updatePaused() }
        function onActiveChanged() { root.pausedLong = false; pausedTimer.stop(); root.updatePaused() }
    }
    Component.onCompleted: updatePaused()

    readonly property bool playerShown: root.ready && root.cfg.player.enabled === true
                                        && mediaSvc.active !== null && (mediaSvc.playing || !root.pausedLong)

    // ── Visualizador ──────────────────────────────────────────────────────────
    // "bottom"/"mirror": barras en el borde inferior (y superior) de la
    // pantalla, como el visualizador de Caelestia al que reemplaza; "circle":
    // alrededor de la tarjeta. Dentro de la tarjeta nunca hay barras.
    readonly property var cav: root.cfg.player.cava
    readonly property bool cavaWanted: root.playerShown && mediaSvc.playing && cav.enabled !== false
    readonly property bool onScreenEdges: cav.mode !== "circle"

    // Como Caelestia: en los bordes solo se ve con el escritorio despejado
    // (sin ventanas en mosaico); detrás de ventanas no se dibuja ni se calcula.
    function desktopFree(screen) {
        if (cav.autoHide === false)
            return true
        const ws = Hyprland.monitorFor(screen)?.activeWorkspace
        if (!ws)
            return true
        return ws.toplevels.values.every(t => t.lastIpcObject?.floating === true)
    }
    // Quickshell no actualiza solo `lastIpcObject` de las ventanas: una
    // ventana abierta después de arrancar (p. ej. Capri, fijada en todos los
    // workspaces) quedaba sin `floating` y contaba como "en mosaico", así que
    // las barras no volvían a salir nunca. Se refresca en cada cambio.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "pin"].includes(event.name))
                Hyprland.refreshToplevels()
        }
    }

    readonly property bool edgesVisibleSomewhere: Quickshell.screens.some(s => root.desktopFree(s))

    readonly property color artColor: mediaSvc.artColor.a > 0 ? mediaSvc.artColor : appTheme.primary
    readonly property color cavaA: cav.colorMode === "art" ? artColor : appTheme.pick((cav.colors || {}).a, appTheme.primary)
    readonly property color cavaB: cav.colorMode === "art" ? Qt.lighter(artColor, 1.4)
                                 : cav.colorMode === "gradient" ? appTheme.pick((cav.colors || {}).b, appTheme.inversePrimary)
                                 : cavaA

    Cava {
        id: cavaSvc
        active: root.cavaWanted && (!root.onScreenEdges || root.edgesVisibleSomewhere)
        bars: root.cfg.player.cava.bars || 32
        framerate: root.cfg.player.cava.framerate || 30
        stereo: root.cfg.player.cava.stereo !== false
        sensitivity: root.cfg.player.cava.sensitivity || 100
        smoothing: root.cfg.player.cava.smoothing ?? 77
    }

    Component {
        id: playerVinyl

        PlayerVinyl {
            opts: root.cfg.player
            theme: appTheme
            media: mediaSvc
            values: cavaSvc.values
            cavaA: root.cavaA
            cavaB: root.cavaB
        }
    }

    Component {
        id: playerCard

        PlayerCard {
            opts: root.cfg.player
            theme: appTheme
            media: mediaSvc
            values: cavaSvc.values
            cavaA: root.cavaA
            cavaB: root.cavaB
        }
    }

    Component {
        id: analogClock

        ClockAnalog {
            opts: root.cfg.clock.analog
            theme: appTheme
            size: root.cfg.clock.size
        }
    }

    Component {
        id: sunMoonClock

        ClockSunMoon {
            opts: root.cfg.clock.sunmoon
            theme: appTheme
            location: root.cfg.location
            size: root.cfg.clock.size
        }
    }

    Component {
        id: earthClock

        ClockEarth {
            opts: root.cfg.clock.earth
            theme: appTheme
            location: root.cfg.location
            size: root.cfg.clock.size
        }
    }

    // ── Reloj (uno por pantalla) ──────────────────────────────────────────────
    Variants {
        model: root.ready ? Quickshell.screens : []

        PanelWindow {
            id: clockWindow

            required property var modelData
            readonly property bool left: root.cfg.clock.position === "top-left"

            screen: modelData
            visible: root.cfg.clock.enabled && clockLoader.item !== null

            // Debajo de las ventanas, encima del fondo de pantalla. Respeta la
            // barra de Caelestia y no reserva espacio propio.
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desktop-widgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0

            anchors.top: true
            anchors.left: left
            anchors.right: !left
            margins.top: root.cfg.clock.marginY
            margins.left: left ? root.cfg.clock.marginX : 0
            margins.right: left ? 0 : root.cfg.clock.marginX

            implicitWidth: Math.max(1, clockLoader.implicitWidth)
            implicitHeight: Math.max(1, clockLoader.implicitHeight)
            color: "transparent"

            // Los clics pasan al escritorio; solo la zona que un reloj declare
            // (hoverItem, p. ej. el globo para girar) recibe el mouse.
            mask: Region {
                item: clockLoader.item && clockLoader.item.hoverItem ? clockLoader.item.hoverItem : null
            }

            Loader {
                id: clockLoader
                sourceComponent: ({ analog: analogClock, sunmoon: sunMoonClock, earth: earthClock })[root.cfg.clock.style] ?? null
            }
        }
    }

    // ── Reproductor (uno por pantalla) ────────────────────────────────────────
    Variants {
        model: root.ready ? Quickshell.screens : []

        PanelWindow {
            id: playerWindow

            required property var modelData
            readonly property bool left: root.cfg.player.position !== "bottom-right"
            readonly property real outer: playerLoader.item ? playerLoader.item.outer : 0

            screen: modelData
            visible: root.playerShown && playerLoader.item !== null

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desktop-widgets-player"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0

            // marginY por defecto 90: con el escritorio vacío, Caelestia captura el
            // mouse en una franja de borde (7) + umbral de arrastre (80) = 87 px
            // en todos los bordes (para abrir sus paneles arrastrando). Más cerca
            // del borde, los botones de la tarjeta no reciben el mouse.
            anchors.bottom: true
            anchors.left: left
            anchors.right: !left
            margins.bottom: Math.round(Math.max(0, root.cfg.player.marginY - outer))
            margins.left: left ? Math.round(Math.max(0, root.cfg.player.marginX - outer)) : 0
            margins.right: left ? 0 : Math.round(Math.max(0, root.cfg.player.marginX - outer))

            implicitWidth: Math.max(1, playerLoader.implicitWidth)
            implicitHeight: Math.max(1, playerLoader.implicitHeight)
            color: "transparent"

            // Solo la tarjeta recibe el mouse (botones); cava alrededor deja pasar los clics
            mask: Region {
                item: playerLoader.item ? playerLoader.item.inputItem : null
            }

            Loader {
                id: playerLoader
                sourceComponent: ({ card: playerCard, vinyl: playerVinyl })[root.cfg.player.style] ?? playerCard
            }
        }
    }

    // ── Barras en los bordes de la pantalla (una franja por borde) ───────────
    component EdgeBars: PanelWindow {
        id: edge

        property bool top: false
        property bool shown: false

        visible: shown
        // Capa de fondo (sobre la imagen de Caelestia): así queda siempre por
        // debajo del reloj y del reproductor (capa Bottom) y nunca les tapa
        // los clics, sin depender del orden en que se crean las ventanas.
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "desktop-widgets-viz"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        anchors.left: true
        anchors.right: true
        anchors.top: top
        anchors.bottom: !top
        implicitHeight: Math.max(1, Math.round(screen.height * (root.cav.height > 0 ? root.cav.height : 0.35)))
        color: "transparent"
        mask: Region {}

        Visualizer {
            anchors.fill: parent
            values: edge.shown ? cavaSvc.values : []
            mode: edge.top ? "top" : "bottom"
            shape: root.cav.shape || "bars"
            reach: height
            thickness: root.cav.thickness > 0 ? root.cav.thickness : 0.85
            rounded: root.cav.rounded !== false
            colorA: root.cavaA
            colorB: root.cavaB
            opacity: root.cav.opacity > 0 ? root.cav.opacity : 0.7
        }
    }

    Variants {
        model: root.ready ? Quickshell.screens : []

        Scope {
            id: edges
            required property var modelData
            readonly property bool show: root.cavaWanted && root.onScreenEdges && root.desktopFree(modelData)

            EdgeBars {
                screen: edges.modelData
                shown: edges.show
            }
            EdgeBars {
                screen: edges.modelData
                top: true
                shown: edges.show && root.cav.mode === "mirror"
            }
        }
    }
}
