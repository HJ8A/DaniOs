// Bordes de luz (fase 2): envoltura del shader edgeglow.frag.
//
// - `values`: barras de cava (estéreo), 0..1.
// - La fase de la ondulación avanza con el TIEMPO REAL entre cuadros de cava,
//   no con un temporizador: sin música no hay cuadros y nada se redibuja.
// - `energy`: pulso de graves (centro del arreglo estéreo), suavizado.
import QtQuick

ShaderEffect {
    id: root

    property var   values: []
    property color accent: "white"
    property color fallback: "#c2c1ff"     // color del esquema, si la portada no tiene color
    property real  cornerRadius: 15
    property real  intensity: 1
    property real  reachFraction: 0.11     // alcance del resplandor (parte del lado menor)

    // ── Animación ligada a los cuadros de cava ───────────────────────────────
    property double lastFrame: 0
    property real phase: 0
    property real energy: 0

    onValuesChanged: {
        const now = Date.now()
        const dt = lastFrame > 0 ? Math.min(0.1, (now - lastFrame) / 1000) : 0
        lastFrame = now
        const v = values
        const n = v.length
        let bass = 0
        if (n > 0) {
            const mid = Math.floor(n / 2)
            const k = Math.max(1, Math.floor(n / 16))
            for (let i = mid - k; i < mid + k; ++i)
                bass += v[(i + n) % n] || 0
            bass /= 2 * k
        }
        energy = energy * 0.6 + bass * 0.4
        phase = (phase + dt * (1.2 + energy * 3.0)) % 1000
    }

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

    // Versión neón del color de la canción: saturada y luminosa aunque la
    // portada sea apagada (beige, gris…); la variante gira un poco el tono.
    // Portadas en blanco y negro (saturación casi 0, tono indefinido): el
    // neón salía blanco; se usa el color del esquema de Caelestia.
    readonly property color base: accent.hsvSaturation < 0.15 ? fallback : accent
    readonly property color neon: Qt.hsva(base.hsvHue, Math.max(0.6, base.hsvSaturation), 1, 1)
    readonly property color variant: Qt.hsva((base.hsvHue + 0.09) % 1, Math.max(0.5, base.hsvSaturation * 0.9), 1, 1)
    property vector4d colorA: Qt.vector4d(neon.r, neon.g, neon.b, 1)
    property vector4d colorB: Qt.vector4d(variant.r, variant.g, variant.b, 1)
    property size area: Qt.size(width, height)
    property real count: Math.max(1, Math.min(64, values.length))
    property real radius: cornerRadius
    property real inset: 2
    property real reach: Math.min(width, height) * reachFraction
    property real core: 1.6

    fragmentShader: Qt.resolvedUrl("../shaders/edgeglow.frag.qsb")
    blending: true
}
