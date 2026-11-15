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
    property var defaults: ({ clock: { analog: {}, sunmoon: {}, earth: {} }, location: {} })
    property var user: ({})
    readonly property var cfg: merge(defaults, user)
    // true cuando defaults.json ya se leyó (antes no se crean las vistas previas)
    readonly property bool ready: defaults.location.latitude !== undefined
    readonly property string style: cfg.clock.style || "analog"
    readonly property var styleOpts: cfg.clock[style] || ({})

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
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: scroller.width - 10
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
