// Reloj 2 — sol y luna según la hora real (amanecer/atardecer de tu ubicación y
// fase real de la luna, calculados sin internet en common/Astro.js).
//
// Dos diseños (opts.layout):
//   "transform" → un solo astro en el centro: sol de día, se tiñe de naranja y
//                 se convierte en luna al atardecer, luna (con su fase) de noche.
//   "arc"       → arco del día: el sol recorre un semicírculo según su posición
//                 real; de noche lo recorre la luna.
// Debajo: hora digital, amanecer/atardecer y fase de la luna (cada uno opcional).
//
// Consumo: se recalcula y redibuja una vez por minuto (alineado al cambio de minuto).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../common"
import "../common/Astro.js" as Astro

Item {
    id: root

    property var  opts: ({})
    property var  theme
    property var  location: ({ latitude: -12.05, longitude: -77.04 })
    property real size: 240

    readonly property bool   arcLayout:     opts.layout === "arc"
    readonly property bool   format24:      opts.format24 === true
    readonly property bool   showDigital:   opts.showDigital !== false
    readonly property bool   showSunTimes:  opts.showSunTimes !== false
    readonly property bool   showMoonPhase: opts.showMoonPhase !== false
    readonly property real   twilight:      opts.twilight > 0 ? opts.twilight : 6
    readonly property string fontFamily:    opts.font || ""
    readonly property var    colors:        opts.colors || ({})

    readonly property color sunColor:    pick(colors.sun, "#ffc94d")
    readonly property color sunsetColor: pick(colors.sunset, "#ff8a3d")
    readonly property color moonColor:   pick(colors.moon, "#ece9df")
    readonly property color moonDark:    pick(colors.moonDark, theme ? Qt.alpha(theme.textVariant, 0.18) : "#30ffffff")
    readonly property color arcColor:    pick(colors.arc, theme ? Qt.alpha(theme.textVariant, 0.45) : "#80ffffff")
    readonly property color digitalColor: pick(colors.digital, theme ? theme.textColor : "white")
    readonly property color infoColor:   pick(colors.info, theme ? theme.textVariant : "#cccccc")

    function pick(value, fallback) {
        return (!value || value === "auto") ? fallback : value
    }

    // ── Estado astronómico (se recalcula en tick) ────────────────────────────
    property date now: new Date()
    property real elevation: 45
    property var  times: null
    property var  moonInfo: ({ illumination: 0.5, waxing: true, phase: "" })

    // 0 = día pleno, 1 = noche (transición dentro de ±twilight grados)
    readonly property real night: Math.max(0, Math.min(1, (twilight - elevation) / (2 * twilight)))
    // calidez del sol: naranja cuando está a menos de 15° del horizonte
    readonly property real warmth: Math.max(0, Math.min(1, (15 - elevation) / 15))
    readonly property color sunTint: Qt.rgba(sunColor.r + (sunsetColor.r - sunColor.r) * warmth,
                                             sunColor.g + (sunsetColor.g - sunColor.g) * warmth,
                                             sunColor.b + (sunsetColor.b - sunColor.b) * warmth, 1)

    // Posición en el arco: fracción 0..1 del día (sol) o de la noche (luna)
    readonly property bool isDay: times ? (now >= times.sunrise && now < times.sunset) : elevation > 0
    readonly property real arcProgress: {
        if (!times)
            return 0.5
        const DAY = 86400000
        if (isDay)
            return (now - times.sunrise) / (times.sunset - times.sunrise)
        // noche: del atardecer (de hoy o de ayer) al amanecer siguiente
        const start = now >= times.sunset ? times.sunset.getTime() : times.sunset.getTime() - DAY
        const end   = now >= times.sunset ? times.sunrise.getTime() + DAY : times.sunrise.getTime()
        return (now.getTime() - start) / (end - start)
    }

    function two(n) { return n < 10 ? "0" + n : "" + n }
    function fmt(d) {
        if (!d)
            return "--:--"
        const h = d.getHours(), m = two(d.getMinutes())
        return format24 ? two(h) + ":" + m : (h % 12 || 12) + ":" + m + (h < 12 ? " AM" : " PM")
    }

    function tick() {
        const preview = opts.previewTime ? new Date(opts.previewTime) : null
        now = (preview && !isNaN(preview)) ? preview : new Date()
        const lat = location.latitude, lon = location.longitude
        elevation = Astro.sunElevation(now, lat, lon)
        times = Astro.sunTimes(now, lat, lon)
        moonInfo = Astro.moon(now)
        const real = new Date()
        timer.interval = Math.max(50, (60 - real.getSeconds()) * 1000 - real.getMilliseconds())
        timer.restart()
    }

    Timer {
        id: timer
        repeat: false
        onTriggered: root.tick()
    }

    Component.onCompleted: tick()
    onOptsChanged: tick()
    onLocationChanged: tick()

    implicitWidth: size
    implicitHeight: stage.height + info.anchors.topMargin + info.implicitHeight

    // ── Dibujo ───────────────────────────────────────────────────────────────
    Item {
        id: stage
        width: root.size
        height: root.arcLayout ? root.size * 0.62 : root.size * 0.7

        // Diseño "transform": un astro que se transforma
        Item {
            visible: !root.arcLayout
            anchors.fill: parent

            Sun {
                anchors.centerIn: parent
                diameter: root.size * 0.55
                tint: root.sunTint
                opacity: 1 - root.night
                scale: 1 - 0.35 * root.night
                visible: opacity > 0.01
            }

            Moon {
                anchors.centerIn: parent
                diameter: root.size * 0.42
                illumination: root.moonInfo.illumination
                waxing: root.moonInfo.waxing
                lit: root.moonColor
                dark: root.moonDark
                opacity: root.night
                scale: 0.75 + 0.25 * root.night
                visible: opacity > 0.01
            }
        }

        // Diseño "arc": arco del día
        Item {
            id: arcView
            visible: root.arcLayout
            anchors.fill: parent

            readonly property real radius: root.size * 0.42
            readonly property real cx: width / 2
            readonly property real cy: height - root.size * 0.06
            readonly property real angle: Math.PI * (1 - Math.max(0, Math.min(1, root.arcProgress)))
            readonly property real bodyX: cx + radius * Math.cos(angle)
            readonly property real bodyY: cy - radius * Math.sin(angle)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.arcColor
                    strokeWidth: Math.max(1, root.size * 0.008)
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 4]
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: arcView.cx
                        centerY: arcView.cy
                        radiusX: arcView.radius
                        radiusY: arcView.radius
                        startAngle: 180
                        sweepAngle: 180
                    }
                }

                ShapePath {
                    strokeColor: root.arcColor
                    strokeWidth: Math.max(1, root.size * 0.008)
                    fillColor: "transparent"
                    startX: arcView.cx - arcView.radius - root.size * 0.04
                    startY: arcView.cy
                    PathLine {
                        x: arcView.cx + arcView.radius + root.size * 0.04
                        y: arcView.cy
                    }
                }
            }

            Sun {
                visible: root.isDay
                diameter: root.size * 0.2
                tint: root.sunTint
                x: arcView.bodyX - width / 2
                y: arcView.bodyY - height / 2
            }

            Moon {
                visible: !root.isDay
                diameter: root.size * 0.15
                illumination: root.moonInfo.illumination
                waxing: root.moonInfo.waxing
                lit: root.moonColor
                dark: root.moonDark
                x: arcView.bodyX - width / 2
                y: arcView.bodyY - height / 2
            }
        }
    }

    // ── Textos ───────────────────────────────────────────────────────────────
    Column {
        id: info
        anchors.top: stage.bottom
        anchors.topMargin: root.size * 0.03
        anchors.horizontalCenter: stage.horizontalCenter
        spacing: root.size * 0.015

        layer.enabled: root.opts.shadow !== false
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Text {
            visible: root.showDigital
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.fmt(root.now)
            color: root.digitalColor
            font.family: root.fontFamily
            font.pixelSize: root.size * (root.opts.digitalSize || 0.15)
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Text {
            visible: root.showSunTimes
            anchors.horizontalCenter: parent.horizontalCenter
            text: "↑ " + root.fmt(root.times ? root.times.sunrise : null) + "    ↓ " + root.fmt(root.times ? root.times.sunset : null)
            color: root.infoColor
            font.family: root.fontFamily
            font.pixelSize: root.size * (root.opts.infoSize || 0.06)
        }

        Text {
            visible: root.showMoonPhase
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.moonInfo.phase + " · " + Math.round(root.moonInfo.illumination * 100) + "%"
            color: root.infoColor
            font.family: root.fontFamily
            font.pixelSize: root.size * (root.opts.infoSize || 0.06)
        }
    }
}
