// Botón redondo con icono de Material Symbols. `primary` = relleno de color.
import QtQuick

Item {
    id: btn

    property string icon
    property bool   primary: false
    property bool   enabledBtn: true
    property real   size: 30
    property color  fg: "white"
    property color  bg: "white"
    signal clicked()

    width: size
    height: size
    opacity: enabledBtn ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.primary ? btn.bg : Qt.alpha(btn.fg, ma.containsMouse ? 0.16 : 0)
        scale: ma.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
    Text {
        anchors.centerIn: parent
        text: btn.icon
        font.family: "Material Symbols Rounded"
        font.pixelSize: btn.size * (btn.primary ? 0.62 : 0.72)
        color: btn.primary ? "#000000" : btn.fg
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabledBtn
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
