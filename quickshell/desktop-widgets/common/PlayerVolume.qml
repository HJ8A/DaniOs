// Volumen de la aplicación del reproductor (clic en el altavoz = silenciar).
import QtQuick

Item {
    id: root

    property var   media
    property color textColor: "white"
    property color subColor: "#cccccc"

    readonly property bool available: media?.volumeSupported ?? false
    implicitHeight: 22

    Text {
        id: volIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        readonly property real v: root.media ? root.media.volume : 1
        text: (root.media?.muted || v === 0) ? "volume_off" : v < 0.4 ? "volume_down" : "volume_up"
        font.family: "Material Symbols Rounded"
        font.pixelSize: parent.height * 0.95
        color: root.subColor
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.media.toggleMute()
        }
    }
    Item {
        id: volTrack
        anchors.left: volIcon.right
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        readonly property real shown: volMa.pressed ? volMa.dragValue : (root.media ? root.media.volume : 1)
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: Qt.alpha(root.textColor, 0.18)
        }
        Rectangle {
            width: parent.width * Math.min(1, volTrack.shown)
            height: parent.height
            radius: 2
            color: root.subColor
        }
        Rectangle {
            width: 10
            height: 10
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            x: Math.min(1, volTrack.shown) * (parent.width - width)
            color: root.textColor
            visible: volMa.containsMouse || volMa.pressed
        }
        MouseArea {
            id: volMa
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real dragValue: 0
            function at(mx) { return Math.max(0, Math.min(1, (mx - 8) / volTrack.width)) }
            onPressed: mouse => { dragValue = at(mouse.x); root.media.setVolume(dragValue) }
            onPositionChanged: mouse => { if (pressed) { dragValue = at(mouse.x); root.media.setVolume(dragValue) } }
        }
    }
}
