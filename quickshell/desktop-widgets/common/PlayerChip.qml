// Nombre del reproductor; clic = cambiar al siguiente si hay varios.
import QtQuick

Rectangle {
    id: root

    property var    media
    property string fontFamily: "Rubik"
    property color  textColor: "white"
    property color  subColor: "#cccccc"

    readonly property var  player: media ? media.active : null
    readonly property bool several: (media?.players.length ?? 0) > 1

    implicitHeight: 18
    width: row.implicitWidth + height * 0.8
    radius: height / 2
    color: Qt.alpha(textColor, ma.containsMouse && several ? 0.16 : 0.08)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3
        Text {
            text: root.player ? root.player.identity : ""
            font.pixelSize: root.height * 0.55
            font.family: root.fontFamily
            color: root.subColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.several
            text: "swap_horiz"
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.height * 0.7
            color: root.subColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.several ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.media.cycle()
    }
}
