// DaniOS Music — puente de Spicetify (extensión de Spotify).
//
// Le pasa a DaniOS Music (programa propio, Quickshell) lo que MPRIS no da:
// la cola, las playlists y sus canciones; y recibe órdenes (reproducir algo,
// saltar a una canción de la cola).
//
// Canal: WebSocket a ws://127.0.0.1:47321 (DaniOS Music es el servidor, solo
// local). Si DaniOS Music está cerrado, reintenta cada 5 s.
// Escrita a la defensiva: Spotify cambia sus APIs internas sin avisar; si algo
// falta se informa en el mensaje "hello" en lugar de romper Spotify.
//
// Instalación: copiar a ~/.config/spicetify/Extensions/ y
//   spicetify config extensions danios-bridge.js && spicetify apply
(function daniosBridge() {
    "use strict"

    const VERSION = 1
    const URL = "ws://127.0.0.1:47321"
    const RETRY_MS = 5000
    const QUEUE_CHECK_MS = 2000

    // Espera a que Spicetify esté listo
    if (!window.Spicetify?.Player?.origin || !Spicetify.Platform) {
        setTimeout(daniosBridge, 300)
        return
    }

    let ws = null
    let queueTimer = null
    let lastQueueKey = ""

    // ── Utilidades ───────────────────────────────────────────────────────────
    const safe = (fn, fallback = null) => {
        try { return fn() } catch (e) { return fallback }
    }

    function send(type, data) {
        if (ws && ws.readyState === WebSocket.OPEN)
            ws.send(JSON.stringify({ type, ...data }))
    }

    function pickImage(images) {
        if (!Array.isArray(images) || images.length === 0)
            return ""
        // la más pequeña (~64 px): basta para la lista y pesa poco
        const sorted = images.slice().sort((a, b) => (a.width || a.height || 999) - (b.width || b.height || 999))
        const img = sorted[0]
        return toHttp(img.url || img.uri || "")
    }

    // spotify:image:<id> → https://i.scdn.co/image/<id>
    function toHttp(u) {
        if (typeof u !== "string")
            return ""
        if (u.startsWith("spotify:image:"))
            return "https://i.scdn.co/image/" + u.slice("spotify:image:".length)
        // mosaico de 4 portadas (playlists): se usa la primera
        if (u.startsWith("spotify:mosaic:"))
            return "https://i.scdn.co/image/" + u.slice("spotify:mosaic:".length).split(":")[0]
        return u
    }

    // Pista del estado del reproductor / cola → formato común
    function fromProvided(t) {
        if (!t)
            return null
        const m = t.metadata || t.contextTrack?.metadata || {}
        const uri = t.uri || t.contextTrack?.uri || ""
        return {
            uri,
            uid: t.uid || t.contextTrack?.uid || "",
            name: m.title || t.name || "",
            artist: m.artist_name || (t.artists || []).map(a => a.name).join(", ") || "",
            image: toHttp(m.image_small_url || m.image_url || "") || pickImage(t.images || t.album?.images),
            duration: Number(m.duration || t.duration?.milliseconds || t.duration_ms || 0)
        }
    }

    // ── Cola ─────────────────────────────────────────────────────────────────
    function readQueue() {
        const q = safe(() => Spicetify.Queue) || {}
        const next = (q.nextTracks || q.nextUp || []).concat(q.queued || [])
            .map(fromProvided)
            .filter(t => t && t.uri && !t.uri.startsWith("spotify:delimiter") && t.name)
            .slice(0, 50)
        const prev = (q.prevTracks || []).map(fromProvided).filter(t => t && t.name).slice(-20)
        const current = fromProvided(q.track || Spicetify.Player.data?.item)
        return { current, next, prev }
    }

    function pushQueue(force) {
        const queue = readQueue()
        const key = [queue.current?.uri, ...queue.next.map(t => t.uid || t.uri)].join("|")
        if (!force && key === lastQueueKey)
            return
        lastQueueKey = key
        send("queue", queue)
    }

    // ── Biblioteca ───────────────────────────────────────────────────────────
    async function getPlaylists() {
        const api = Spicetify.Platform.RootlistAPI
        if (!api?.getContents)
            return send("error", { what: "getPlaylists", message: "RootlistAPI no disponible" })
        const root = await api.getContents()
        const out = []
        const walk = items => {
            for (const it of items || []) {
                if (it.type === "folder")
                    walk(it.items)
                else if (it.type === "playlist")
                    out.push({
                        uri: it.uri,
                        name: it.name || "",
                        owner: it.owner?.name || it.owner?.displayName || "",
                        image: pickImage(it.images) || toHttp(it.image || ""),
                        count: it.totalLength || it.totalItemCount || 0
                    })
            }
        }
        walk(root.items)
        // "Tus me gusta" al principio
        out.unshift({ uri: "spotify:collection:tracks", name: "Tus me gusta", owner: "", image: "", count: 0 })
        send("playlists", { items: out })
    }

    async function getTracks(uri) {
        let items = []
        if (uri === "spotify:collection:tracks") {
            const api = Spicetify.Platform.LibraryAPI
            const res = await api?.getTracks?.({ limit: 300 })
            items = (res?.items || []).map(fromProvided)
        } else {
            const api = Spicetify.Platform.PlaylistAPI
            if (!api?.getContents)
                return send("error", { what: "getTracks", message: "PlaylistAPI no disponible" })
            const res = await api.getContents(uri, { limit: 300 })
            items = (res?.items || []).map(fromProvided)
        }
        send("tracks", { uri, items: items.filter(t => t && t.uri) })
    }

    // ── Búsqueda ─────────────────────────────────────────────────────────────
    // GraphQL interno de Spotify, "searchModalResults" (el buscador de Ctrl+K
    // del propio cliente). Devuelve los resultados principales MEZCLADOS
    // (topResultsV2.itemsV2, cada uno con su __typename); aquí se agrupan.
    // Medido en Spotify 1.3.8: la Web API por CosmosAsync responde 429 y no
    // existe "searchDesktop", por eso solo esta vía.
    const names = arr => (arr || []).map(a => a?.profile?.name || a?.name).filter(Boolean).join(", ")
    const img = sources => pickImage((sources || []).map(x => ({ url: x.url, width: x.width, height: x.height })))

    async function search(query, id) {
        const G = Spicetify.GraphQL
        const def = G?.Definitions?.searchModalResults
        if (!def)
            return send("error", { what: "search", message: "GraphQL searchModalResults no disponible" })
        const r = await G.Request(def, {
            searchTerm: query, offset: 0, limit: 12, numberOfTopResults: 12, includeAudiobooks: false,
            includeArtistHasConcertsField: false, includePreReleases: false, includeLocalConcertsField: false,
            includeAuthors: false })
        const out = { tracks: [], artists: [], albums: [], playlists: [] }
        for (const it of r?.data?.searchV2?.topResultsV2?.itemsV2 || []) {
            const d = it?.item?.data
            if (!d || !d.uri)
                continue
            switch (d.__typename) {
            case "Track":
                out.tracks.push({ uri: d.uri, name: d.name || "", artist: names(d.artists?.items),
                                  image: img(d.albumOfTrack?.coverArt?.sources),
                                  duration: d.duration?.totalMilliseconds || 0 })
                break
            case "Artist":
                out.artists.push({ uri: d.uri, name: d.profile?.name || "", image: img(d.visuals?.avatarImage?.sources) })
                break
            case "Album":
                out.albums.push({ uri: d.uri, name: d.name || "", artist: names(d.artists?.items),
                                  image: img(d.coverArt?.sources) })
                break
            case "Playlist":
                out.playlists.push({ uri: d.uri, name: d.name || "", owner: d.ownerV2?.data?.name || "",
                                     image: img(d.images?.items?.[0]?.sources) })
                break
            }
        }
        send("search", { id, query, via: "graphql", ...out })
    }

    // ── Letras (las de Spotify: spclient "color-lyrics", la misma que usa su
    // vista de letras). Si no hay, DaniOS Music prueba LRCLIB por su cuenta.
    async function getLyrics(uri) {
        const id = String(uri || "").split(":").pop()
        let lines = [], synced = false, source = "spotify", error = ""
        try {
            const r = await Spicetify.CosmosAsync.get(
                `https://spclient.wg.spotify.com/color-lyrics/v2/track/${id}?format=json&vocalRemoval=false&market=from_token`)
            const ly = r?.lyrics
            if (ly?.lines?.length) {
                synced = ly.syncType === "LINE_SYNCED"
                lines = ly.lines.map(l => ({ t: Number(l.startTimeMs) || 0, text: String(l.words || "").replace(/♪/g, "").trim() }))
                                 .filter(l => l.text !== "")
            } else {
                error = r?.code ? "código " + r.code : "sin letra"
            }
        } catch (e) {
            error = String(e)
        }
        send("lyrics", { uri, synced, source, lines, error })
    }

    // ── Órdenes de DaniOS Music ──────────────────────────────────────────────
    async function handle(msg) {
        switch (msg.cmd) {
        case "getQueue":
            return pushQueue(true)
        case "getPlaylists":
            return getPlaylists()
        case "getTracks":
            return getTracks(msg.uri)
        case "play": {         // una playlist entera o una canción dentro de su playlist
            let context = msg.context
            // "Tus me gusta" como contexto: Spotify lo llama spotify:user:<usuario>:collection
            if (context === "spotify:collection:tracks" && Spicetify.Platform.username)
                context = "spotify:user:" + Spicetify.Platform.username + ":collection"
            if (context)
                return Spicetify.Player.playUri(context, {}, { skipTo: { uri: msg.uri } })
            return Spicetify.Player.playUri(msg.uri)
        }
        case "search":
            return search(String(msg.query || ""), msg.id)
        case "getLyrics":
            return getLyrics(msg.uri)
        case "queueAdd":       // botón "+" del buscador
            return Spicetify.addToQueue([{ uri: msg.uri }])
        case "skipTo":         // saltar a una canción de la cola
            return Spicetify.Platform.PlayerAPI.skipTo({ uri: msg.uri, uid: msg.uid })
        }
    }

    // ── Conexión ─────────────────────────────────────────────────────────────
    function connect() {
        ws = new WebSocket(URL)
        ws.onopen = () => {
            send("hello", {
                version: VERSION,
                apis: {
                    queue: !!safe(() => Spicetify.Queue),
                    rootlist: !!Spicetify.Platform.RootlistAPI?.getContents,
                    playlist: !!Spicetify.Platform.PlaylistAPI?.getContents,
                    library: !!Spicetify.Platform.LibraryAPI?.getTracks,
                    skipTo: !!Spicetify.Platform.PlayerAPI?.skipTo,
                    playUri: !!Spicetify.Player.playUri,
                    search: !!Spicetify.GraphQL?.Definitions?.searchModalResults,
                    lyrics: !!Spicetify.CosmosAsync?.get,
                    queueAdd: !!Spicetify.addToQueue
                }
            })
            pushQueue(true)
            queueTimer = setInterval(() => pushQueue(false), QUEUE_CHECK_MS)
        }
        ws.onmessage = ev => {
            let msg
            try { msg = JSON.parse(ev.data) } catch (e) { return }
            handle(msg).catch?.(e => send("error", { what: msg.cmd, message: String(e) }))
        }
        ws.onclose = () => {
            clearInterval(queueTimer)
            queueTimer = null
            ws = null
            setTimeout(connect, RETRY_MS)
        }
        ws.onerror = () => {}          // onclose se encarga del reintento
    }

    Spicetify.Player.addEventListener("songchange", () => setTimeout(() => pushQueue(true), 300))
    connect()
})()
