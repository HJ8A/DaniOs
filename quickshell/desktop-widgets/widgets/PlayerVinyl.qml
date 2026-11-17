// Reproductor estilo vinilo: la funda (portada) con el disco detrás. Al sonar,
// el disco sale de la funda, gira y el brazo se apoya encima; en pausa el
// brazo se levanta y el disco vuelve a la funda.
// ⏮ ⏯ ⏭ van dentro de la funda; debajo, una cápsula de vidrio compacta
// (desenfoque de Hyprland, regla de capa "desktop-widgets-player") con
// título · artista, progreso, volumen y reproductor. Sin tarjeta grande.
//
// Rendimiento:
// - surcos y reflejos = shader estático (los reflejos de un vinilo real no giran);
// - lo único que gira es la etiqueta (la portada), a pasos de `vinyl.fps`
//   (30 por defecto): una animación normal redibuja a la frecuencia de la
//   pantalla (165 Hz aquí) y costaba ~15 % de CPU;
// - en pausa no se mueve nada.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../common"

Item {
    id: root

    property var opts: ({})
    property var theme
    property var media
    property var values: []
    property color cavaA: "white"
    property color cavaB: "white"

    readonly property Item inputItem: body

    readonly property var    cav: opts.cava || ({})
    readonly property var    vin: opts.vinyl || ({})
    readonly property var    colors: opts.colors || ({})
    readonly property var    player: media ? media.active : null
    readonly property bool   playing: player ? player.isPlaying : false
    readonly property string fontFamily: opts.font || "Rubik"
    readonly property string art: media ? media.artUrl(player) : ""

    function pick(value, fallback) {
        return (!value || value === "auto") ? fallback : value
    }

    // ── Medidas ──────────────────────────────────────────────────────────────
    readonly property real w: opts.width > 0 ? opts.width : 380
    readonly property real unit: Math.round(w * 0.40)            // como la tarjeta
    readonly property real pad: Math.round(unit * 0.09)
    readonly property real cornerRadius: opts.radius >= 0 ? opts.radius : 22
    readonly property real sleeveSize: Math.round(w * 0.46)
    readonly property real discSize: Math.round(sleeveSize * 0.95)
    readonly property real slideIn: sleeveSize * 0.08
    readonly property real slideOut: sleeveSize * 0.5
    readonly property real armSpace: discSize * 0.24
    readonly property real stageW: (sleeveSize + discSize) / 2 + slideOut + armSpace
    readonly property real stageX: (w - stageW) / 2
    readonly property real pillPad: Math.round(unit * 0.065)
    readonly property real pillH: pillPad * 2 + Math.round(unit * 0.115) + Math.round(unit * 0.12) * 2 + 8
    readonly property real pillW: Math.min(w, stageW + unit * 0.2)

    readonly property bool ring: cav.enabled !== false && cav.mode === "circle"
    readonly property real ringGap: 6
    readonly property real ringReach: cav.circleReach > 0 ? cav.circleReach : 26
    readonly property real outer: ring ? ringGap + ringReach : 0

    implicitWidth: w + outer * 2
    implicitHeight: sleeveSize + 10 + pillH + outer * 2

    // ── Colores ──────────────────────────────────────────────────────────────
    readonly property color textColor: pick(colors.text, theme ? theme.textColor : "white")
    readonly property color subColor: pick(colors.subtext, theme ? theme.textVariant : "#cccccc")
    readonly property color accent: pick(colors.accent, sleeve.vivid ?? (theme ? theme.primary : "#c2c1ff"))
    readonly property color surface: theme ? theme.surface : "#131317"

    Item {
        id: body
        x: root.outer
        y: root.outer
        width: root.w
        height: root.sleeveSize + 10 + root.pillH

        // ── Disco (detrás de la funda) ───────────────────────────────────────
        Item {
            id: disc
            width: root.discSize
            height: root.discSize
            y: (root.sleeveSize - height) / 2
            x: root.stageX + (root.sleeveSize - width) / 2 + (root.playing ? root.slideOut : root.slideIn)
            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

            // cava en círculo alrededor del disco
            Visualizer {
                anchors.centerIn: parent
                width: parent.width + (root.ringGap + root.ringReach) * 2
                height: width
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
                shapeWidth: root.discSize
                shapeHeight: root.discSize
                shapeRadius: root.discSize / 2
                opacity: root.cav.opacity > 0 ? root.cav.opacity : 0.8
            }

            ShaderEffect {
                anchors.fill: parent
                property vector4d tint: Qt.vector4d(root.accent.r, root.accent.g, root.accent.b, 1)
                property real labelFrac: 0.36
                property real pixels: width / 2
                fragmentShader: Qt.resolvedUrl("../shaders/vinyl.frag.qsb")
            }

            // Etiqueta = portada, lo único que gira
            ClippingRectangle {
                id: label
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.36) * 2 - 2
                height: width
                radius: width / 2
                color: Qt.alpha(root.accent, 0.6)

                Image {
                    anchors.fill: parent
                    source: root.art
                    sourceSize: Qt.size(256, 256)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Timer {
                id: spinTimer
                interval: Math.round(1000 / Math.max(10, Math.min(60, root.vin.fps || 30)))
                repeat: true
                running: root.visible && root.playing && root.vin.spin !== false
                property double last: 0
                onRunningChanged: last = Date.now()
                onTriggered: {
                    const now = Date.now()
                    const degPerMs = 360 * (root.vin.rpm || 33.3) / 60000
                    label.rotation = (label.rotation + (now - last) * degPerMs) % 360
                    last = now
                }
            }

            // Eje central
            Rectangle {
                anchors.centerIn: parent
                width: Math.max(4, parent.width * 0.035)
                height: width
                radius: width / 2
                color: "#d8d8d8"
                border.color: "#55000000"
            }
        }

        // ── Funda (portada) ──────────────────────────────────────────────────
        AlbumArt {
            id: sleeve
            visible: root.vin.sleeve !== false
            x: root.stageX
            width: root.sleeveSize
            height: width
            radius: 6
            media: root.media
            source: root.art
            placeholderColor: root.subColor

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.55
                shadowBlur: 0.6
                shadowHorizontalOffset: 3
                shadowVerticalOffset: 4
            }
        }

        // ── Brazo ────────────────────────────────────────────────────────────
        Item {
            id: arm
            anchors.fill: parent           // necesario: la capa de sombra usa su tamaño
            visible: root.vin.tonearm !== false
            readonly property real pivotX: root.stageX + (root.sleeveSize + root.discSize) / 2 + root.slideOut + root.armSpace * 0.45
            readonly property real pivotY: (root.sleeveSize - root.discSize) / 2 + root.discSize * 0.1
            readonly property real len: root.discSize * 0.72
            readonly property real thick: Math.max(3, root.discSize * 0.022)

            // Base del pivote
            Rectangle {
                x: arm.pivotX - width / 2
                y: arm.pivotY - height / 2
                width: root.discSize * 0.14
                height: width
                radius: width / 2
                color: "#2a2a2e"
                border.color: "#6a6a70"
                border.width: 1
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    radius: width / 2
                    color: "#bdbdc2"
                }
            }

            // Brazo + cápsula (gira desde el pivote)
            Item {
                x: arm.pivotX - width / 2
                y: arm.pivotY
                width: arm.thick * 4
                height: arm.len
                transformOrigin: Item.Top
                rotation: root.playing ? (root.vin.armAngle || 27) : 4
                Behavior on rotation { NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: arm.thick
                    height: parent.height - arm.thick * 4
                    radius: width / 2
                    color: "#c9c9ce"
                }
                Rectangle {           // cápsula
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: arm.thick * 3.2
                    height: arm.thick * 5
                    radius: 2
                    color: "#3a3a40"
                    border.color: "#8a8a90"
                    border.width: 1
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.5
                shadowBlur: 0.4
                shadowHorizontalOffset: 2
                shadowVerticalOffset: 3
            }
        }

        // ── Controles dentro de la funda ────────────────────────────────────
        Rectangle {                    // degradado para que se lean sobre cualquier portada
            visible: sleeve.visible
            x: sleeve.x
            y: sleeve.y + sleeve.height * 0.5
            width: sleeve.width
            height: sleeve.height * 0.5
            radius: sleeve.radius
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
            }
        }
        PlayerControls {
            anchors.horizontalCenter: sleeve.horizontalCenter
            anchors.bottom: sleeve.bottom
            anchors.bottomMargin: Math.round(root.sleeveSize * 0.07)
            player: root.player
            size: Math.round(root.sleeveSize * 0.21)
            fg: "white"
            accent: root.accent
        }

        // ── Cápsula de vidrio: título · artista, progreso, volumen ───────────
        Rectangle {
            id: pill
            y: root.sleeveSize + 10
            x: (root.w - width) / 2
            width: root.pillW
            height: root.pillH
            radius: Math.min(root.cornerRadius, height / 2)
            color: Qt.alpha(root.surface, root.opts.opacity >= 0 ? Math.min(0.6, root.opts.opacity * 0.5) : 0.42)
            border.color: Qt.alpha(root.textColor, 0.10)
            border.width: 1

            WheelHandler {
                enabled: root.media?.volumeSupported ?? false
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => root.media.setVolume(root.media.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.pillPad
                anchors.leftMargin: root.pillPad * 1.6
                anchors.rightMargin: root.pillPad * 1.6
                spacing: 4

                Text {
                    width: parent.width
                    function esc(t) { return String(t ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;") }
                    readonly property string artist: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                    text: "<b>" + esc(root.player ? root.player.trackTitle : "") + "</b>"
                          + (artist ? "<font color='" + root.subColor + "'>  ·  " + esc(artist) + "</font>" : "")
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: Math.round(root.unit * 0.1)
                    color: root.textColor
                }

                PlayerProgress {
                    width: parent.width
                    height: Math.round(root.unit * 0.12)
                    visible: root.opts.showProgress !== false && available
                    player: root.player
                    fontSize: Math.round(root.unit * 0.064)
                    fontFamily: root.fontFamily
                    textColor: root.textColor
                    subColor: root.subColor
                    accent: root.accent
                }

                Item {
                    width: parent.width
                    height: Math.round(root.unit * 0.12)
                    PlayerVolume {
                        anchors.left: parent.left
                        anchors.right: chip.visible ? chip.left : parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        visible: root.opts.showVolume !== false && available
                        media: root.media
                        textColor: root.textColor
                        subColor: root.subColor
                    }
                    PlayerChip {
                        id: chip
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.round(root.unit * 0.11)
                        visible: root.opts.showPlayerName !== false
                        media: root.media
                        fontFamily: root.fontFamily
                        textColor: root.textColor
                        subColor: root.subColor
                    }
                }
            }
        }
    }
}
