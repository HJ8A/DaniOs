// Fondo de panel: color de superficie + portada desenfocada encima.
// Es estático (se recalcula solo al cambiar de portada): no poner dentro nada
// que cambie cada cuadro, porque ClippingRectangle lo re-renderiza entero.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

ClippingRectangle {
    id: root

    property string source: ""          // vacío = fondo liso
    property color  surface: "#131317"
    property real   surfaceOpacity: 0.85
    property color  borderColor: "#14ffffff"

    color: Qt.alpha(surface, surfaceOpacity)
    border.color: borderColor
    border.width: 1

    Image {
        id: backdrop
        anchors.fill: parent
        visible: false
        source: root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(96, 96)
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: backdrop.status === Image.Ready
        source: backdrop
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.2
        autoPaddingEnabled: false
        opacity: 0.55
    }
    Rectangle {
        anchors.fill: parent
        visible: backdrop.status === Image.Ready
        color: Qt.alpha(root.surface, 0.45)
    }
}
