// Configuración de una app con el patrón defaults.json + config.json (solo lo
// que el usuario cambió). Lo usa la pestaña Widgets para DaniOS Music; la app
// vigila su config.json y aplica cada cambio al instante.
import QtQuick
import Quickshell.Io

Item {
    id: root

    property string defaultsPath
    property string configPath

    property var defaults: ({})
    property var user: ({})
    readonly property var cfg: merge(defaults, user)
    readonly property bool ready: Object.keys(defaults).length > 0

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

    function get(path) {
        let node = cfg
        for (const part of path.split(".")) {
            if (!isObj(node)) return undefined
            node = node[part]
        }
        return node
    }

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

    function reset() {
        user = ({})
        userFile.setText("{}\n")
    }

    FileView {
        path: root.defaultsPath
        blockLoading: true
        onLoaded: {
            try { root.defaults = JSON.parse(text()) } catch (e) { console.warn("JsonSettings:", root.defaultsPath, "inválido:", e) }
        }
    }

    FileView {
        id: userFile
        path: root.configPath
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.user = JSON.parse(text()) } catch (e) { console.warn("JsonSettings:", root.configPath, "inválido:", e) }
        }
        onLoadFailed: root.user = ({})
    }
}
