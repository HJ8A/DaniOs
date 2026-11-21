// Busca el videoclip de la canción en YouTube con yt-dlp y entrega la URL de
// SOLO VIDEO (sin audio: el sonido lo pone Spotify).
//
// 1. Buscar: 6 resultados ("--flat-playlist", sin abrir cada video) y elegir
//    con VideoScore.js (título, artista, duración, "video oficial"; descarta
//    letras, audios, canales "- Topic"…). Sin un candidato bueno → "none".
// 2. URL: del id elegido, formato VP9 → H.264 hasta `maxHeight` (GPU Intel).
//
// Caché (~/.cache/danios-music/videos.json, v2): canción → id, o "sin video"
// durante 7 días. La URL caduca (~6 h), así que se pide cada vez desde el id.
// Un fallo de red no se guarda (se decide con el código de salida).
// Si cambia la canción mientras tanto, se cancela y se empieza de nuevo.
import QtQuick
import Quickshell
import Quickshell.Io
import "VideoScore.js" as Score

Item {
    id: root

    property var  player                     // MprisPlayer activo
    property int  maxHeight: 1080
    property bool enabled: true
    property bool onlyMusicVideos: true

    // Salida
    property string url: ""
    property string videoTitle: ""
    property string status: "idle"           // idle | disabled | resolving | ready | none | error
    // Franjas negras del propio video: zona útil {x, y, w, h} sobre {vw, vh}
    // (o null). Se detecta una vez por video con ffmpeg cropdetect y se guarda.
    property var    crop: null
    property bool   usingFallback: false
    property string currentId: ""

    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property real   trackLength: player && player.lengthSupported ? player.length : 0
    readonly property string key: (artist && title) ? (artist + " - " + title).toLowerCase() : ""

    readonly property int    cacheVersion: 2
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/danios-music/videos.json"
    property var  cache: ({})
    property bool cacheLoaded: false

    // Formato (medido en Qt 6.12 con el backend FFmpeg, 2026-11-20):
    //   · MP4 por https (H.264 o AV1): admite saltos (3–4 s) → sincronizable;
    //   · WebM (VP9) por https: Qt lo marca "no seekable" e ignora los saltos;
    //   · HLS: admite saltos pero tarda ~7 s (antes: video "congelado").
    // Todos los decodifica la GPU Intel (VA-API: H.264, VP9, AV1).
    readonly property string format: {
        const h = "[height<=" + maxHeight + "]"
        return "bv*[protocol=https][ext=mp4][vcodec^=avc1]" + h
             + "/bv*[protocol=https][ext=mp4][vcodec^=av01]" + h
             + "/bv*[protocol^=m3u8][vcodec^=avc1]" + h
             + "/bv*[protocol^=m3u8][vcodec^=vp09]" + h
             + "/bv*" + h
    }
    // Plan B: a veces YouTube responde 403 a la URL directa (depende del video
    // y del cliente que use yt-dlp; medido). HLS funciona en esos casos.
    readonly property string fallbackFormat: {
        const h = "[height<=" + maxHeight + "]"
        return "bv*[protocol^=m3u8][vcodec^=avc1]" + h + "/bv*[protocol^=m3u8]" + h + "/bv*" + h
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        atomicWrites: true
        blockLoading: true
        onLoaded: {
            let data = {}
            try { data = JSON.parse(text()) } catch (e) {}
            // Formato viejo (búsqueda simple, sin puntuar) → se descarta
            root.cache = (data && data.v === root.cacheVersion && data.items) ? data.items : {}
            root.cacheLoaded = true
            root.resolve()
        }
        onLoadFailed: {
            root.cache = {}
            root.cacheLoaded = true
            root.resolve()
        }
    }

    function remember(k, value) {
        const next = Object.assign({}, cache)
        next[k] = value
        cache = next
        cacheFile.setText(JSON.stringify({ v: cacheVersion, items: next }))
    }

    // Spotify reenvía los metadatos a menudo y a veces llegan incompletos
    // (sin artista) un instante: solo una canción DISTINTA reinicia la búsqueda.
    property string resolvedKey: ""
    onKeyChanged: {
        if (key && key !== resolvedKey)
            resolve()
    }
    onEnabledChanged: resolve()
    onOnlyMusicVideosChanged: resolve()

    // Pequeña espera: los metadatos de MPRIS llegan en varios pasos (título,
    // luego artista); así no se lanza una búsqueda por cada paso.
    Timer {
        id: debounce
        interval: 400
        onTriggered: root.start()
    }

    function resolve() {
        url = ""
        crop = null
        usingFallback = false
        cropProc.running = false
        videoTitle = ""
        searchProc.running = false
        urlProc.running = false
        if (!enabled) {
            status = "disabled"
            return
        }
        if (!key || !cacheLoaded) {
            status = "idle"
            return
        }
        resolvedKey = key
        status = "resolving"
        debounce.restart()
    }

    property string pendingKey: ""

    function start() {
        if (!key)
            return
        pendingKey = key
        const hit = cache[key]
        if (hit && hit.id) {
            fetchUrl(hit.id, hit.title)
            return
        }
        // "Sin video" se recuerda 7 días (por si luego lo suben). Si se cambió
        // el filtro, la entrada guardada no vale.
        if (hit && hit.none && hit.strict === onlyMusicVideos && Date.now() - hit.at < 7 * 86400000) {
            status = "none"
            return
        }
        searchProc.command = ["yt-dlp", "--flat-playlist", "--no-warnings",
                              "--print", "%(id)s\t%(title)s\t%(duration)s\t%(channel)s",
                              "ytsearch6:" + artist + " " + title + " official video"]
        searchProc.running = true
    }

    function fetchUrl(id, vtitle) {
        videoTitle = vtitle || ""
        currentId = id
        const hit = cache[key]
        crop = hit && hit.crop !== undefined ? hit.crop : null
        urlProc.command = ["yt-dlp", "--no-warnings", "--no-playlist", "-f", usingFallback ? fallbackFormat : format,
                           "--print", "urls", "--", id]
        urlProc.running = true
    }

    // El reproductor no pudo con la URL (error o no arrancó): una vez, en HLS
    function fallback() {
        if (usingFallback || !currentId || status !== "ready") {
            status = "error"
            return
        }
        usingFallback = true
        url = ""
        status = "resolving"
        fetchUrl(currentId, videoTitle)
    }

    // Franjas negras: solo fotogramas clave de un tramo de 40 s (barato), una
    // vez por video; el resultado se guarda en la caché.
    function detectCrop() {
        const hit = cache[key]
        if (!hit || hit.crop !== undefined || !url)
            return
        // Con su propia URL HLS: la directa a veces da 403 a ffmpeg
        cropProc.command = ["bash", "-c",
            'u=$(yt-dlp --no-warnings -f "$1" --print urls -- "$2" | head -n1) && [ -n "$u" ] && ' +
            'exec ffmpeg -hide_banner -nostats -ss 15 -t 40 -skip_frame nokey -i "$u" ' +
            '-vf cropdetect=limit=24:round=2:reset=1 -an -f null -',
            "cropdetect", fallbackFormat, hit.id]
        cropProc.forKey = key
        cropProc.running = true
    }

    // 1. Búsqueda y elección
    Process {
        id: searchProc
        stdout: StdioCollector { id: searchOut }
        onExited: (code, exitStatus) => {
            if (root.pendingKey !== root.key)
                return
            if (code !== 0) {
                root.status = "error"
                return
            }
            const best = Score.pick(Score.parse(searchOut.text), root.artist, root.title,
                                    root.trackLength, root.onlyMusicVideos)
            if (!best) {
                root.remember(root.key, { none: true, strict: root.onlyMusicVideos, at: Date.now() })
                root.status = "none"
                return
            }
            root.remember(root.key, { id: best.id, title: best.title, score: best.score })
            root.fetchUrl(best.id, best.title)
        }
    }

    // 2. URL de solo video
    Process {
        id: urlProc
        stdout: StdioCollector { id: urlOut }
        onExited: (code, exitStatus) => {
            if (root.pendingKey !== root.key)
                return
            const u = urlOut.text.trim().split("\n")[0] || ""
            if (code === 0 && u.startsWith("http")) {
                root.url = u
                root.status = "ready"
                root.detectCrop()
            } else {
                root.status = "error"
            }
        }
    }

    // 3. Franjas negras (cropdetect escribe en stderr)
    Process {
        id: cropProc
        property string forKey: ""
        stderr: StdioCollector { id: cropOut }
        onExited: (code, exitStatus) => {
            const k = forKey
            const hit = root.cache[k]
            if (!hit || !hit.id)
                return
            const text = cropOut.text
            const size = text.match(/Video: [^\n]*?(\d{3,4})x(\d{3,4})/)
            const all = text.match(/crop=(\d+):(\d+):(\d+):(\d+)/g)
            let crop = null
            if (code === 0 && size && all) {
                // Recorte de cada fotograma clave por separado: se usa el MÁS
                // REPETIDO (ignora fotogramas con letra o efectos sobre las
                // franjas); empate → el de mayor área
                const count = {}
                for (const c of all) count[c] = (count[c] || 0) + 1
                const area = c => { const v = c.match(/\d+/g); return v[0] * v[1] }
                const best = Object.keys(count).sort((a, b) => count[b] - count[a] || area(b) - area(a))[0]
                const m = best.match(/crop=(\d+):(\d+):(\d+):(\d+)/)
                const vw = +size[1], vh = +size[2], w = +m[1], h = +m[2], x = +m[3], y = +m[4]
                // Solo si las franjas son apreciables (> 3 % de un lado)
                if (w > vw * 0.25 && h > vh * 0.25 && (w < vw * 0.97 || h < vh * 0.97))
                    crop = { x: x, y: y, w: w, h: h, vw: vw, vh: vh }
            } else if (code !== 0) {
                return                        // fallo (red, 403…): se reintenta otro día
            }
            root.remember(k, Object.assign({}, hit, { crop: crop }))
            if (k === root.key)
                root.crop = crop
        }
    }
}
