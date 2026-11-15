// Reloj 1 — analógico con números flotantes (sin esfera ni contorno), agujas
// en el centro y la hora digital debajo.
//
// Todas las opciones llegan en `opts` (clock.analog de config.json, ya
// combinado con los valores por defecto de shell.qml). Colores "auto" = esquema
// de Caelestia.
//
// Consumo: se redibuja solo al cambiar el minuto (o cada segundo si `seconds`
// está activo); el temporizador se alinea al cambio exacto de minuto/segundo.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    // Aguja: rectángulo que gira desde su base (el centro del reloj). Un
    // componente en línea no ve los ids del archivo: todo llega por propiedades.
    component Hand: Rectangle {
        property real length
        property real angle
        property real cx
        property real cy
        property bool smooth: true

        height: length
        radius: width / 2
        antialiasing: true
        x: cx - width / 2
        y: cy - length
        transformOrigin: Item.Bottom
        rotation: angle

        Behavior on rotation {
            enabled: smooth
            RotationAnimation {
                duration: 400
                direction: RotationAnimation.Clockwise
                easing.type: Easing.OutCubic
            }
        }
    }

    property var  opts: ({})
    property var  theme
    property real size: 240

    readonly property bool   showSeconds: opts.seconds === true
    readonly property bool   format24:    opts.format24 === true
    readonly property bool   showDigital: opts.showDigital !== false
    readonly property bool   roman:       opts.numerals === "roman"
    readonly property string fontFamily:  opts.font || ""
    readonly property var    colors:      opts.colors || ({})

    readonly property color numbersColor:    theme ? theme.pick(colors.numbers,    theme.textColor) : "white"
    readonly property color hourHandColor:   theme ? theme.pick(colors.hourHand,   theme.textColor) : "white"
    readonly property color minuteHandColor: theme ? theme.pick(colors.minuteHand, theme.textColor) : "white"
    readonly property color secondHandColor: theme ? theme.pick(colors.secondHand, theme.primary)   : "white"
    readonly property color centerColor:     theme ? theme.pick(colors.center,     theme.primary)   : "white"
    readonly property color digitalColor:    theme ? theme.pick(colors.digital,    theme.textColor) : "white"

    readonly property var romanNumerals: ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

    property date now: new Date()

    readonly property real hourAngle:   ((now.getHours() % 12) + now.getMinutes() / 60) * 30
    readonly property real minuteAngle: (now.getMinutes() + (showSeconds ? now.getSeconds() / 60 : 0)) * 6
    readonly property real secondAngle: now.getSeconds() * 6

    function two(n) { return n < 10 ? "0" + n : "" + n }

    readonly property string digitalText: {
        const h = now.getHours()
        const m = two(now.getMinutes())
        if (format24)
            return two(h) + ":" + m
        return (h % 12 || 12) + ":" + m + (h < 12 ? " AM" : " PM")
    }

    // Despierta justo en el próximo cambio de minuto (o de segundo).
    function tick() {
        now = new Date()
        const ms = now.getMilliseconds()
        timer.interval = showSeconds ? Math.max(50, 1000 - ms) : Math.max(50, (60 - now.getSeconds()) * 1000 - ms)
        timer.restart()
    }

    Timer {
        id: timer
        repeat: false
        onTriggered: root.tick()
    }

    Component.onCompleted: tick()
    onShowSecondsChanged: tick()

    implicitWidth: size
    implicitHeight: dial.height + (showDigital ? digital.anchors.topMargin + digital.implicitHeight : 0)

    Item {
        id: content
        anchors.fill: parent

        // Sombra suave para que se lea sobre cualquier fondo. Se calcula solo
        // cuando cambia el contenido (una vez por minuto).
        layer.enabled: root.opts.shadow !== false
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Item {
            id: dial
            width: root.size
            height: root.size

            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real radius: width * 0.42

            // Números flotando en círculo
            Repeater {
                model: 12

                Text {
                    required property int index
                    readonly property real angle: index * 30 * Math.PI / 180

                    text: root.roman ? root.romanNumerals[index] : (index === 0 ? "12" : "" + index)
                    color: root.numbersColor
                    font.family: root.fontFamily
                    font.pixelSize: root.size * (root.opts.numberSize || 0.11)
                    font.weight: Font.Medium
                    x: dial.cx + dial.radius * Math.sin(angle) - width / 2
                    y: dial.cy - dial.radius * Math.cos(angle) - height / 2
                }
            }

            Hand {
                cx: dial.cx
                cy: dial.cy
                smooth: root.opts.smoothHands !== false
                length: root.size * 0.22
                width: Math.max(3, root.size * 0.035)
                angle: root.hourAngle
                color: root.hourHandColor
            }

            Hand {
                cx: dial.cx
                cy: dial.cy
                smooth: root.opts.smoothHands !== false
                length: root.size * 0.32
                width: Math.max(2, root.size * 0.022)
                angle: root.minuteAngle
                color: root.minuteHandColor
            }

            Hand {
                cx: dial.cx
                cy: dial.cy
                smooth: root.opts.smoothHands !== false
                visible: root.showSeconds
                length: root.size * 0.36
                width: Math.max(1, root.size * 0.008)
                angle: root.secondAngle
                color: root.secondHandColor
            }

            Rectangle {
                width: root.size * 0.05
                height: width
                radius: width / 2
                color: root.centerColor
                x: dial.cx - width / 2
                y: dial.cy - height / 2
                antialiasing: true
            }
        }

        Text {
            id: digital
            visible: root.showDigital
            anchors.top: dial.bottom
            anchors.topMargin: root.size * 0.02
            anchors.horizontalCenter: dial.horizontalCenter
            text: root.digitalText
            color: root.digitalColor
            font.family: root.fontFamily
            font.pixelSize: root.size * (root.opts.digitalSize || 0.15)
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }
    }
}
