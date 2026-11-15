// Luna con su fase real (iluminación 0..1, creciente/menguante). Se pinta en
// un Canvas solo cuando cambia la fase o el color (1 vez por minuto como mucho).
import QtQuick

Canvas {
    id: moonRoot

    property real diameter: 100
    property real illumination: 0.5
    property bool waxing: true
    property color lit: "#ece9df"
    property color dark: "#30ffffff"

    width: diameter
    height: diameter
    antialiasing: true

    onIlluminationChanged: requestPaint()
    onWaxingChanged: requestPaint()
    onLitChanged: requestPaint()
    onDarkChanged: requestPaint()
    onDiameterChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        const r = diameter / 2 - 1
        ctx.reset()
        ctx.translate(diameter / 2, diameter / 2)
        // disco en sombra
        ctx.beginPath()
        ctx.arc(0, 0, r, 0, 2 * Math.PI)
        ctx.fillStyle = dark
        ctx.fill()
        // parte iluminada: borde exterior + terminador elíptico
        const dir = waxing ? 1 : -1               // iluminada a la derecha si crece
        const tx  = r * (1 - 2 * illumination)    // ancho firmado del terminador
        ctx.beginPath()
        ctx.arc(0, 0, r, -Math.PI / 2, Math.PI / 2, dir < 0)
        for (let i = 0; i <= 48; ++i) {
            const t = Math.PI / 2 - Math.PI * i / 48
            ctx.lineTo(dir * tx * Math.cos(t), r * Math.sin(t))
        }
        ctx.closePath()
        ctx.fillStyle = lit
        ctx.fill()
    }
}
