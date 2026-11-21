// Pestaña "Widgets" del picker (Super + I): configura los widgets de escritorio
// (~/.config/quickshell/desktop-widgets).
//
// - Lee defaults.json (valores por defecto, una sola fuente) y config.json
//   (solo lo que el usuario cambió). Escribe en config.json solo las
//   diferencias, de forma atómica; la app de widgets vigila el archivo y
//   aplica cada cambio al instante en el escritorio.
// - Las vistas previas usan los mismos componentes que el escritorio.
// - El picker la carga solo mientras la pestaña está abierta.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "dw/common" as DW
import "dw/widgets" as DWW

Item {
    id: tab

    // Colores del picker (vienen de shell.qml)
    property color cBg: "#131317"
    property color cSurface: "#201f23"
    property color cSurfaceHigh: "#2a292e"
    property color cPrimary: "#c2c1ff"
    property color cText: "#e5e1e7"
    property color cTextV: "#c8c5d1"
    property color cOutline: "#47464f"

    // Paleta para los controles (los componentes en línea no ven los ids)
    readonly property QtObject pal: QtObject {
        property color bg: tab.cBg
        property color surface: tab.cSurface
        property color surfaceHigh: tab.cSurfaceHigh
        property color primary: tab.cPrimary
        property color text: tab.cText
        property color textV: tab.cTextV
        property color outline: tab.cOutline
    }

    // ── Datos ────────────────────────────────────────────────────────────────
    // Carpeta de desktop-widgets (se puede cambiar para pruebas)
    property string dir: Quickshell.env("HOME") + "/.config/quickshell/desktop-widgets/"
    property var defaults: ({ clock: { analog: {}, sunmoon: {}, earth: {} }, player: { cava: { colors: {} }, colors: {}, vinyl: {} }, location: {} })
    property var user: ({})
    readonly property var cfg: merge(defaults, user)
    // true cuando defaults.json ya se leyó (antes no se crean las vistas previas)
    readonly property bool ready: defaults.location.latitude !== undefined
    readonly property string style: cfg.clock.style || "analog"
    readonly property var styleOpts: cfg.clock[style] || ({})
    readonly property var pl: cfg.player || ({})
    readonly property var cv: pl.cava || ({})

    // Sección visible: "clock" | "player"
    property string section: "clock"

    function isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }

    function merge(base, over) {
        if (!isObj(over))
            return over === undefined ? base : over
        const out = {}
        for (const k in base) out[k] = base[k]
        for (const k in over) out[k] = isObj(base[k]) ? merge(base[k], over[k]) : over[k]
        return out
    }

    function get(path) {
        let node = cfg
        for (const part of path.split(".")) {
            if (!isObj(node)) return undefined
            node = node[part]
        }
        return node
    }

    function defaultOf(path) {
        let node = defaults
        for (const part of path.split(".")) {
            if (!isObj(node)) return undefined
            node = node[part]
        }
        return node
    }

    // Quita del objeto las claves iguales al valor por defecto y las ramas vacías
    function prune(over, base) {
        const out = {}
        for (const k in over) {
            if (isObj(over[k]) && isObj(base[k])) {
                const sub = prune(over[k], base[k])
                if (Object.keys(sub).length) out[k] = sub
            } else if (JSON.stringify(over[k]) !== JSON.stringify(base[k])) {
                out[k] = over[k]
            }
        }
        return out
    }

    function set(path, value) {
        const next = JSON.parse(JSON.stringify(user))
        const parts = path.split(".")
        let node = next
        for (let i = 0; i < parts.length - 1; ++i) {
            if (!isObj(node[parts[i]])) node[parts[i]] = {}
            node = node[parts[i]]
        }
        node[parts[parts.length - 1]] = value
        save(next)
    }

    function save(next) {
        const clean = prune(next, defaults)
        user = clean
        userFile.setText(JSON.stringify(clean, null, 4) + "\n")
    }

    // "Restablecer": vuelve todo el reloj a los valores por defecto (la ubicación se mantiene)
    function resetClock() {
        const next = JSON.parse(JSON.stringify(user))
        delete next.clock
        save(next)
    }

    FileView {
        path: tab.dir + "defaults.json"
        blockLoading: true
        onLoaded: {
            try { tab.defaults = JSON.parse(text()) } catch (e) { console.warn("WidgetsTab: defaults.json inválido:", e) }
        }
    }

    FileView {
        id: userFile
        path: tab.dir + "config.json"
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { tab.user = JSON.parse(text()) } catch (e) { console.warn("WidgetsTab: config.json inválido:", e) }
        }
        onLoadFailed: tab.user = ({})
    }

    DW.Theme { id: previewTheme }

    // DaniOS Music (~/.config/quickshell/danios-music): mismo patrón de config
    JsonSettings {
        id: music
        defaultsPath: Quickshell.env("HOME") + "/.config/quickshell/danios-music/defaults.json"
        configPath: Quickshell.env("HOME") + "/.config/quickshell/danios-music/config.json"
    }
    readonly property var mu: music.cfg

    function resetPlayer() {
        const next = JSON.parse(JSON.stringify(user))
        delete next.player
        save(next)
    }

    // ── Controles (en línea: todo llega por propiedades) ─────────────────────
    component Chip: Rectangle {
        id: chip
        property QtObject pal
        property string label
        property bool active: false
        signal activated()

        implicitHeight: 32
        implicitWidth: chipText.implicitWidth + 28
        radius: height / 2
        color: active ? Qt.alpha(pal.primary, 0.20) : chipMa.containsMouse ? Qt.alpha(pal.primary, 0.08) : "transparent"
        border.color: active ? pal.primary : Qt.alpha(pal.outline, 0.55)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: 12
            font.weight: chip.active ? Font.Medium : Font.Normal
            color: chip.active ? chip.pal.primary : chip.pal.textV
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    component Toggle: Item {
        id: toggle
        property QtObject pal
        property string label
        property bool checked: false
        signal toggled(bool value)

        implicitHeight: 30
        implicitWidth: toggleRow.implicitWidth

        Row {
            id: toggleRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 38
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: toggle.checked ? Qt.alpha(toggle.pal.primary, 0.85) : Qt.alpha(toggle.pal.outline, 0.6)
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 2
                    x: toggle.checked ? parent.width - width - 2 : 2
                    color: toggle.checked ? toggle.pal.bg : toggle.pal.text
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: toggle.label
                font.pixelSize: 12
                color: toggle.pal.text
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled(!toggle.checked)
        }
    }

    // Deslizador: se ve en vivo mientras se arrastra, se guarda al soltar
    component Slider: Item {
        id: slider
        property QtObject pal
        property string label
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.1
        property int decimals: 1
        property string suffix: ""
        property real shown: value
        signal committed(real value)

        onValueChanged: if (!sliderMa.pressed) shown = value

        implicitHeight: 44
        implicitWidth: 260

        Text {
            id: sliderLabel
            text: slider.label
            font.pixelSize: 12
            color: slider.pal.text
        }
        Text {
            anchors.right: parent.right
            text: slider.shown.toFixed(slider.decimals) + slider.suffix
            font.pixelSize: 12
            font.weight: Font.Medium
            color: slider.pal.primary
        }
        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sliderLabel.bottom
            anchors.topMargin: 8
            height: 16
            readonly property real frac: (slider.shown - slider.from) / (slider.to - slider.from)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.alpha(slider.pal.outline, 0.6)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * track.frac
                height: 4
                radius: 2
                color: slider.pal.primary
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: track.frac * (parent.width - width)
                color: slider.pal.primary
            }
            MouseArea {
                id: sliderMa
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                function valueAt(mx) {
                    const f = Math.max(0, Math.min(1, (mx - 6) / (track.width)))
                    const raw = slider.from + f * (slider.to - slider.from)
                    return Math.round(raw / slider.step) * slider.step
                }
                onPressed: mouse => slider.shown = valueAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) slider.shown = valueAt(mouse.x) }
                onReleased: slider.committed(slider.shown)
            }
        }
    }

    // Selector de color: "Auto" (esquema) + muestras de la paleta actual
    component ColorPicker: Row {
        id: picker
        property QtObject pal
        property var scheme
        property string label
        property string value: "auto"
        property string natural: ""      // color natural por defecto (sol, luna…), si existe
        signal picked(string value)

        spacing: 6

        Text {
            width: 120
            anchors.verticalCenter: parent.verticalCenter
            text: picker.label
            font.pixelSize: 12
            color: picker.pal.text
            elide: Text.ElideRight
        }
        Rectangle {
            width: autoText.implicitWidth + 18
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool active: picker.value === "auto" || (picker.natural !== "" && picker.value === picker.natural)
            color: active ? Qt.alpha(picker.pal.primary, 0.2) : "transparent"
            border.color: active ? picker.pal.primary : Qt.alpha(picker.pal.outline, 0.55)
            Text {
                id: autoText
                anchors.centerIn: parent
                text: picker.natural !== "" ? "Natural" : "Auto"
                font.pixelSize: 11
                color: parent.active ? picker.pal.primary : picker.pal.textV
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.picked(picker.natural !== "" ? picker.natural : "auto")
            }
        }
        Repeater {
            model: picker.scheme
            Rectangle {
                required property var modelData
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: modelData
                readonly property bool active: String(picker.value).toLowerCase() === String(modelData).toLowerCase()
                border.color: active ? picker.pal.text : Qt.alpha(picker.pal.outline, 0.8)
                border.width: active ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.picked(String(parent.modelData))
                }
            }
        }
    }

    component Field: Rectangle {
        id: field
        property QtObject pal
        property string label
        property string text
        property var validator
        property int fieldWidth: 120
        readonly property bool valid: input.acceptableInput
        signal accepted(string value)

        implicitWidth: fieldWidth
        implicitHeight: 52
        color: "transparent"

        Text {
            id: fieldLabel
            text: field.label
            font.pixelSize: 11
            color: field.pal.textV
        }
        Rectangle {
            anchors.top: fieldLabel.bottom
            anchors.topMargin: 4
            width: parent.width
            height: 30
            radius: 8
            color: Qt.alpha(field.pal.surface, 0.9)
            border.color: !field.valid ? "#e57373" : input.activeFocus ? field.pal.primary : Qt.alpha(field.pal.outline, 0.6)
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                text: field.text
                validator: field.validator
                color: field.pal.text
                font.pixelSize: 12
                selectByMouse: true
                onEditingFinished: if (acceptableInput) field.accepted(text)
            }
        }
    }

    component SectionTitle: Text {
        property QtObject pal
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 2
        color: pal.primary
    }

    // ── Contenido ────────────────────────────────────────────────────────────
    Flickable {
        id: scroller
        anchors.fill: parent
        contentHeight: page.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: page
        width: scroller.width - 10
        spacing: 16

        // Sección: reloj o reproductor
        RowLayout {
            spacing: 8
            Chip { pal: tab.pal; label: "🕒  Reloj"; active: tab.section === "clock"; onActivated: tab.section = "clock" }
            Chip { pal: tab.pal; label: "♫  Reproductor"; active: tab.section === "player"; onActivated: tab.section = "player" }
            Chip { pal: tab.pal; label: "▶  DaniOS Music"; active: tab.section === "music"; onActivated: tab.section = "music" }
        }

        ColumnLayout {
            id: content
            visible: tab.section === "clock"
            Layout.fillWidth: true
            spacing: 16

            // Encabezado
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { pal: tab.pal; text: "WIDGETS · RELOJ" }
                Item { Layout.fillWidth: true }
                Toggle {
                    pal: tab.pal
                    label: "Mostrar reloj"
                    checked: tab.cfg.clock.enabled !== false
                    onToggled: v => tab.set("clock.enabled", v)
                }
                Chip {
                    pal: tab.pal
                    label: "↺ Restablecer"
                    onActivated: tab.resetClock()
                }
            }

            // Estilo: tres vistas previas en vivo
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: [
                        { id: "analog",  name: "Analógico" },
                        { id: "sunmoon", name: "Sol y luna" },
                        { id: "earth",   name: "Tierra" }
                    ]

                    Rectangle {
                        id: styleCard
                        required property var modelData
                        readonly property bool active: tab.style === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        radius: 14
                        color: Qt.alpha(tab.cSurface, 0.7)
                        border.color: active ? tab.cPrimary : styleMa.containsMouse ? Qt.alpha(tab.cPrimary, 0.5) : Qt.alpha(tab.cOutline, 0.5)
                        border.width: active ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Item {
                            id: previewBox
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: cardName.top
                            anchors.margins: 8
                            clip: true

                            Loader {
                                id: previewLoader
                                anchors.centerIn: parent
                                active: tab.ready
                                readonly property real fit: item ? Math.min(1, previewBox.height / Math.max(1, item.implicitHeight), previewBox.width / Math.max(1, item.implicitWidth)) : 1
                                scale: fit
                                sourceComponent: styleCard.modelData.id === "analog" ? analogPreview
                                               : styleCard.modelData.id === "sunmoon" ? sunMoonPreview : earthPreview
                            }
                        }

                        Text {
                            id: cardName
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: styleCard.modelData.name
                            font.pixelSize: 13
                            font.weight: styleCard.active ? Font.Medium : Font.Normal
                            color: styleCard.active ? tab.cPrimary : tab.cTextV
                        }

                        MouseArea {
                            id: styleMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tab.set("clock.style", styleCard.modelData.id)
                        }
                    }
                }
            }

            // Opciones comunes
            SectionTitle { pal: tab.pal; text: "GENERAL" }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12

                RowLayout {
                    spacing: 8
                    Text { text: "Posición"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "Izquierda"; active: tab.cfg.clock.position === "top-left"; onActivated: tab.set("clock.position", "top-left") }
                    Chip { pal: tab.pal; label: "Derecha"; active: tab.cfg.clock.position !== "top-left"; onActivated: tab.set("clock.position", "top-right") }
                }
                RowLayout {
                    spacing: 8
                    Text { text: "Formato"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "12 h"; active: tab.styleOpts.format24 !== true; onActivated: tab.set("clock." + tab.style + ".format24", false) }
                    Chip { pal: tab.pal; label: "24 h"; active: tab.styleOpts.format24 === true; onActivated: tab.set("clock." + tab.style + ".format24", true) }
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal
                    label: "Tamaño"
                    value: tab.cfg.clock.size || 240
                    from: 160; to: 400; step: 10; decimals: 0; suffix: " px"
                    onCommitted: v => tab.set("clock.size", v)
                }
                Toggle {
                    pal: tab.pal
                    label: "Hora digital"
                    checked: tab.styleOpts.showDigital !== false
                    onToggled: v => tab.set("clock." + tab.style + ".showDigital", v)
                }
            }

            // Opciones del reloj elegido
            SectionTitle {
                pal: tab.pal
                text: tab.style === "analog" ? "ANALÓGICO" : tab.style === "sunmoon" ? "SOL Y LUNA" : "TIERRA"
            }

            // Analógico
            Flow {
                visible: tab.style === "analog"
                Layout.fillWidth: true
                spacing: 16
                RowLayout {
                    spacing: 8
                    Text { text: "Números"; font.pixelSize: 12; color: tab.cText }
                    Chip { pal: tab.pal; label: "1 2 3"; active: tab.styleOpts.numerals !== "roman"; onActivated: tab.set("clock.analog.numerals", "arabic") }
                    Chip { pal: tab.pal; label: "I II III"; active: tab.styleOpts.numerals === "roman"; onActivated: tab.set("clock.analog.numerals", "roman") }
                }
                Toggle {
                    pal: tab.pal; label: "Segundero"
                    checked: tab.styleOpts.seconds === true
                    onToggled: v => tab.set("clock.analog.seconds", v)
                }
            }

            // Sol y luna
            Flow {
                visible: tab.style === "sunmoon"
                Layout.fillWidth: true
                spacing: 16
                RowLayout {
                    spacing: 8
                    Text { text: "Diseño"; font.pixelSize: 12; color: tab.cText }
                    Chip { pal: tab.pal; label: "Transformar"; active: tab.styleOpts.layout !== "arc"; onActivated: tab.set("clock.sunmoon.layout", "transform") }
                    Chip { pal: tab.pal; label: "Arco del día"; active: tab.styleOpts.layout === "arc"; onActivated: tab.set("clock.sunmoon.layout", "arc") }
                }
                Toggle {
                    pal: tab.pal; label: "Amanecer y atardecer"
                    checked: tab.styleOpts.showSunTimes !== false
                    onToggled: v => tab.set("clock.sunmoon.showSunTimes", v)
                }
                Toggle {
                    pal: tab.pal; label: "Fase de la luna"
                    checked: tab.styleOpts.showMoonPhase !== false
                    onToggled: v => tab.set("clock.sunmoon.showMoonPhase", v)
                }
            }

            // Tierra
            ColumnLayout {
                visible: tab.style === "earth"
                Layout.fillWidth: true
                spacing: 12
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    Toggle {
                        pal: tab.pal; label: "Marca en la ciudad"
                        checked: tab.styleOpts.showMarker !== false
                        onToggled: v => tab.set("clock.earth.showMarker", v)
                    }
                    Toggle {
                        pal: tab.pal; label: "Sol y luna orbitando"
                        checked: tab.styleOpts.showSunMoon !== false
                        onToggled: v => tab.set("clock.earth.showSunMoon", v)
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 24
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal
                        label: "Luces de ciudades"
                        value: tab.styleOpts.nightLights || 1.4
                        from: 0.5; to: 2.5; step: 0.1
                        onCommitted: v => tab.set("clock.earth.nightLights", Math.round(v * 10) / 10)
                    }
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal
                        label: "Halo de atmósfera"
                        value: tab.styleOpts.atmosphere !== undefined ? tab.styleOpts.atmosphere : 0.8
                        from: 0; to: 1.5; step: 0.1
                        onCommitted: v => tab.set("clock.earth.atmosphere", Math.round(v * 10) / 10)
                    }
                }
            }

            // Colores
            SectionTitle { pal: tab.pal; text: "COLORES" }
            Column {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: {
                        const names = {
                            numbers: "Números", hourHand: "Aguja de horas", minuteHand: "Aguja de minutos",
                            secondHand: "Segundero", center: "Centro", digital: "Hora digital",
                            sun: "Sol", sunset: "Sol al atardecer", moon: "Luna", moonDark: "Sombra de la luna",
                            arc: "Arco", info: "Textos", atmosphere: "Atmósfera", marker: "Marca"
                        }
                        const colors = (tab.styleOpts.colors || {})
                        return Object.keys(colors).map(k => ({ key: k, name: names[k] || k }))
                    }

                    ColorPicker {
                        required property var modelData
                        pal: tab.pal
                        label: modelData.name
                        value: (tab.styleOpts.colors || {})[modelData.key] || "auto"
                        natural: {
                            const d = tab.defaultOf("clock." + tab.style + ".colors." + modelData.key)
                            return (d && d !== "auto") ? d : ""
                        }
                        scheme: [previewTheme.primary, previewTheme.secondary, previewTheme.tertiary,
                                 previewTheme.textColor, previewTheme.textVariant, "#ffffff", "#000000"]
                        onPicked: v => tab.set("clock." + tab.style + ".colors." + modelData.key, v)
                    }
                }
            }

            // Rendimiento
            SectionTitle { pal: tab.pal; text: "RENDIMIENTO" }
            Flow {
                Layout.fillWidth: true
                spacing: 16
                Toggle {
                    visible: tab.style === "analog"
                    pal: tab.pal; label: "Giro suave de agujas"
                    checked: tab.styleOpts.smoothHands !== false
                    onToggled: v => tab.set("clock.analog.smoothHands", v)
                }
                Toggle {
                    visible: tab.style === "earth"
                    pal: tab.pal; label: "Girar al pasar el mouse"
                    checked: tab.styleOpts.spinOnHover !== false
                    onToggled: v => tab.set("clock.earth.spinOnHover", v)
                }
                Toggle {
                    pal: tab.pal; label: "Sombra (legibilidad)"
                    checked: tab.styleOpts.shadow !== false
                    onToggled: v => tab.set("clock." + tab.style + ".shadow", v)
                }
            }

            // Ubicación
            SectionTitle { pal: tab.pal; text: "UBICACIÓN (sol, luna y Tierra)" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Field {
                    pal: tab.pal; label: "Ciudad"; fieldWidth: 160
                    text: tab.cfg.location.name || ""
                    validator: RegularExpressionValidator { regularExpression: /.{0,40}/ }
                    onAccepted: v => tab.set("location.name", v)
                }
                Field {
                    pal: tab.pal; label: "Latitud (−90 a 90)"
                    text: String(tab.cfg.location.latitude)
                    validator: DoubleValidator { bottom: -90; top: 90; decimals: 4; notation: DoubleValidator.StandardNotation; locale: "C" }
                    onAccepted: v => tab.set("location.latitude", parseFloat(v))
                }
                Field {
                    pal: tab.pal; label: "Longitud (−180 a 180)"
                    text: String(tab.cfg.location.longitude)
                    validator: DoubleValidator { bottom: -180; top: 180; decimals: 4; notation: DoubleValidator.StandardNotation; locale: "C" }
                    onAccepted: v => tab.set("location.longitude", parseFloat(v))
                }
                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 8
                    text: "Enter para guardar. Sin internet: se usa para el amanecer, el atardecer y centrar la Tierra."
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: tab.cTextV
                }
            }

        }

        // ══ Reproductor ══════════════════════════════════════════════════════
        ColumnLayout {
            visible: tab.section === "player"
            Layout.fillWidth: true
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                SectionTitle { pal: tab.pal; text: "WIDGETS · REPRODUCTOR" }
                Item { Layout.fillWidth: true }
                Toggle {
                    pal: tab.pal
                    label: "Mostrar reproductor"
                    checked: tab.pl.enabled !== false
                    onToggled: v => tab.set("player.enabled", v)
                }
                Chip { pal: tab.pal; label: "↺ Restablecer"; onActivated: tab.resetPlayer() }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Aparece solo cuando hay música (Spotify, YouTube en el navegador…). Rueda del mouse sobre la tarjeta = volumen de esa app; clic en el nombre del reproductor = cambiar de reproductor."
                font.pixelSize: 11
                color: tab.cTextV
            }

            SectionTitle { pal: tab.pal; text: "ESTILO" }
            RowLayout {
                spacing: 8
                Chip { pal: tab.pal; label: "▭  Tarjeta"; active: (tab.pl.style || "card") === "card"; onActivated: tab.set("player.style", "card") }
                Chip { pal: tab.pal; label: "◉  Vinilo"; active: tab.pl.style === "vinyl"; onActivated: tab.set("player.style", "vinyl") }
            }
            ColumnLayout {
                visible: tab.pl.style === "vinyl"
                Layout.fillWidth: true
                spacing: 12
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    Toggle { pal: tab.pal; label: "Girar el disco"; checked: (tab.pl.vinyl || {}).spin !== false; onToggled: v => tab.set("player.vinyl.spin", v) }
                    Toggle { pal: tab.pal; label: "Funda (portada)"; checked: (tab.pl.vinyl || {}).sleeve !== false; onToggled: v => tab.set("player.vinyl.sleeve", v) }
                    Toggle { pal: tab.pal; label: "Brazo"; checked: (tab.pl.vinyl || {}).tonearm !== false; onToggled: v => tab.set("player.vinyl.tonearm", v) }
                }
                RowLayout {
                    spacing: 8
                    Text { text: "Velocidad"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "33 rpm"; active: Math.round((tab.pl.vinyl || {}).rpm || 33.3) === 33; onActivated: tab.set("player.vinyl.rpm", 33.3) }
                    Chip { pal: tab.pal; label: "45 rpm"; active: Math.round((tab.pl.vinyl || {}).rpm || 33.3) === 45; onActivated: tab.set("player.vinyl.rpm", 45) }
                    Item { width: 16 }
                    Text { text: "Fluidez del giro"; font.pixelSize: 12; color: tab.cText }
                    Repeater {
                        model: [{ l: "20 fps (ahorro)", v: 20 }, { l: "30 fps", v: 30 }, { l: "60 fps", v: 60 }]
                        Chip {
                            required property var modelData
                            pal: tab.pal; label: modelData.l
                            active: ((tab.pl.vinyl || {}).fps || 30) === modelData.v
                            onActivated: tab.set("player.vinyl.fps", modelData.v)
                        }
                    }
                }
            }

            SectionTitle { pal: tab.pal; text: "GENERAL" }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12

                RowLayout {
                    spacing: 8
                    Text { text: "Posición"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "Izquierda"; active: tab.pl.position !== "bottom-right"; onActivated: tab.set("player.position", "bottom-left") }
                    Chip { pal: tab.pal; label: "Derecha"; active: tab.pl.position === "bottom-right"; onActivated: tab.set("player.position", "bottom-right") }
                }
                RowLayout {
                    spacing: 8
                    Text { text: "Fondo"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "Portada"; active: tab.pl.background !== "solid"; onActivated: tab.set("player.background", "art") }
                    Chip { pal: tab.pal; label: "Liso"; active: tab.pl.background === "solid"; onActivated: tab.set("player.background", "solid") }
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Ancho"
                    value: tab.pl.width || 380
                    from: 300; to: 520; step: 10; decimals: 0; suffix: " px"
                    onCommitted: v => tab.set("player.width", v)
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Separación del borde inferior (menos de 80 px: Caelestia tapa los botones con el escritorio vacío)"
                    value: tab.pl.marginY ?? 90
                    from: 20; to: 300; step: 5; decimals: 0; suffix: " px"
                    onCommitted: v => tab.set("player.marginY", v)
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Separación del borde lateral"
                    value: tab.pl.marginX ?? 40
                    from: 0; to: 300; step: 5; decimals: 0; suffix: " px"
                    onCommitted: v => tab.set("player.marginX", v)
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Opacidad del fondo"
                    value: tab.pl.opacity ?? 0.85
                    from: 0.3; to: 1; step: 0.05; decimals: 2
                    onCommitted: v => tab.set("player.opacity", Math.round(v * 100) / 100)
                }
                RowLayout {
                    spacing: 8
                    Text { text: "En pausa"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Repeater {
                        model: [{ l: "Ocultar ya", v: 0 }, { l: "1 min", v: 60 }, { l: "5 min", v: 300 }, { l: "Nunca", v: -1 }]
                        Chip {
                            required property var modelData
                            pal: tab.pal; label: modelData.l
                            active: (tab.pl.hideAfterPaused ?? 300) === modelData.v
                            onActivated: tab.set("player.hideAfterPaused", modelData.v)
                        }
                    }
                }
                Flow {
                    spacing: 16
                    Toggle { pal: tab.pal; label: "Reproductor"; checked: tab.pl.showPlayerName !== false; onToggled: v => tab.set("player.showPlayerName", v) }
                    Toggle { pal: tab.pal; label: "Progreso"; checked: tab.pl.showProgress !== false; onToggled: v => tab.set("player.showProgress", v) }
                    Toggle { pal: tab.pal; label: "Volumen"; checked: tab.pl.showVolume !== false; onToggled: v => tab.set("player.showVolume", v) }
                }
            }

            // Reproductor preferido (cuando suenan varios a la vez)
            RowLayout {
                spacing: 8
                Text { text: "Preferido"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                Chip { pal: tab.pal; label: "Automático"; active: !tab.pl.preferred; onActivated: tab.set("player.preferred", "") }
                Repeater {
                    // reproductores abiertos ahora (sin duplicados ni vacíos) + el guardado
                    model: {
                        const names = Mpris.players.values.filter(p => (p.trackTitle ?? "") !== "").map(p => p.identity)
                        if (tab.pl.preferred) names.push(tab.pl.preferred)
                        return [...new Set(names)]
                    }
                    Chip {
                        required property var modelData
                        pal: tab.pal; label: modelData
                        active: tab.pl.preferred === modelData
                        onActivated: tab.set("player.preferred", modelData)
                    }
                }
            }

            // cava
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { pal: tab.pal; text: "VISUALIZADOR (CAVA)" }
                Item { Layout.fillWidth: true }
                Toggle { pal: tab.pal; label: "Activar"; checked: tab.cv.enabled !== false; onToggled: v => tab.set("player.cava.enabled", v) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                enabled: tab.cv.enabled !== false
                opacity: enabled ? 1 : 0.4

                RowLayout {
                    spacing: 8
                    Text { text: "Modo"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "Abajo de la pantalla"; active: (tab.cv.mode || "bottom") === "bottom"; onActivated: tab.set("player.cava.mode", "bottom") }
                    Chip { pal: tab.pal; label: "Arriba y abajo"; active: tab.cv.mode === "mirror"; onActivated: tab.set("player.cava.mode", "mirror") }
                    Chip { pal: tab.pal; label: tab.pl.style === "vinyl" ? "Alrededor del disco" : "Contorno del reproductor"; active: tab.cv.mode === "circle"; onActivated: tab.set("player.cava.mode", "circle") }
                }
                RowLayout {
                    spacing: 8
                    Text { text: "Forma"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "Barras"; active: (tab.cv.shape || "bars") === "bars"; onActivated: tab.set("player.cava.shape", "bars") }
                    Chip { pal: tab.pal; label: "Onda"; active: tab.cv.shape === "wave"; onActivated: tab.set("player.cava.shape", "wave") }
                    Chip { pal: tab.pal; label: "Puntos"; active: tab.cv.shape === "dots"; onActivated: tab.set("player.cava.shape", "dots") }
                    Item { width: 16 }
                    Toggle { pal: tab.pal; label: "Estéreo"; checked: tab.cv.stereo !== false; onToggled: v => tab.set("player.cava.stereo", v) }
                    Toggle { pal: tab.pal; label: "Redondeadas"; checked: tab.cv.rounded !== false; onToggled: v => tab.set("player.cava.rounded", v) }
                }
                Toggle {
                    visible: tab.cv.mode !== "circle"
                    pal: tab.pal
                    label: "Ocultar cuando hay ventanas (no dibuja ni calcula detrás de ellas)"
                    checked: tab.cv.autoHide !== false
                    onToggled: v => tab.set("player.cava.autoHide", v)
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 12
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal; label: "Número de barras"
                        value: tab.cv.bars || 32
                        from: 8; to: 64; step: 2; decimals: 0
                        onCommitted: v => tab.set("player.cava.bars", v)
                    }
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal; label: "Grosor"
                        value: tab.cv.thickness || 0.85
                        from: 0.2; to: 1; step: 0.05; decimals: 2
                        onCommitted: v => tab.set("player.cava.thickness", Math.round(v * 100) / 100)
                    }
                    Slider {
                        Layout.fillWidth: true
                        visible: tab.cv.mode !== "circle"
                        pal: tab.pal; label: "Altura (parte de la pantalla)"
                        value: tab.cv.height || 0.35
                        from: 0.1; to: 0.6; step: 0.05; decimals: 2
                        onCommitted: v => tab.set("player.cava.height", Math.round(v * 100) / 100)
                    }
                    Slider {
                        Layout.fillWidth: true
                        visible: tab.cv.mode === "circle"
                        pal: tab.pal; label: "Alcance alrededor"
                        value: tab.cv.circleReach || 26
                        from: 10; to: 60; step: 2; decimals: 0; suffix: " px"
                        onCommitted: v => tab.set("player.cava.circleReach", v)
                    }
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal; label: "Opacidad"
                        value: tab.cv.opacity || 0.7
                        from: 0.1; to: 1; step: 0.05; decimals: 2
                        onCommitted: v => tab.set("player.cava.opacity", Math.round(v * 100) / 100)
                    }
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal; label: "Sensibilidad"
                        value: tab.cv.sensitivity || 100
                        from: 40; to: 250; step: 10; decimals: 0; suffix: " %"
                        onCommitted: v => tab.set("player.cava.sensitivity", v)
                    }
                    Slider {
                        Layout.fillWidth: true
                        pal: tab.pal; label: "Suavizado"
                        value: tab.cv.smoothing ?? 77
                        from: 0; to: 100; step: 1; decimals: 0
                        onCommitted: v => tab.set("player.cava.smoothing", v)
                    }
                    RowLayout {
                        spacing: 8
                        Text { text: "Fluidez"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                        Chip { pal: tab.pal; label: "30 fps (ahorro)"; active: (tab.cv.framerate || 30) === 30; onActivated: tab.set("player.cava.framerate", 30) }
                        Chip { pal: tab.pal; label: "60 fps"; active: tab.cv.framerate === 60; onActivated: tab.set("player.cava.framerate", 60) }
                    }
                }

                RowLayout {
                    spacing: 8
                    Text { text: "Color"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "De la portada"; active: tab.cv.colorMode === "art"; onActivated: tab.set("player.cava.colorMode", "art") }
                    Chip { pal: tab.pal; label: "Un color"; active: tab.cv.colorMode === "auto"; onActivated: tab.set("player.cava.colorMode", "auto") }
                    Chip { pal: tab.pal; label: "Degradado"; active: (tab.cv.colorMode || "gradient") === "gradient"; onActivated: tab.set("player.cava.colorMode", "gradient") }
                }
                ColorPicker {
                    visible: tab.cv.colorMode !== "art"
                    pal: tab.pal
                    label: tab.cv.colorMode !== "gradient" ? "Color" : tab.cv.mode === "circle" ? "Color del centro" : "Color de la base"
                    value: (tab.cv.colors || {}).a || "auto"
                    scheme: [previewTheme.primary, previewTheme.secondary, previewTheme.tertiary,
                             previewTheme.textColor, previewTheme.textVariant, "#ffffff", "#000000"]
                    onPicked: v => tab.set("player.cava.colors.a", v)
                }
                ColorPicker {
                    visible: (tab.cv.colorMode || "gradient") === "gradient"
                    pal: tab.pal
                    label: tab.cv.mode === "circle" ? "Color de los lados" : "Color de la punta"
                    value: (tab.cv.colors || {}).b || "auto"
                    scheme: [previewTheme.primary, previewTheme.secondary, previewTheme.tertiary,
                             previewTheme.textColor, previewTheme.textVariant, "#ffffff", "#000000"]
                    onPicked: v => tab.set("player.cava.colors.b", v)
                }
            }

            SectionTitle { pal: tab.pal; text: "COLORES DE LA TARJETA" }
            Column {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [{ key: "accent", name: "Acento (botón, progreso)" }, { key: "text", name: "Título" }, { key: "subtext", name: "Artista y tiempos" }]
                    ColorPicker {
                        required property var modelData
                        pal: tab.pal
                        label: modelData.name
                        value: (tab.pl.colors || {})[modelData.key] || "auto"
                        scheme: [previewTheme.primary, previewTheme.secondary, previewTheme.tertiary,
                                 previewTheme.textColor, previewTheme.textVariant, "#ffffff", "#000000"]
                        onPicked: v => tab.set("player.colors." + modelData.key, v)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Acento en Auto = color de la portada de cada canción. Las barras van en los bordes de la pantalla (reemplazan al visualizador de Caelestia) o alrededor del reproductor; dentro de la tarjeta no hay barras. cava solo corre mientras suena música y se ve (0 % en pausa o con ventanas)."
                font.pixelSize: 11
                color: tab.cTextV
            }
        }

        // ══ DaniOS Music ════════════════════════════════════════════════════
        ColumnLayout {
            visible: tab.section === "music"
            Layout.fillWidth: true
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                SectionTitle { pal: tab.pal; text: "DANIOS MUSIC" }
                Item { Layout.fillWidth: true }
                Chip { pal: tab.pal; label: "↺ Restablecer"; onActivated: music.reset() }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Reproductor a pantalla completa (Super + M). Los cambios se aplican al instante si está abierto."
                font.pixelSize: 11
                color: tab.cTextV
            }

            SectionTitle { pal: tab.pal; text: "VIDEOCLIP" }
            Flow {
                Layout.fillWidth: true
                spacing: 16
                Toggle { pal: tab.pal; label: "Videoclip de fondo"; checked: (tab.mu.video || {}).enabled !== false; onToggled: v => music.set("video.enabled", v) }
                Toggle { pal: tab.pal; label: "Solo videoclips reales (no letras ni portadas fijas)"; checked: (tab.mu.video || {}).onlyMusicVideos !== false; onToggled: v => music.set("video.onlyMusicVideos", v) }
                Toggle { pal: tab.pal; label: "Recortar franjas negras"; checked: (tab.mu.video || {}).cropBars !== false; onToggled: v => music.set("video.cropBars", v) }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12
                RowLayout {
                    spacing: 8
                    Text { text: "Calidad"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "720p (menos red)"; active: ((tab.mu.video || {}).maxHeight || 1080) === 720; onActivated: music.set("video.maxHeight", 720) }
                    Chip { pal: tab.pal; label: "1080p"; active: ((tab.mu.video || {}).maxHeight || 1080) === 1080; onActivated: music.set("video.maxHeight", 1080) }
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Oscurecer el video"
                    value: (tab.mu.video || {}).dim ?? 0.35
                    from: 0; to: 0.7; step: 0.05; decimals: 2
                    onCommitted: v => music.set("video.dim", Math.round(v * 100) / 100)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                SectionTitle { pal: tab.pal; text: "BORDES DE NEÓN" }
                Item { Layout.fillWidth: true }
                Toggle { pal: tab.pal; label: "Activar"; checked: (tab.mu.edges || {}).enabled !== false; onToggled: v => music.set("edges.enabled", v) }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12
                enabled: (tab.mu.edges || {}).enabled !== false
                opacity: enabled ? 1 : 0.4
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Intensidad"
                    value: (tab.mu.edges || {}).intensity ?? 1
                    from: 0.3; to: 1.6; step: 0.05; decimals: 2
                    onCommitted: v => music.set("edges.intensity", Math.round(v * 100) / 100)
                }
                Slider {
                    Layout.fillWidth: true
                    pal: tab.pal; label: "Alcance hacia dentro"
                    value: (tab.mu.edges || {}).reach || 0.11
                    from: 0.04; to: 0.25; step: 0.01; decimals: 2
                    onCommitted: v => music.set("edges.reach", Math.round(v * 100) / 100)
                }
                RowLayout {
                    spacing: 8
                    Text { text: "Fluidez"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                    Chip { pal: tab.pal; label: "30 fps (ahorro)"; active: ((tab.mu.edges || {}).framerate || 30) === 30; onActivated: music.set("edges.framerate", 30) }
                    Chip { pal: tab.pal; label: "60 fps"; active: (tab.mu.edges || {}).framerate === 60; onActivated: music.set("edges.framerate", 60) }
                }
            }

            SectionTitle { pal: tab.pal; text: "HORA" }
            RowLayout {
                spacing: 8
                Text { text: "Formato"; font.pixelSize: 12; color: tab.cText; Layout.preferredWidth: 70 }
                Chip { pal: tab.pal; label: "12 h"; active: (tab.mu.clock || {}).format24 !== true; onActivated: music.set("clock.format24", false) }
                Chip { pal: tab.pal; label: "24 h"; active: (tab.mu.clock || {}).format24 === true; onActivated: music.set("clock.format24", true) }
            }
        }

        Item { Layout.preferredHeight: 8 }
      }
    }

    // ── Vistas previas (mismos componentes que el escritorio) ────────────────
    Component {
        id: analogPreview
        DWW.ClockAnalog {
            opts: tab.cfg.clock.analog
            theme: previewTheme
            size: 150
        }
    }
    Component {
        id: sunMoonPreview
        DWW.ClockSunMoon {
            opts: tab.cfg.clock.sunmoon
            theme: previewTheme
            location: tab.cfg.location
            size: 150
        }
    }
    Component {
        id: earthPreview
        DWW.ClockEarth {
            opts: tab.cfg.clock.earth
            theme: previewTheme
            location: tab.cfg.location
            size: 150
        }
    }
}
