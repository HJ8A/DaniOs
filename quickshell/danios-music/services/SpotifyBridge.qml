// Puente con Spotify vía la extensión de Spicetify (spicetify/danios-bridge.js).
// DaniOS Music es el servidor WebSocket (solo 127.0.0.1); la extensión, dentro
// de Spotify, se conecta y envía la cola y la biblioteca, y recibe órdenes.
// MPRIS sigue usándose para lo básico (play/pausa, metadatos, posición).
import QtQuick
import QtWebSockets

Item {
    id: root

    property int port: 47321

    // Estado
    readonly property bool connected: client !== null
    property var  apis: ({})
    property var  current: null
    property var  queueNext: []
    property var  playlists: []
    property var  tracks: ({ uri: "", items: [] })
    property string lastError: ""

    // Búsqueda: cada petición lleva un número; solo vale la respuesta de la
    // última (si se escribe rápido, una respuesta lenta no pisa a otra nueva)
    property int    searchSeq: 0
    property bool   searching: false
    property var    results: ({ query: "", tracks: [], artists: [], albums: [], playlists: [] })

    property var client: null

    function sendCmd(obj) {
        if (client)
            client.sendTextMessage(JSON.stringify(obj))
    }

    function refreshQueue() { sendCmd({ cmd: "getQueue" }) }
    function loadPlaylists() { sendCmd({ cmd: "getPlaylists" }) }
    function loadTracks(uri) {
        tracks = { uri: uri, items: [], loading: true }
        sendCmd({ cmd: "getTracks", uri: uri })
    }
    function play(uri, context) { sendCmd({ cmd: "play", uri: uri, context: context || "" }) }
    function skipTo(track) { sendCmd({ cmd: "skipTo", uri: track.uri, uid: track.uid }) }
    function queueAdd(uri) { sendCmd({ cmd: "queueAdd", uri: uri }) }

    // Letras de Spotify para una canción: { uri, synced, lines: [{t (ms), text}], error }
    property var lyrics: ({ uri: "", synced: false, lines: [], error: "" })
    function getLyrics(uri) { sendCmd({ cmd: "getLyrics", uri: uri }) }
    // Si se busca sin conexión (p. ej. justo al abrir, antes de que la
    // extensión se reconecte), la búsqueda se envía al conectar
    property string pendingQuery: ""
    onConnectedChanged: if (connected && pendingQuery) search(pendingQuery)

    function search(query) {
        if (!client) {
            pendingQuery = query
            searching = query.trim() !== ""
            return
        }
        pendingQuery = ""
        searchSeq += 1
        if (!query.trim()) {
            searching = false
            results = { query: "", tracks: [], artists: [], albums: [], playlists: [] }
            return
        }
        searching = true
        sendCmd({ cmd: "search", query: query.trim(), id: searchSeq })
    }

    function handle(message) {
        let msg
        try { msg = JSON.parse(message) } catch (e) { return }
        switch (msg.type) {
        case "hello":
            apis = msg.apis || {}
            console.info("danios-music: puente conectado, APIs:", JSON.stringify(apis))
            break
        case "queue":
            current = msg.current
            queueNext = msg.next || []
            break
        case "playlists":
            playlists = msg.items || []
            break
        case "tracks":
            tracks = { uri: msg.uri, items: msg.items || [], loading: false }
            break
        case "search":
            if (msg.id !== searchSeq)          // respuesta vieja
                break
            searching = false
            results = { query: msg.query, via: msg.via, tracks: msg.tracks || [], artists: msg.artists || [],
                        albums: msg.albums || [], playlists: msg.playlists || [] }
            break
        case "lyrics":
            lyrics = { uri: msg.uri, synced: !!msg.synced, source: msg.source, lines: msg.lines || [], error: msg.error || "" }
            break
        case "error":
            searching = false
            lastError = msg.what + ": " + msg.message
            console.warn("danios-music: puente:", lastError)
            break
        }
    }

    WebSocketServer {
        id: server
        host: "127.0.0.1"
        port: root.port
        listen: true
        accept: true

        onClientConnected: socket => {
            // Una sola extensión a la vez: la nueva reemplaza a la anterior
            if (root.client && root.client !== socket)
                root.client.active = false
            root.client = socket
            socket.onTextMessageReceived.connect(root.handle)
            socket.onStatusChanged.connect(() => {
                if ((socket.status === WebSocket.Closed || socket.status === WebSocket.Error) && root.client === socket) {
                    root.client = null
                    root.current = null
                    root.queueNext = []
                }
            })
        }
        onErrorStringChanged: if (errorString) console.warn("danios-music: servidor del puente:", errorString)
    }

    // Si el puerto está ocupado (otra instancia que aún no terminó de
    // cerrarse), reintentar cada 5 s en vez de quedarse sin puente
    Timer {
        interval: 5000
        repeat: true
        running: !root.connected && server.errorString !== ""     // nunca con una extensión conectada
        onTriggered: {
            server.listen = false
            server.listen = true
        }
    }
}
