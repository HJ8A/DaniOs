// Sol: disco con halo y 12 rayos. Lo usan los relojes 2 y 3.
import QtQuick
import QtQuick.Effects

Item {
    id: sunRoot

    property real diameter: 100
    property color tint: "#ffc94d"

    width: diameter
    height: diameter

    // Rayos: cada uno es un contenedor del tamaño del sol, girado sobre su
    // centro, con un rectángulo pegado arriba.
    Repeater {
        model: 12

        Item {
            required property int index
            width: sunRoot.diameter
            height: sunRoot.diameter
            rotation: index * 30

            Rectangle {
                width: sunRoot.diameter * 0.055
                height: sunRoot.diameter * 0.16
                radius: width / 2
                color: sunRoot.tint
                antialiasing: true
                x: (sunRoot.diameter - width) / 2
                y: 0
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: sunRoot.diameter * 0.56
        height: width
        radius: width / 2
        color: sunRoot.tint
        antialiasing: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: sunRoot.tint
            shadowBlur: 1.0
            shadowOpacity: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
