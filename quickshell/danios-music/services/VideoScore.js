// Elige el videoclip entre varios resultados de YouTube (sin dependencias:
// se puede probar con node). Puntúa cada candidato:
//
//   + el título del video contiene el nombre de la canción (por palabras)
//   + aparece el artista (en el título o en el canal)
//   + "official video", "video oficial", "videoclip"…
//   + la duración se parece a la de la canción
//   − "letra", "lyrics", "audio", "visualizer", "karaoke", "cover", "remix"…
//     (salvo que la propia canción lo diga)
//   − canal "… - Topic" (subida automática: portada fija, no videoclip)
//
// Por debajo de MIN_SCORE no hay videoclip (mejor la portada que un video
// equivocado). Con `onlyMusicVideos`, además, el título tiene que decir que es
// un video ("Video Oficial", "Official Video", "Videoclip", "Video No
// Oficial"…): descarta las subidas de la canción con la portada fija, que no
// aportan nada sobre la portada desenfocada y gastan red.
.pragma library

var MIN_SCORE = 45

function normalize(s) {
    return String(s || "").toLowerCase()
        .normalize("NFD").replace(/[̀-ͯ]/g, "")     // sin tildes
        .replace(/\$/g, "s")                                  // bardero$ → barderos
        .replace(/[^a-z0-9ñ ]+/g, " ")
        .replace(/\s+/g, " ").trim()
}

var STOP = { "the": 1, "a": 1, "el": 1, "la": 1, "los": 1, "las": 1, "de": 1, "y": 1, "feat": 1, "ft": 1, "prod": 1 }

function words(s) {
    return normalize(s).split(" ").filter(function (w) { return w.length > 1 && !STOP[w] })
}

// Parte del título de la canción presente en el texto (0..1)
function coverage(needle, hay) {
    var ws = words(needle)
    if (ws.length === 0)
        return 0
    var h = " " + normalize(hay) + " "
    var hit = 0
    for (var i = 0; i < ws.length; ++i)
        if (h.indexOf(" " + ws[i] + " ") >= 0) hit++
    return hit / ws.length
}

var BAD = /\b(letra|lyrics?|lyric video|audio|visuali[sz]er|karaoke|cover|remix|slowed|sped up|reverb|8d|instrumental|nightcore|bass boosted|reaction|tutorial|live|en vivo)\b/
var IS_VIDEO = /\b(video|videoclip|clip|mv)\b/

var GOOD = /\b(official (music )?video|video oficial|videoclip|video clip|official mv|mv oficial)\b/

function score(c, artist, title, trackLength) {
    var t = normalize(c.title)
    var ch = normalize(c.channel)
    var s = 0

    var cov = coverage(title, c.title)
    s += cov >= 1 ? 40 : cov * 30
    if (cov === 0)
        s -= 30

    var firstArtist = String(artist || "").split(/,|&| x | feat\.? | ft\.? /i)[0]
    if (coverage(firstArtist, c.title) >= 1 || coverage(firstArtist, c.channel) >= 1)
        s += 25

    if (GOOD.test(t))
        s += 20

    var bad = t.match(BAD)
    if (bad && normalize(title).indexOf(bad[0]) < 0)
        s -= 40

    if (/ topic$/.test(ch))
        s -= 50

    var d = Number(c.duration)
    if (trackLength > 0 && d > 0) {
        var diff = Math.abs(d - trackLength)
        if (diff <= 15) s += 15
        else if (diff <= 60) s += 5        // intros y finales de los videoclips
        else if (diff > 120) s -= 30
    }
    return s
}

// candidates: [{ id, title, duration, channel }]  →  { id, title, score } | null
function pick(candidates, artist, title, trackLength, onlyMusicVideos) {
    var best = null
    for (var i = 0; i < candidates.length; ++i) {
        var c = candidates[i]
        if (!c.id)
            continue
        if (onlyMusicVideos && !IS_VIDEO.test(normalize(c.title)))
            continue
        var sc = score(c, artist, title, trackLength)
        if (!best || sc > best.score)
            best = { id: c.id, title: c.title, score: sc }
    }
    return best && best.score >= MIN_SCORE ? best : null
}

// Salida de: yt-dlp --flat-playlist --print "%(id)s\t%(title)s\t%(duration)s\t%(channel)s"
function parse(text) {
    return String(text || "").trim().split("\n").map(function (line) {
        var f = line.split("\t")
        return { id: f[0], title: f[1] || "", duration: parseFloat(f[2]) || 0, channel: f[3] || "" }
    }).filter(function (c) { return c.id && c.id.length === 11 })
}

if (typeof module !== "undefined")
    module.exports = { pick: pick, score: score, parse: parse, normalize: normalize, MIN_SCORE: MIN_SCORE }
