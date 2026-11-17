// Barra de progreso con tiempos (clic = buscar). Pide la posición al
// reproductor 1 vez por segundo, solo mientras suena y se ve.
import QtQuick

Item {
    id: root

    property var    player
    property real   fontSize: 10
    property string fontFamily: "Rubik"
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property color  accent: "#c2c1ff"

    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property real position: player && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    readonly property bool available: length > 0

    function mmss(sec) {
        if (!(sec >= 0) || sec > 359999)
            return "--:--"
        const s = Math.floor(sec)
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    implicitHeight: Math.round(fontSize * 1.9)

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    Text {
        id: posText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.mmss(root.position)
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.features: { "tnum": 1 }
        color: root.subColor
    }
    Text {
        id: lenText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.mmss(root.length)
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.features: { "tnum": 1 }
        color: root.subColor
    }
    Item {
        id: track
        anchors.left: posText.right
        anchors.right: lenText.left
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Qt.alpha(root.textColor, 0.18)
        }
        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: 2
            color: root.accent
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            enabled: root.player?.canSeek ?? false
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                const f = Math.max(0, Math.min(1, (mouse.x - 6) / track.width))
                root.player.position = f * root.length
            }
        }
    }
}
