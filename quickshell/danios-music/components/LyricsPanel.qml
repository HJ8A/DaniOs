// Panel de letras (fase 4b), a la derecha y simétrico a la cola: sin
// contenedor, inclinado hacia el otro lado, desvanecido arriba y abajo.
//
// Sincronizada: la línea que suena va grande y del color de la canción, las
// demás se atenúan según la distancia y la lista se desplaza sola; clic en una
// línea = saltar a ese momento. Sin tiempos: letra fija con scroll.
//
// Rendimiento: la posición se ESTIMA con el reloj desde la última lectura de
// Spotify (no se le pregunta a cada momento) y se corrige cada 2 s; el
// temporizador solo corre con el panel visible, letra sincronizada y música.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var    player
    property var    lyrics               // services/LyricsService.qml
    property Item   backdrop
    property color  accent: "white"
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property string fontFamily: "Rubik"

    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool synced: lyrics ? lyrics.synced : false
    readonly property var  lines: lyrics ? lyrics.lines : []

    // ── Posición estimada ────────────────────────────────────────────────────
    property double baseMs: 0
    property double baseAt: 0
    property double nowMs: 0
    function resync() {
        if (!player)
            return
        player.positionChanged()
        baseMs = player.position * 1000
        baseAt = Date.now()
        nowMs = baseMs
    }
    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.synced && root.playing
        property int ticks: 0
        onTriggered: {
            if (++ticks % 8 === 0)
                root.resync()                       // cada 2 s
            else
                root.nowMs = root.baseMs + (Date.now() - root.baseAt)
        }
        onRunningChanged: if (running) root.resync()
    }
    onLinesChanged: resync()

    readonly property int current: {
        if (!synced || !lines.length)
            return -1
        let lo = 0, hi = lines.length - 1, ans = -1
        const t = nowMs + 150                       // un pelín adelantado: se siente a tiempo
        while (lo <= hi) {                           // búsqueda binaria
            const mid = (lo + hi) >> 1
            if (lines[mid].t <= t) { ans = mid; lo = mid + 1 } else hi = mid - 1
        }
        return ans
    }
    // Desplazamiento suave hasta centrar la línea actual
    onCurrentChanged: {
        if (current < 0)
            return
        const from = list.contentY
        list.positionViewAtIndex(current, ListView.Center)
        const to = list.contentY
        list.contentY = from
        scrollAnim.to = to
        scrollAnim.restart()
    }
    NumberAnimation {
        id: scrollAnim
        target: list
        property: "contentY"
        duration: 450
        easing.type: Easing.OutCubic
    }

    function seekTo(ms) {
        if (!player || !player.canSeek || ms < 0)
            return
        player.position = ms / 1000
        baseMs = ms
        baseAt = Date.now()
        nowMs = ms
    }

    // ── Cabecera ─────────────────────────────────────────────────────────────
    Glass {
        id: header
        anchors.top: parent.top
        anchors.right: parent.right
        backdrop: root.backdrop
        height: 42
        width: headRow.implicitWidth + 28
        radius: height / 2
        tint: Qt.rgba(1, 1, 1, 0.06)
        blur: 0.8
        Row {
            id: headRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "lyrics"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: root.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Letras"
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !!root.lyrics && root.lyrics.source !== ""
                text: "· " + (root.lyrics && root.lyrics.source === "spotify" ? "Spotify" : "LRCLIB")
                       + (root.synced ? "" : " · sin tiempos")
                color: root.subColor
                font.family: root.fontFamily
                font.pixelSize: 11
            }
        }
    }

    // Estados
    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: !root.lyrics || root.lyrics.status !== "ready"
        text: !root.lyrics ? "" : root.lyrics.status === "loading" ? "Buscando la letra…"
            : root.lyrics.status === "none" ? "No encontré la letra de esta canción"
            : root.lyrics.status === "error" ? "No se pudo cargar la letra (¿sin conexión?)" : ""
        color: root.subColor
        font.family: root.fontFamily
        font.pixelSize: 13
    }

    // ── Letra ────────────────────────────────────────────────────────────────
    Item {
        id: fadeMask
        anchors.fill: body
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.2;  color: "black" }
                GradientStop { position: 0.78; color: "black" }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
    }

    Item {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !!root.lyrics && root.lyrics.status === "ready"
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0
            maskSpreadAtMin: 1
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.85
            shadowBlur: 0.5
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        ListView {
            id: list
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.lines
            spacing: 6
            // margen para que la primera y la última línea puedan centrarse
            header: Item { width: 1; height: list.height * 0.4 }
            footer: Item { width: 1; height: list.height * 0.4 }
            highlightFollowsCurrentItem: false

            delegate: Item {
                id: line
                required property var modelData
                required property int index
                readonly property int dist: root.current < 0 ? 0 : Math.abs(index - root.current)
                readonly property bool isCurrent: index === root.current
                width: list.width
                height: label.implicitHeight * (isCurrent ? 1.12 : 1) + 4

                Text {
                    id: label
                    width: parent.width / (line.isCurrent ? 1.12 : 1)
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    text: line.modelData.text
                    color: line.isCurrent ? root.accent : root.textColor
                    opacity: !root.synced ? 0.9 : line.isCurrent ? 1 : Math.max(0.25, 0.75 - line.dist * 0.12)
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.weight: line.isCurrent ? Font.Bold : Font.Medium
                    transformOrigin: Item.Right
                    scale: line.isCurrent ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.synced && line.modelData.t >= 0
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.seekTo(line.modelData.t)
                }
            }
        }
    }
}
