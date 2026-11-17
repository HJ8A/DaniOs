// Reproductor estilo tarjeta: portada a la izquierda; título, artista,
// reproductor, progreso, ⏮ ⏯ ⏭ y volumen a la derecha (PlayerInfo).
// Rueda del mouse sobre la tarjeta = volumen de la app.
//
// Dentro de la tarjeta no hay barras: cava va en los bordes de la pantalla
// o, en modo "circle", alrededor del contorno de la tarjeta.
// Rendimiento: el fondo desenfocado se calcula una vez por canción; lo único
// que cambia cada cuadro son las barras de cava (GPU).
import QtQuick
import "../common"

Item {
    id: root

    property var opts: ({})
    property var theme
    property var media                  // services/Media.qml
    property var values: []             // cava (solo para el modo contorno)
    property color cavaA: "white"
    property color cavaB: "white"

    // Lo único que recibe el mouse (el resto deja pasar los clics)
    readonly property Item inputItem: card

    readonly property var    cav: opts.cava || ({})
    readonly property var    colors: opts.colors || ({})
    readonly property var    player: media ? media.active : null
    readonly property string fontFamily: opts.font || "Rubik"     // la de Caelestia

    function pick(value, fallback) {
        return (!value || value === "auto") ? fallback : value
    }

    // ── Medidas ──────────────────────────────────────────────────────────────
    readonly property real cardW: opts.width > 0 ? opts.width : 380
    readonly property real cardH: Math.round(cardW * 0.40)
    readonly property real pad: Math.round(cardH * 0.09)
    readonly property real cornerRadius: opts.radius >= 0 ? opts.radius : 22
    readonly property bool ring: cav.enabled !== false && cav.mode === "circle"
    readonly property real ringGap: 6
    readonly property real ringReach: cav.circleReach > 0 ? cav.circleReach : 26
    readonly property real outer: ring ? ringGap + ringReach : 0

    implicitWidth: cardW + outer * 2
    implicitHeight: cardH + outer * 2

    // ── Colores ──────────────────────────────────────────────────────────────
    readonly property color textColor: pick(colors.text, theme ? theme.textColor : "white")
    readonly property color subColor: pick(colors.subtext, theme ? theme.textVariant : "#cccccc")
    readonly property color accent: pick(colors.accent, cover.vivid ?? (theme ? theme.primary : "#c2c1ff"))
    readonly property color surface: theme ? theme.surface : "#131317"

    // ── cava alrededor (detrás de la tarjeta) ────────────────────────────────
    Visualizer {
        anchors.fill: parent
        visible: root.ring
        values: root.ring ? root.values : []
        mode: "circle"
        shape: root.cav.shape || "bars"
        reach: root.ringReach
        gap: root.ringGap
        thickness: root.cav.thickness > 0 ? root.cav.thickness : 0.85
        rounded: root.cav.rounded !== false
        colorA: root.cavaA
        colorB: root.cavaB
        symmetricGradient: root.cav.stereo !== false
        shapeWidth: root.cardW
        shapeHeight: root.cardH
        shapeRadius: root.cornerRadius
        opacity: root.cav.opacity > 0 ? root.cav.opacity : 0.8
    }

    // ── Tarjeta ──────────────────────────────────────────────────────────────
    Item {
        id: card
        x: root.outer
        y: root.outer
        width: root.cardW
        height: root.cardH

        ArtBackdrop {
            anchors.fill: parent
            radius: root.cornerRadius
            source: root.opts.background === "solid" ? "" : cover.source
            surface: root.surface
            surfaceOpacity: root.opts.opacity >= 0 ? root.opts.opacity : 0.85
            borderColor: Qt.alpha(root.textColor, 0.08)
        }

        // Rueda = volumen
        WheelHandler {
            enabled: root.media?.volumeSupported ?? false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.media.setVolume(root.media.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
        }

        AlbumArt {
            id: cover
            x: root.pad
            y: root.pad
            width: root.cardH - root.pad * 2
            height: width
            radius: Math.max(8, root.cornerRadius - root.pad / 2)
            media: root.media
            source: root.media ? root.media.artUrl(root.player) : ""
            placeholderColor: root.subColor
        }

        PlayerInfo {
            anchors.left: cover.right
            anchors.leftMargin: root.pad
            anchors.right: parent.right
            anchors.rightMargin: root.pad
            anchors.top: cover.top
            anchors.bottom: cover.bottom
            media: root.media
            opts: root.opts
            unit: root.cardH
            textColor: root.textColor
            subColor: root.subColor
            accent: root.accent
            fontFamily: root.fontFamily
        }
    }
}
