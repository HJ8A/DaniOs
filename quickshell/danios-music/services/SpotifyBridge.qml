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
        case "error":
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
}
