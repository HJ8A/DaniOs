// Reloj 3 — la Tierra vista sobre tu ciudad, con la línea día/noche real, luces
// de ciudades de noche, una marca en la ciudad, el sol y la luna orbitando en
// su dirección real y la hora digital debajo.
//
// El globo es un shader (shaders/earth.frag.qsb) que dibuja la GPU. Es
// estático: solo se recalcula una vez por minuto (avanza la línea día/noche).
// Al pasar el mouse gira suavemente; al salir vuelve a centrarse en la ciudad.
// Solo mientras gira hay trabajo continuo de GPU.
import QtQuick
import QtQuick.Effects
import "../common"
import "../common/Astro.js" as Astro

Item {
    id: root

    property var  opts: ({})
    property var  theme
    property var  location: ({ latitude: -12.05, longitude: -77.04 })
    property real size: 240

    // Zona que recibe el mouse (para girar al pasar por encima)
    readonly property Item hoverItem: globeArea

    readonly property bool   format24:     opts.format24 === true
    readonly property bool   showDigital:  opts.showDigital !== false
    readonly property bool   showMarker:   opts.showMarker !== false
    readonly property bool   showSunMoon:  opts.showSunMoon !== false
    readonly property bool   spinOnHover:  opts.spinOnHover !== false
    readonly property real   spinSeconds:  opts.spinSeconds > 0 ? opts.spinSeconds : 20
    readonly property string fontFamily:   opts.font || ""
    readonly property var    colors:       opts.colors || ({})

    function pick(value, fallback) {
        return (!value || value === "auto") ? fallback : value
    }

    readonly property color atmosphereColor: pick(colors.atmosphere, theme ? theme.primary : "#7fb2ff")
    readonly property color markerColor:     pick(colors.marker, theme ? theme.primary : "#ffffff")
    readonly property color sunColor:        pick(colors.sun, "#ffc94d")
    readonly property color moonColor:       pick(colors.moon, "#ece9df")
    readonly property color moonDark:        pick(colors.moonDark, theme ? Qt.alpha(theme.textVariant, 0.25) : "#40ffffff")
    readonly property color digitalColor:    pick(colors.digital, theme ? theme.textColor : "white")

    // ── Estado (se recalcula una vez por minuto) ─────────────────────────────
    property date now: new Date()
    property var  sunPoint:  ({ lat: 0, lon: 0 })
    property var  moonPoint: ({ lat: 0, lon: 0 })
    property var  moonInfo:  ({ illumination: 0.5, waxing: true })

    // Giro extra (grados de longitud) al pasar el mouse
    property real spin: 0

    readonly property real viewLat: location.latitude
    readonly property real viewLon: location.longitude + spin

    function two(n) { return n < 10 ? "0" + n : "" + n }
    function fmt(d) {
        const h = d.getHours(), m = two(d.getMinutes())
        return format24 ? two(h) + ":" + m : (h % 12 || 12) + ":" + m + (h < 12 ? " AM" : " PM")
    }

    function tick() {
        const preview = opts.previewTime ? new Date(opts.previewTime) : null
        now = (preview && !isNaN(preview)) ? preview : new Date()
        sunPoint = Astro.subsolarPoint(now)
        moonPoint = Astro.sublunarPoint(now)
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

    // Posición en pantalla de un punto (lat, lon) sobre el globo
    function screenOf(lat, lon) {
        const p = Astro.project(lat, lon, viewLat, viewLon)
        return { x: globe.width / 2 + p.x * globe.radius, y: globe.height / 2 - p.y * globe.radius, front: p.z > 0 }
    }
    // Dirección de un astro sobre el anillo alrededor del globo
    function ringOf(lat, lon, ringRadius) {
        const p = Astro.project(lat, lon, viewLat, viewLon)
        const a = Math.atan2(p.y, p.x)
        return { x: globe.width / 2 + ringRadius * Math.cos(a), y: globe.height / 2 - ringRadius * Math.sin(a), front: p.z > 0 }
    }

    implicitWidth: size
    implicitHeight: globe.height + (showDigital ? digital.anchors.topMargin + digital.implicitHeight : 0)

    Item {
        id: globe
        width: root.size
        height: root.size

        readonly property real radius: width * 0.33      // radio del globo
        readonly property real ring: width * 0.45        // órbita del sol y la luna

        // Texturas (NASA, dominio público — ver assets/CREDITS.md)
        Image {
            id: dayTexture
            visible: false
            source: "../assets/earth-day.jpg"
            asynchronous: true
            mipmap: true
        }
        Image {
            id: nightTexture
            visible: false
            source: "../assets/earth-night.jpg"
            asynchronous: true
            mipmap: true
        }

        ShaderEffect {
            anchors.fill: parent
            visible: dayTexture.status === Image.Ready && nightTexture.status === Image.Ready

            property real centerLat: root.viewLat * Math.PI / 180
            property real centerLon: root.viewLon * Math.PI / 180
            property vector4d sunDir: {
                const v = Astro.toVector(root.sunPoint.lat, root.sunPoint.lon)
                return Qt.vector4d(v.x, v.y, v.z, 0)
            }
            property vector4d atmosphere: Qt.vector4d(root.atmosphereColor.r, root.atmosphereColor.g, root.atmosphereColor.b,
                                                      root.opts.atmosphere >= 0 ? root.opts.atmosphere : 0.8)
            property real globeScale: globe.radius / (globe.width / 2)
            property real nightLights: root.opts.nightLights > 0 ? root.opts.nightLights : 1.4
            property variant dayTex: dayTexture
            property variant nightTex: nightTexture

            fragmentShader: "../shaders/earth.frag.qsb"
        }

        // Marca en la ciudad
        Rectangle {
            readonly property var pos: root.screenOf(root.location.latitude, root.location.longitude)
            visible: root.showMarker && pos.front
            width: Math.max(5, root.size * 0.03)
            height: width
            radius: width / 2
            color: root.markerColor
            border.color: "#000000"
            border.width: 1
            x: pos.x - width / 2
            y: pos.y - height / 2
            antialiasing: true
        }

        // Sol y luna orbitando en su dirección real (más tenues si están detrás del globo)
        Sun {
            readonly property var pos: root.ringOf(root.sunPoint.lat, root.sunPoint.lon, globe.ring)
            visible: root.showSunMoon
            diameter: root.size * 0.11
            tint: root.sunColor
            opacity: pos.front ? 1 : 0.45
            x: pos.x - width / 2
            y: pos.y - height / 2
        }

        Moon {
            readonly property var pos: root.ringOf(root.moonPoint.lat, root.moonPoint.lon, globe.ring)
            visible: root.showSunMoon
            diameter: root.size * 0.08
            illumination: root.moonInfo.illumination
            waxing: root.moonInfo.waxing
            lit: root.moonColor
            dark: root.moonDark
            opacity: pos.front ? 1 : 0.45
            x: pos.x - width / 2
            y: pos.y - height / 2
        }

        // Giro al pasar el mouse
        Item {
            id: globeArea
            anchors.centerIn: parent
            width: globe.radius * 2
            height: globe.radius * 2

            HoverHandler {
                id: hover
                enabled: root.spinOnHover
            }
        }

        NumberAnimation {
            id: spinning
            target: root
            property: "spin"
            running: hover.hovered
            from: root.spin
            to: root.spin + 360
            duration: root.spinSeconds * 1000
            loops: Animation.Infinite
        }

        NumberAnimation {
            id: settle
            target: root
            property: "spin"
            to: 0
            duration: 900
            easing.type: Easing.OutCubic
        }

        Connections {
            target: hover
            function onHoveredChanged() {
                if (!hover.hovered) {
                    // volver por el camino corto
                    root.spin = ((root.spin % 360) + 540) % 360 - 180
                    settle.start()
                } else {
                    settle.stop()
                }
            }
        }
    }

    Text {
        id: digital
        visible: root.showDigital
        anchors.top: globe.bottom
        anchors.topMargin: -root.size * 0.03
        anchors.horizontalCenter: globe.horizontalCenter
        text: root.fmt(root.now)
        color: root.digitalColor
        font.family: root.fontFamily
        font.pixelSize: root.size * (root.opts.digitalSize || 0.15)
        font.weight: Font.DemiBold
        font.letterSpacing: 1

        layer.enabled: root.opts.shadow !== false
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }
    }
}
