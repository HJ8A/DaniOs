// Reproductores de música (MPRIS) y volumen de la aplicación (PipeWire).
//
// - `players`: reproductores con canción. Se ignoran los vacíos (Spotify
//   publica además un `chromium.instance<pid>` sin datos).
// - `active`: el elegido a mano (cycle()) → el que suena (preferido primero)
//   → el preferido → el primero.
// - Volumen: el de los streams de PipeWire de esa aplicación (como en el
//   mezclador), emparejados por nombre; el volumen MPRIS de los navegadores no
//   funciona. Si no hay stream, se usa el MPRIS si el reproductor lo admite.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: root

    property string preferred: ""       // identidad preferida ("Spotify", "Brave"…)
    property MprisPlayer manual: null

    // Plataformas permitidas (identidad MPRIS, sin distinguir mayúsculas).
    // Vacía = todas. DaniOS Music la usa para quedarse con Spotify y YouTube
    // Music y dejar fuera los navegadores.
    property var allowed: []
    function isAllowed(p) {
        if (!allowed || allowed.length === 0)
            return true
        const id = (p.identity || "").toLowerCase()
        return allowed.some(a => String(a).toLowerCase() === id)
    }

    readonly property var players: Mpris.players.values.filter(p => (p.trackTitle ?? "") !== "" && isAllowed(p))

    readonly property MprisPlayer active: {
        const list = players
        if (manual && list.includes(manual))
            return manual
        const pref = p => preferred !== "" && p.identity.toLowerCase() === preferred.toLowerCase()
        return list.find(p => p.isPlaying && pref(p))
            ?? list.find(p => p.isPlaying)
            ?? list.find(pref)
            ?? list[0]
            ?? null
    }

    readonly property bool playing: active ? active.isPlaying : false

    // Color vivo de la portada actual (lo calcula la tarjeta al cargar la
    // portada); transparente si aún no hay.
    property color artColor: "transparent"
    onActiveChanged: artColor = "transparent"

    function cycle() {
        const list = players
        if (list.length < 2)
            return
        manual = list[(list.indexOf(active) + 1) % list.length]
    }

    function artUrl(p) {
        if (!p)
            return ""
        if (p.trackArtUrl)
            return p.trackArtUrl
        // YouTube en el navegador a veces no manda portada: miniatura del video
        const url = p.metadata["xesam:url"] ?? ""
        const id = url.match(/youtube\.com\/watch.*[?&]v=([\w-]{11})/)?.[1]
        return id ? "https://img.youtube.com/vi/" + id + "/hqdefault.jpg" : ""
    }

    // ── Volumen de la aplicación ─────────────────────────────────────────────
    function matches(node, player) {
        const id = (player.identity || "").toLowerCase()
        const entry = (player.desktopEntry || "").toLowerCase()
        const app = (node.properties["application.name"] || "").toLowerCase()
        const bin = (node.properties["application.process.binary"] || "").toLowerCase()
        if (!id && !entry)
            return false
        return (app !== "" && (app === id || id.includes(app) || app.includes(id)))
            || (bin !== "" && (bin === entry || bin === id))
    }

    readonly property var streams: active
        ? Pipewire.nodes.values.filter(n => n.isStream && n.audio && !n.isSink && matches(n, active))
        : []

    PwObjectTracker {
        objects: root.streams
    }

    readonly property bool volumeSupported: streams.length > 0 || (active?.volumeSupported ?? false)
    readonly property real volume: streams.length > 0 ? (streams[0].audio?.volume ?? 1)
                                 : active?.volumeSupported ? active.volume : 1
    readonly property bool muted: streams.length > 0 && (streams[0].audio?.muted ?? false)

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v))
        if (streams.length > 0) {
            for (const s of streams)
                if (s.audio) {
                    s.audio.volume = v
                    if (v > 0 && s.audio.muted)
                        s.audio.muted = false
                }
        } else if (active?.volumeSupported) {
            active.volume = v
        }
    }

    function toggleMute() {
        for (const s of streams)
            if (s.audio)
                s.audio.muted = !muted
    }
}
