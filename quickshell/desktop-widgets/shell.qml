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
import "common"
import "widgets"

ShellRoot {
    id: root

    // ── Valores por defecto: defaults.json (una sola fuente, también la lee la
    //    pestaña "Widgets" de Super + I). Documentados en el vault. ───────────
    // Esqueleto con la misma forma, para que nada lea `undefined` antes de cargar.
    property var defaults: ({ clock: { analog: {}, sunmoon: {}, earth: {} }, location: {} })

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
    readonly property bool ready: root.cfg.clock !== undefined && root.cfg.clock.style !== undefined

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
        id: theme
    }

    Component {
        id: analogClock

        ClockAnalog {
            opts: root.cfg.clock.analog
            theme: theme
            size: root.cfg.clock.size
        }
    }

    Component {
        id: sunMoonClock

        ClockSunMoon {
            opts: root.cfg.clock.sunmoon
            theme: theme
            location: root.cfg.location
            size: root.cfg.clock.size
        }
    }

    Component {
        id: earthClock

        ClockEarth {
            opts: root.cfg.clock.earth
            theme: theme
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
}
