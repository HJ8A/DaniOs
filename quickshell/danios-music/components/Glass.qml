// Panel de vidrio: desenfoca SOLO el trozo del fondo que tiene detrás
// (ShaderEffectSource con sourceRect) y lo recorta con esquinas redondeadas.
// El desenfoque de Hyprland no sirve aquí: el video está dentro de la misma
// ventana. El costo depende del tamaño del panel, no de la pantalla.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property Item  backdrop                  // el fondo a desenfocar
    property real  radius: 24
    property color tint: Qt.rgba(1, 1, 1, 0.08)
    property color borderColor: Qt.rgba(1, 1, 1, 0.16)
    property real  blurMax: 48
    property real  blur: 1                   // 0..1 (menos = más transparente)

    // Posición del panel dentro del fondo (se recalcula si se mueve/cambia)
    readonly property rect region: {
        x; y; width; height; parent;
        if (!backdrop)
            return Qt.rect(0, 0, 0, 0)
        const p = root.mapToItem(backdrop, 0, 0)
        return Qt.rect(p.x, p.y, width, height)
    }

    ShaderEffectSource {
        id: src
        anchors.fill: parent
        visible: false
        sourceItem: root.backdrop
        sourceRect: root.region
        live: true
        hideSource: false
    }

    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: src
        autoPaddingEnabled: false
        blurEnabled: true
        blur: root.blur
        blurMax: root.blurMax
        saturation: 0.15
        maskEnabled: true
        maskSource: mask
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        border.color: root.borderColor
        border.width: 1
    }
}
