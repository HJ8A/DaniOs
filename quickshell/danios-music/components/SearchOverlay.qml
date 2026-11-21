// Buscador (fase 4a), estilo Zen: barra de vidrio arriba al centro y, debajo,
// los resultados con portadas agrupados en Canciones / Artistas / Álbumes /
// Playlists. Se abre con un clic en la tarjeta central o con Ctrl + K.
//
//   escribir  → busca tras 250 ms sin teclear (la búsqueda la hace Spotify)
//   ↑ ↓       → mover la selección      Enter / clic → reproducir
//   +         → (solo en la fila seleccionada, canciones) añadir a la cola
//   Esc       → borra el texto; con el texto vacío, cierra
//
// Se crea solo mientras está abierto (Loader en shell.qml).
import QtQuick
import Quickshell.Widgets
import QtQuick.Effects

Item {
    id: root

    property var    bridge
    property Item   backdrop
    property color  accent: "white"
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property string fontFamily: "Rubik"
    signal closed()

    readonly property var res: bridge ? bridge.results : ({ tracks: [], artists: [], albums: [], playlists: [] })
    property int selected: 0
    property string queuedUri: ""              // feedback del botón "+"

    // Resultados aplanados: encabezados + filas (solo las filas se seleccionan)
    readonly property var entries: {
        const out = []
        const add = (title, type, items) => {
            if (!items || items.length === 0)
                return
            out.push({ header: true, title: title })
            for (const it of items)
                out.push({ header: false, type: type, data: it })
        }
        // Artistas primero: suele ser lo que se busca al escribir un nombre
        add("Artistas", "artist", res.artists)
        add("Canciones", "track", res.tracks)
        add("Álbumes", "album", res.albums)
        add("Playlists", "playlist", res.playlists)
        return out
    }
    readonly property var rows: entries.map((e, i) => e.header ? -1 : i).filter(i => i >= 0)

    // Se calcula sobre `entries` (no `rows`): al cambiar entries, rows aún
    // puede tener el valor anterior y la selección quedaba vacía
    onEntriesChanged: selected = entries.findIndex(e => !e.header)

    function move(step) {
        if (!rows.length)
            return
        const at = Math.max(0, rows.indexOf(selected))
        selected = rows[(at + step + rows.length) % rows.length]
        list.positionViewAtIndex(selected, ListView.Contain)
    }

    function activate(i) {
        const e = entries[i]
        if (!e || e.header)
            return
        bridge.play(e.data.uri)
        root.closed()
    }

    function subtitle(e) {
        const d = e.data
        switch (e.type) {
        case "track": return "Canción · " + (d.artist || "")
        case "artist": return "Artista"
        case "album": return "Álbum · " + (d.artist || "")
        case "playlist": return "Playlist" + (d.owner ? " · " + d.owner : "")
        }
        return ""
    }

    Component.onCompleted: input.forceActiveFocus()

    // Clic fuera de la barra y los resultados = cerrar
    MouseArea {
        anchors.fill: parent
        onClicked: root.closed()
    }

    // ── Barra de búsqueda ────────────────────────────────────────────────────
    Glass {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.07
        width: Math.min(680, parent.width * 0.5)
        height: 56
        radius: height / 2
        backdrop: root.backdrop
        tint: Qt.rgba(1, 1, 1, 0.1)
        borderColor: Qt.alpha(root.accent, 0.45)

        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

        Text {
            id: lens
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.bridge && root.bridge.searching ? "progress_activity" : "search"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 24
            color: root.subColor
            RotationAnimator on rotation {
                running: root.bridge ? root.bridge.searching : false
                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                onRunningChanged: if (!running) lens.rotation = 0
            }
        }

        TextInput {
            id: input
            anchors.left: lens.right
            anchors.leftMargin: 12
            anchors.right: clear.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: root.textColor
            selectionColor: Qt.alpha(root.accent, 0.5)
            font.family: root.fontFamily
            font.pixelSize: 18
            clip: true
            onTextChanged: debounce.restart()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: "Busca canciones, artistas, álbumes o playlists"
                color: Qt.alpha(root.subColor, 0.7)
                font: input.font
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (input.text !== "")
                        input.text = ""
                    else
                        root.closed()
                } else if (event.key === Qt.Key_Down) {
                    root.move(1)
                } else if (event.key === Qt.Key_Up) {
                    root.move(-1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activate(root.selected)
                } else {
                    return
                }
                event.accepted = true
            }
        }

        Text {
            id: clear
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text !== ""
            text: "close"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: root.subColor
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: { input.text = ""; input.forceActiveFocus() }
            }
        }
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: root.bridge.search(input.text)
    }

    // ── Resultados ───────────────────────────────────────────────────────────
    Glass {
        id: panel
        anchors.horizontalCenter: bar.horizontalCenter
        anchors.top: bar.bottom
        anchors.topMargin: 10
        width: bar.width
        height: Math.min(list.contentHeight + 16, root.height * 0.62)
        visible: input.text !== "" && (root.entries.length > 0 || (root.bridge && !root.bridge.searching))
        radius: 22
        backdrop: root.backdrop
        tint: Qt.rgba(1, 1, 1, 0.07)

        MouseArea { anchors.fill: parent }       // no cerrar al hacer clic dentro

        Text {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            text: "Sin resultados"
            color: root.subColor
            font.family: root.fontFamily
            font.pixelSize: 13
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.entries
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool header: modelData.header
                readonly property bool sel: !header && root.selected === index
                width: list.width
                height: header ? 30 : 56

                // Encabezado de grupo
                Text {
                    visible: row.header
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: row.header ? row.modelData.title.toUpperCase() : ""
                    color: root.subColor
                    font.family: root.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.weight: Font.DemiBold
                }

                // Fila
                Rectangle {
                    visible: !row.header
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 12
                    color: row.sel ? Qt.alpha(root.accent, 0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                ClippingRectangle {   // recorta de verdad por las esquinas (clip: true no)
                    id: thumb
                    visible: !row.header
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42
                    height: 42
                    radius: !row.header && row.modelData.type === "artist" ? 21 : 7
                    color: Qt.alpha(root.textColor, 0.08)
                    
                    Image {
                        anchors.fill: parent
                        source: row.header ? "" : (row.modelData.data.image || "")
                        sourceSize: Qt.size(84, 84)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }
                Column {
                    visible: !row.header
                    anchors.left: thumb.right
                    anchors.leftMargin: 12
                    anchors.right: addBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: row.header ? "" : (row.modelData.data.name || "")
                        elide: Text.ElideRight
                        color: row.sel ? root.accent : root.textColor
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: row.header ? "" : root.subtitle(row.modelData)
                        elide: Text.ElideRight
                        color: root.subColor
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    visible: !row.header
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = row.index
                    onClicked: root.activate(row.index)
                }

                // "+" a la cola: solo en la fila seleccionada y solo canciones
                Rectangle {
                    id: addBtn
                    readonly property bool done: !row.header && root.queuedUri === row.modelData.data.uri
                    visible: row.sel && row.modelData.type === "track"
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: addMa.containsMouse ? Qt.alpha(root.accent, 0.35) : Qt.alpha(root.textColor, 0.1)
                    Text {
                        anchors.centerIn: parent
                        text: addBtn.done ? "check" : "add"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: addBtn.done ? root.accent : root.textColor
                    }
                    MouseArea {
                        id: addMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.bridge.queueAdd(row.modelData.data.uri)
                            root.queuedUri = row.modelData.data.uri
                            doneTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: doneTimer
        interval: 1400
        onTriggered: root.queuedUri = ""
    }
}
