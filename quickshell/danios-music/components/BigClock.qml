// Hora gigante, alta y estrecha, con la fecha pequeña encima. Se actualiza
// una vez por minuto (alineado al cambio de minuto). Brillo del color de la
// canción alrededor de los números.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color  color: "white"
    property string fontFamily: "Open Sans Condensed"
    property int    fontWeight: Font.Light
    property real   size: 220              // alto de los números
    property bool   format24: false

    property date now: new Date()

    function two(n) { return n < 10 ? "0" + n : "" + n }
    readonly property string timeText: {
        const h = now.getHours(), m = two(now.getMinutes())
        return format24 ? two(h) + ":" + m : (h % 12 || 12) + ":" + m
    }
    readonly property string dateText: {
        const s = Qt.locale("es_ES").toString(now, "ddd d 'de' MMM")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function tick() {
        now = new Date()
        const t = new Date()
        timer.interval = Math.max(50, (60 - t.getSeconds()) * 1000 - t.getMilliseconds())
        timer.restart()
    }
    Timer { id: timer; onTriggered: root.tick() }
    Component.onCompleted: tick()

    implicitWidth: Math.max(digits.width * digits.sx, date.implicitWidth)
    implicitHeight: date.implicitHeight + digits.height * digits.sy * 0.86

    Text {
        id: date
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.dateText
        color: root.color
        font.family: "Rubik"
        font.pixelSize: Math.round(root.size * 0.085)
        font.weight: Font.Medium
        opacity: 0.9
    }

    Text {
        id: digits
        readonly property real sx: 1
        readonly property real sy: 1.35      // más alta que ancha, como la referencia
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: date.bottom
        anchors.topMargin: -root.size * 0.12
        text: root.timeText
        color: root.color
        font.family: root.fontFamily
        font.weight: root.fontWeight
        font.pixelSize: root.size
        transform: Scale { origin.x: digits.width / 2; origin.y: 0; yScale: digits.sy }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.color
            shadowOpacity: 0.55
            shadowBlur: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
