// Configuración de DaniOS Music: defaults.json (todas las opciones, una sola
// fuente) + config.json (solo lo que el usuario cambió). `set()` guarda
// únicamente las diferencias, de forma atómica. Si config.json tiene un error
// se conserva la última configuración válida.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var defaults: ({ video: {}, clock: {}, edges: {} })
    property var user: ({})
    readonly property var cfg: merge(defaults, user)
    readonly property bool ready: defaults.video.enabled !== undefined

    function isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }

    function merge(base, over) {
        if (!isObj(over))
            return over === undefined ? base : over
        const out = {}
        for (const k in base) out[k] = base[k]
        for (const k in over) out[k] = isObj(base[k]) ? merge(base[k], over[k]) : over[k]
        return out
    }

    function prune(over, base) {
        const out = {}
        for (const k in over) {
            if (isObj(over[k]) && isObj(base[k])) {
                const sub = prune(over[k], base[k])
                if (Object.keys(sub).length) out[k] = sub
            } else if (JSON.stringify(over[k]) !== JSON.stringify(base[k])) {
                out[k] = over[k]
            }
        }
        return out
    }

    // set("video.enabled", false)
    function set(path, value) {
        const next = JSON.parse(JSON.stringify(user))
        const parts = path.split(".")
        let node = next
        for (let i = 0; i < parts.length - 1; ++i) {
            if (!isObj(node[parts[i]])) node[parts[i]] = {}
            node = node[parts[i]]
        }
        node[parts[parts.length - 1]] = value
        const clean = prune(next, defaults)
        user = clean
        userFile.setText(JSON.stringify(clean, null, 4) + "\n")
    }

    FileView {
        path: Qt.resolvedUrl("../defaults.json").toString().replace("file://", "")
        blockLoading: true
        onLoaded: {
            try { root.defaults = JSON.parse(text()) } catch (e) { console.warn("danios-music: defaults.json inválido:", e) }
        }
    }

    FileView {
        id: userFile
        path: Qt.resolvedUrl("../config.json").toString().replace("file://", "")
        blockLoading: true
        printErrors: false        // no existir es lo normal (todo por defecto)
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.user = JSON.parse(text()) } catch (e) { console.warn("danios-music: config.json inválido, conservo la última configuración válida:", e) }
        }
        onLoadFailed: root.user = ({})
    }
}
