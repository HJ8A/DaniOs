// Cola y playlists a la izquierda (fase 3). Sin contenedor: solo las pestañas
// van en una cápsula de vidrio; las canciones flotan sobre el video (con una
// sombra suave para que se lean sobre cualquier imagen) y se desvanecen arriba
// y abajo, como un scroll del que van apareciendo.
//   · "A continuación": la canción actual y la cola (clic = saltar a esa)
//   · "Playlists": tu biblioteca → canciones de la playlist (clic = reproducir
//     esa canción dentro de su playlist)
// Datos y órdenes por el puente de Spicetify (services/SpotifyBridge.qml).
// Las listas son ListView: solo se crean las filas visibles; portadas
// pequeñas, asíncronas y en caché.
// Al pasar el mouse la fila se agranda y las de abajo se encogen (las de
// arriba no cambian: así la fila bajo el cursor no se mueve y no "tiembla").
// Arriba y abajo la lista se desvanece.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property Item   backdrop                // el video (para el vidrio de las pestañas)
    property var    bridge
    property color  accent: "white"
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property string fontFamily: "Rubik"

    property string tab: "queue"            // queue | playlists
    property var    openPlaylist: null      // playlist abierta (o null = lista de playlists)

    function mmss(ms) {
        const s = Math.floor((ms || 0) / 1000)
        return s > 0 ? Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") : ""
    }

    // Las playlists se piden cuando hacen falta: pestaña abierta + puente
    // conectado, en cualquier orden (también tras reconectarse Spotify)
    readonly property bool wantsPlaylists: tab === "playlists" && !!bridge && bridge.connected
    onWantsPlaylistsChanged: if (wantsPlaylists && bridge.playlists.length === 0) bridge.loadPlaylists()

    // ── Fila (canción o playlist) ────────────────────────────────────────────
    component Row_: Item {
        id: row
        property string image: ""
        property string title: ""
        property string subtitle: ""
        property string trailing: ""
        property bool   highlighted: false
        property bool   roundImage: false
        property int    rowIndex: -1           // índice en la lista (-1 = fija, sin efecto)
        property QtObject pal
        signal activated()

        // Ampliación: la fila bajo el mouse crece; las de abajo se encogen
        readonly property int hover: ListView.view ? ListView.view.hoverIndex : -1
        readonly property real targetHeight: hover < 0 || rowIndex < 0 ? 52
                                           : rowIndex === hover ? 66
                                           : rowIndex > hover ? (rowIndex === hover + 1 ? 50 : 44) : 52

        width: ListView.view ? ListView.view.width : 0
        height: targetHeight
        Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 10
            color: row.highlighted ? Qt.alpha(row.pal.accent, 0.18)
                 : rowMa.containsMouse ? Qt.alpha(row.pal.text, 0.08) : "transparent"
        }
        Rectangle {
            id: thumb
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(28, row.height - 14)
            height: width
            radius: row.roundImage ? width / 2 : 7
            color: Qt.alpha(row.pal.text, 0.08)
            clip: true
            Image {
                anchors.fill: parent
                source: row.image
                sourceSize: Qt.size(80, 80)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            Text {
                anchors.centerIn: parent
                visible: row.image === ""
                text: "music_note"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: row.pal.sub
            }
        }
        Column {
            anchors.left: thumb.right
            anchors.leftMargin: 10
            anchors.right: trail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: row.title
                elide: Text.ElideRight
                color: row.highlighted ? row.pal.accent : row.pal.text
                font.family: row.pal.font
                font.pixelSize: row.rowIndex >= 0 && row.rowIndex === row.hover ? 14 : 13
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                elide: Text.ElideRight
                color: row.pal.sub
                font.family: row.pal.font
                font.pixelSize: 11
            }
        }
        Text {
            id: trail
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing
            color: row.pal.sub
            font.family: row.pal.font
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
            onContainsMouseChanged: {
                const v = row.ListView.view
                if (!v || row.rowIndex < 0)
                    return
                if (containsMouse)
                    v.enterRow(row.rowIndex)
                else
                    v.leaveRow(row.rowIndex)
            }
        }
    }

    // Lista con el estado de la ampliación. Al salir de una fila se espera un
    // poco antes de quitarla, por si el mouse entra en la de al lado.
    component HoverList: ListView {
        id: hl
        property int hoverIndex: -1
        function enterRow(i) { leaveTimer.stop(); hoverIndex = i }
        function leaveRow(i) { if (hoverIndex === i) leaveTimer.restart() }
        Timer { id: leaveTimer; interval: 90; onTriggered: hl.hoverIndex = -1 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
    }

    component TabChip: Rectangle {
        id: chip
        property string label
        property bool active: false
        property QtObject pal
        signal clicked()
        height: 30
        width: chipText.implicitWidth + 24
        radius: 15
        color: active ? Qt.alpha(pal.accent, 0.22) : chipMa.containsMouse ? Qt.alpha(pal.text, 0.08) : "transparent"
        border.color: active ? Qt.alpha(pal.accent, 0.6) : Qt.alpha(pal.text, 0.15)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? chip.pal.accent : chip.pal.sub
            font.family: chip.pal.font
            font.pixelSize: 12
            font.weight: chip.active ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    readonly property QtObject pal: QtObject {
        property color accent: root.accent
        property color text: root.textColor
        property color sub: root.subColor
        property string font: root.fontFamily
    }

    // ── Cabecera ─────────────────────────────────────────────────────────────
    // Las dos pestañas juntas en una cápsula de vidrio
    Glass {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        backdrop: root.backdrop
        height: 42
        width: tabs.implicitWidth + 12
        radius: height / 2
        tint: Qt.rgba(1, 1, 1, 0.06)
        blur: 0.8

        Row {
            id: tabs
            anchors.centerIn: parent
            spacing: 4
            TabChip { pal: root.pal; label: "A continuación"; active: root.tab === "queue"; onClicked: root.tab = "queue" }
            TabChip { pal: root.pal; label: "Playlists"; active: root.tab === "playlists"; onClicked: { root.tab = "playlists"; root.openPlaylist = null } }
        }
    }

    // Máscara de desvanecido: opaca en el centro, transparente en los bordes
    Item {
        id: fadeMask
        anchors.fill: body
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.16; color: "black" }
                GradientStop { position: 0.8;  color: "black" }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
    }

    Item {
        id: body
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0
            maskSpreadAtMin: 1
            // sin fondo detrás: sombra suave para leer sobre cualquier video
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.85
            shadowBlur: 0.5
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 0
        anchors.rightMargin: 8
        anchors.bottomMargin: 8

        // Sin la extensión
        Column {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: !(root.bridge && root.bridge.connected)
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "link_off"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 28
                color: root.subColor
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Esperando a Spotify…\nLa cola y las playlists llegan con la extensión «danios-bridge» de Spicetify."
                color: root.subColor
                font.family: root.fontFamily
                font.pixelSize: 12
            }
        }

        // ── A continuación ───────────────────────────────────────────────────
        HoverList {
            id: queueList
            anchors.fill: parent
            visible: root.bridge && root.bridge.connected && root.tab === "queue"
            model: root.bridge ? root.bridge.queueNext : []
            header: Column {
                width: queueList.width
                visible: !!(root.bridge && root.bridge.current)
                Text {
                    leftPadding: 10
                    text: "Sonando"
                    color: root.subColor
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                Row_ {
                    pal: root.pal
                    width: queueList.width
                    highlighted: true
                    image: root.bridge?.current?.image ?? ""
                    title: root.bridge?.current?.name ?? ""
                    subtitle: root.bridge?.current?.artist ?? ""
                    trailing: root.mmss(root.bridge?.current?.duration)
                }
                Text {
                    leftPadding: 10
                    topPadding: 8
                    visible: queueList.count > 0
                    text: "A continuación"
                    color: root.subColor
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
            }
            delegate: Row_ {
                required property var modelData
                required property int index
                rowIndex: index
                pal: root.pal
                image: modelData.image || ""
                title: modelData.name || ""
                subtitle: modelData.artist || ""
                trailing: root.mmss(modelData.duration)
                onActivated: root.bridge.skipTo(modelData)
            }
        }

        // ── Playlists ────────────────────────────────────────────────────────
        HoverList {
            id: playlistList
            anchors.fill: parent
            visible: root.bridge && root.bridge.connected && root.tab === "playlists" && !root.openPlaylist
            model: root.bridge ? root.bridge.playlists : []
            delegate: Row_ {
                required property var modelData
                required property int index
                rowIndex: index
                pal: root.pal
                image: modelData.image || ""
                title: modelData.name || ""
                subtitle: modelData.uri === "spotify:collection:tracks" ? "Tu biblioteca"
                        : (modelData.owner || "") + (modelData.count ? " · " + modelData.count + (modelData.count === 1 ? " canción" : " canciones") : "")
                onActivated: {
                    root.openPlaylist = modelData
                    root.bridge.loadTracks(modelData.uri)
                }
            }
        }

        // ── Canciones de una playlist ────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.bridge && root.bridge.connected && root.tab === "playlists" && !!root.openPlaylist

            Row_ {
                id: back
                pal: root.pal
                width: parent.width
                image: ""
                title: root.openPlaylist ? root.openPlaylist.name : ""
                subtitle: "← Volver a Playlists"
                onActivated: root.openPlaylist = null
            }
            Text {
                anchors.centerIn: parent
                visible: !!root.bridge?.tracks?.loading
                text: "Cargando…"
                color: root.subColor
                font.family: root.fontFamily
                font.pixelSize: 12
            }
            HoverList {
                id: trackList
                anchors.top: back.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                model: root.openPlaylist && root.bridge && root.bridge.tracks.uri === root.openPlaylist.uri ? root.bridge.tracks.items : []
                delegate: Row_ {
                    required property var modelData
                    required property int index
                    rowIndex: index
                    pal: root.pal
                    image: modelData.image || ""
                    title: modelData.name || ""
                    subtitle: modelData.artist || ""
                    trailing: root.mmss(modelData.duration)
                    highlighted: root.bridge?.current?.uri === modelData.uri
                    onActivated: root.bridge.play(modelData.uri, root.openPlaylist.uri)
                }
            }
        }
    }
}
