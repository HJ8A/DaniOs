// Letras de la canción actual (fase 4b).
//
// Orden: 1) Spotify (su propia letra, vía la extensión de Spicetify);
//        2) LRCLIB exacto (artista + título + duración);
//        3) LRCLIB búsqueda (el resultado con la duración más parecida).
// Solo se busca si `active` (panel de letras abierto): ahorra red y solo se
// envía el artista/título a LRCLIB cuando el usuario quiere ver la letra.
// Caché en disco por canción (~/.cache/danios-music/lyrics/), también "sin letra".
//
// Salida: lines [{t (ms), text}], synced, source ("spotify"|"lrclib"), status
// (idle | loading | ready | none | error).
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var  player                 // MprisPlayer
    property var  bridge                 // SpotifyBridge (puede no estar conectado)
    property bool active: false

    property var    lines: []
    property bool   synced: false
    property string source: ""
    property string status: "idle"

    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property real   lengthSec: player && player.lengthSupported ? player.length : 0
    readonly property string key: (artist && title) ? (artist + " - " + title).toLowerCase() : ""
    property string loadedKey: ""

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/danios-music/lyrics/"
    function cacheFile(k) { return cacheDir + k.replace(/[^a-z0-9ñáéíóúü -]/gi, "_").slice(0, 120) + ".json" }

    onKeyChanged: if (key && key !== loadedKey) reset()
    onActiveChanged: maybeLoad()

    function reset() {
        lines = []
        synced = false
        source = ""
        status = "idle"
        loadedKey = ""
        spotifyWait.stop()
        maybeLoad()
    }

    function maybeLoad() {
        if (!active || !key || key === loadedKey || status === "loading")
            return
        loadedKey = key
        status = "loading"
        cache.path = ""
        cache.path = cacheFile(key)          // 0) caché en disco
    }

    function finish(result, store) {
        lines = result.lines || []
        synced = !!result.synced
        source = result.source || ""
        status = lines.length ? "ready" : "none"
        if (store)
            cache.setText(JSON.stringify({ lines: lines, synced: synced, source: source, at: Date.now() }))
    }

    FileView {
        id: cache
        blockLoading: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text())
                // "Sin letra" se reintenta pasados 7 días
                if (c.lines.length || Date.now() - c.at < 7 * 86400000) {
                    root.finish(c, false)
                    return
                }
            } catch (e) {}
            root.fromSpotify()
        }
        onLoadFailed: root.fromSpotify()
    }

    // ── 1) Spotify ───────────────────────────────────────────────────────────
    property string pendingUri: ""
    function fromSpotify() {
        const cur = bridge && bridge.connected ? bridge.current : null
        if (!cur || !cur.uri || (cur.name || "").toLowerCase() !== title.toLowerCase()) {
            fromLrclib()
            return
        }
        pendingUri = cur.uri
        bridge.getLyrics(cur.uri)
        spotifyWait.restart()
    }
    Timer {
        id: spotifyWait
        interval: 3000                      // si Spotify no responde, LRCLIB
        onTriggered: { root.pendingUri = ""; root.fromLrclib() }
    }
    Connections {
        target: root.bridge
        function onLyricsChanged() {
            const l = root.bridge.lyrics
            if (!root.pendingUri || l.uri !== root.pendingUri)
                return
            spotifyWait.stop()
            root.pendingUri = ""
            if (l.lines.length)
                root.finish({ lines: l.lines, synced: l.synced, source: "spotify" }, true)
            else
                root.fromLrclib()
        }
    }

    // ── 2) y 3) LRCLIB ───────────────────────────────────────────────────────
    function parseLrc(text) {
        const out = []
        for (const raw of String(text || "").split("\n")) {
            const stamps = raw.match(/\[(\d+):(\d+(?:\.\d+)?)\]/g)
            const words = raw.replace(/\[[^\]]*\]/g, "").trim()
            if (!stamps || !words)
                continue
            for (const st of stamps) {
                const m = st.match(/\[(\d+):(\d+(?:\.\d+)?)\]/)
                out.push({ t: Math.round((+m[1] * 60 + +m[2]) * 1000), text: words })
            }
        }
        return out.sort((a, b) => a.t - b.t)
    }

    function fromRecord(r) {
        if (r && r.syncedLyrics)
            return { lines: parseLrc(r.syncedLyrics), synced: true, source: "lrclib" }
        if (r && r.plainLyrics)
            return { lines: r.plainLyrics.split("\n").map(s => s.trim()).filter(s => s).map(s => ({ t: -1, text: s })),
                     synced: false, source: "lrclib" }
        return null
    }

    function request(url, onDone) {
        const forKey = key
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || forKey !== root.key)
                return
            let data = null
            try { data = JSON.parse(xhr.responseText) } catch (e) {}
            onDone(xhr.status, data)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function fromLrclib() {
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title)
                + (lengthSec > 0 ? "&duration=" + Math.round(lengthSec) : "")
        request("https://lrclib.net/api/get?" + q, (code, data) => {
            const exact = code === 200 ? fromRecord(data) : null
            if (exact) {
                finish(exact, true)
                return
            }
            if (code !== 200 && code !== 404) {
                status = "error"                // sin red: no se guarda, se reintenta luego
                loadedKey = ""
                return
            }
            // Búsqueda: el que tenga letra y la duración más parecida
            request("https://lrclib.net/api/search?q=" + encodeURIComponent(artist + " " + title), (code2, list) => {
                if (code2 !== 200 || !Array.isArray(list)) {
                    status = "error"
                    loadedKey = ""
                    return
                }
                const ok = list.filter(r => r.syncedLyrics || r.plainLyrics)
                ok.sort((a, b) => (b.syncedLyrics ? 1 : 0) - (a.syncedLyrics ? 1 : 0)
                                  || Math.abs((a.duration || 0) - lengthSec) - Math.abs((b.duration || 0) - lengthSec))
                const best = ok.find(r => !lengthSec || Math.abs((r.duration || 0) - lengthSec) < 8)
                finish(fromRecord(best) || { lines: [], synced: false, source: "" }, true)
            })
        })
    }
}
