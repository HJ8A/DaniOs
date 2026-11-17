// Colores del esquema activo de Caelestia (~/.local/state/caelestia/scheme.json).
// Se recarga solo cuando cambia el esquema (p. ej. al elegir otro fondo con
// Super + I), así que los widgets cambian de color junto con todo el escritorio.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property color primary:          "#c6c6c6"
    property color secondary:        "#9e9e9e"
    property color tertiary:         "#f6f6f6"
    property color inversePrimary:   "#5d5d5d"
    property color textColor:        "#e6e6e6"
    property color textVariant: "#ababab"
    property color surface:          "#0e0e0e"
    property color outline:          "#757575"
    property bool  dark:             true

    function hex(value, fallback) {
        return (value && value.length >= 6) ? "#" + value.slice(-6) : fallback
    }

    // "auto" (o vacío) usa el color del esquema; si no, el valor tal cual (#rrggbb).
    function pick(value, fallback) {
        return (!value || value === "auto") ? fallback : value
    }

    property FileView file: FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                const c = d.colours || {}
                theme.primary          = theme.hex(c.primary, theme.primary)
                theme.secondary        = theme.hex(c.secondary, theme.secondary)
                theme.tertiary         = theme.hex(c.tertiary, theme.tertiary)
                theme.inversePrimary   = theme.hex(c.inversePrimary, theme.inversePrimary)
                theme.textColor        = theme.hex(c.onSurface, theme.textColor)
                theme.textVariant      = theme.hex(c.onSurfaceVariant, theme.textVariant)
                theme.surface          = theme.hex(c.surface, theme.surface)
                theme.outline          = theme.hex(c.outline, theme.outline)
                theme.dark             = d.mode !== "light"
            } catch (e) {
                console.warn("desktop-widgets: no se pudo leer scheme.json:", e)
            }
        }
    }
}
