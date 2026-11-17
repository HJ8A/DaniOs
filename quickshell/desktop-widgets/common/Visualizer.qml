// Visualizador de audio: todo lo dibuja la GPU (shaders/spectrum.frag).
// La CPU solo empaqueta los valores (hasta 64) en 16 vec4 por cuadro.
//
//   mode  "bottom"  barras desde el borde inferior
//         "top"     desde el borde superior
//         "mirror"  desde arriba y desde abajo
//         "circle"  hacia fuera, alrededor de un rectángulo redondeado de
//                   `shapeWidth`×`shapeHeight` centrado en este item
//   shape "bars" | "wave" | "dots"
//
// Medido (48 barras, 30 fps) con Rectangle/Shape: 5–19 % de CPU según la
// forma. Con el shader el costo no depende de la forma elegida.
import QtQuick

ShaderEffect {
    id: root

    property var    values: []
    property string mode: "bottom"
    property string shape: "bars"
    property real   reach: 40              // largo máximo (px)
    property real   thickness: 0.6         // fracción del espacio de cada barra
    property bool   rounded: true
    property color  colorA: "white"
    property color  colorB: colorA
    property bool   symmetricGradient: true

    // Contorno (modo circle)
    property real shapeWidth: width
    property real shapeHeight: height
    property real shapeRadius: 20
    property real gap: 6

    function pack(k) {
        const v = values
        return Qt.vector4d(v[4 * k] || 0, v[4 * k + 1] || 0, v[4 * k + 2] || 0, v[4 * k + 3] || 0)
    }

    // ── Uniforms (mismos nombres que en el shader) ───────────────────────────
    property vector4d v0: pack(0)
    property vector4d v1: pack(1)
    property vector4d v2: pack(2)
    property vector4d v3: pack(3)
    property vector4d v4: pack(4)
    property vector4d v5: pack(5)
    property vector4d v6: pack(6)
    property vector4d v7: pack(7)
    property vector4d v8: pack(8)
    property vector4d v9: pack(9)
    property vector4d v10: pack(10)
    property vector4d v11: pack(11)
    property vector4d v12: pack(12)
    property vector4d v13: pack(13)
    property vector4d v14: pack(14)
    property vector4d v15: pack(15)

    property vector4d shapeRect: Qt.vector4d(shapeWidth / 2, shapeHeight / 2, shapeRadius, 0)
    property size area: Qt.size(width, height)
    property real count: Math.max(1, Math.min(64, values.length))
    property real modeId: mode === "circle" ? 2 : mode === "mirror" ? 1 : mode === "top" ? 3 : 0
    property real kind: shape === "wave" ? 1 : shape === "dots" ? 2 : 0
    property real roundedF: rounded ? 1 : 0
    property real symmetric: symmetricGradient ? 1 : 0
    property real maxBarWidth: mode === "circle" ? 6 : 10000

    fragmentShader: Qt.resolvedUrl("../shaders/spectrum.frag.qsb")
    blending: true
    visible: values.length > 0
}
