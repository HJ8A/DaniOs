import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    property color clBg:         "#131317"
    property color clSurface:    "#1c1b20"
    property color clSurfaceHi:  "#26252b"
    property color clPrimary:    "#c2c1ff"
    property color clOnSurface:  "#e5e1e7"
    property color clOnSurfaceV: "#a8a5b1"
    property color clOutline:    "#3a3940"

    // Order categories should appear in
    property var categoryOrder: ["Apps", "Shell", "Ventanas", "Grupos", "Workspaces",
                                  "Especiales", "Personalizados", "Screenshots", "Media", "Sistema"]

    property var rawVarRows: []
    property var rawCustomRows: []
    property string filterText: ""

    function modmaskToString(m) {
        var parts = []
        if (m & 64) parts.push("SUPER")
        if (m & 4)  parts.push("CTRL")
        if (m & 8)  parts.push("ALT")
        if (m & 1)  parts.push("SHIFT")
        return parts
    }

    function prettyKey(k) {
        var map = {
            "bracketright": "]", "bracketleft": "[", "comma": ",",
            "mouse:272": "Mouse Left", "mouse:273": "Mouse Right",
            "mouse_down": "Scroll Down", "mouse_up": "Scroll Up",
            "Return": "Enter", "period": ".",
        }
        return map[k] || k
    }

    // Rebuild the flat, filtered, section-grouped list model
    function rebuild() {
        var all = rawVarRows.concat(rawCustomRows)

        // Dedup by key (custom descriptions win over generic ones)
        var byKey = {}
        for (var i = 0; i < all.length; i++) {
            var r = all[i]
            byKey[r.key] = r
        }
        var merged = Object.values(byKey)

        var f = root.filterText
        if (f) {
            merged = merged.filter(function(r) {
                return r.key.toLowerCase().indexOf(f) !== -1 || r.label.toLowerCase().indexOf(f) !== -1
            })
        }

        var byCat = {}
        for (var j = 0; j < merged.length; j++) {
            var row = merged[j]
            if (!byCat[row.category]) byCat[row.category] = []
            byCat[row.category].push(row)
        }
        for (var cat in byCat) {
            byCat[cat].sort(function(a, b) { return a.label.localeCompare(b.label) })
        }

        var out = []
        var cats = root.categoryOrder.filter(function(c) { return byCat[c] && byCat[c].length })
        var extra = Object.keys(byCat).filter(function(c) { return cats.indexOf(c) === -1 })
        cats = cats.concat(extra)

        for (var k = 0; k < cats.length; k++) {
            var c = cats[k]
            out.push({ isHeader: true, category: c, count: byCat[c].length })
            for (var m = 0; m < byCat[c].length; m++) {
                out.push({ isHeader: false, key: byCat[c][m].key, label: byCat[c][m].label })
            }
        }
        listModel = out
    }

    property var listModel: []

    Process {
        id: varProc
        command: ["lua5.4", Qt.resolvedUrl("gen_keybinds.lua").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.rawVarRows = JSON.parse(this.text) } catch (e) { root.rawVarRows = [] }
                root.rebuild()
            }
        }
    }

    Process {
        id: customProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    var out = []
                    for (var i = 0; i < parsed.length; i++) {
                        var b = parsed[i]
                        if (!b.has_description || (b.submap && b.submap !== "")) continue
                        var mods = root.modmaskToString(b.modmask)
                        var keyLabel = (mods.length ? mods.join(" + ") + " + " : "") + root.prettyKey(b.key || "?")
                        out.push({ key: keyLabel, category: "Personalizados", label: b.description })
                    }
                    root.rawCustomRows = out
                } catch (e) {
                    root.rawCustomRows = []
                }
                root.rebuild()
            }
        }
    }

    Component.onCompleted: {
        varProc.running = true
        customProc.running = true
    }

    PanelWindow {
        id: overlay
        visible: true

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace:     "keybinds-viewer"
        WlrLayershell.exclusiveZone: -1

        anchors { top: true; bottom: true; left: true; right: true }
        color: "#cc000000"

        MouseArea {
            anchors.fill: parent
            Keys.onEscapePressed: Qt.quit()
            onClicked: Qt.quit()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width:  Math.min(parent.width * 0.6, 720)
            height: Math.min(parent.height * 0.86, 860)
            radius: 20
            color: root.clBg
            border.color: root.clOutline
            border.width: 1

            opacity: 0; scale: 0.96
            NumberAnimation on opacity { running: true; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation on scale   { running: true; to: 1; duration: 180; easing.type: Easing.OutCubic }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Atajos de teclado"
                        color: root.clOnSurface
                        font.pixelSize: 20
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "leído en vivo de tu config"
                        color: root.clOnSurfaceV
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 10
                    color: root.clSurface
                    border.color: searchField.activeFocus ? root.clPrimary : root.clOutline
                    border.width: 1

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 10
                        color: root.clOnSurface
                        font.pixelSize: 14
                        focus: true
                        clip: true
                        onTextChanged: { root.filterText = text.toLowerCase(); root.rebuild() }

                        Text {
                            visible: searchField.text.length === 0
                            text: "Buscar atajo o acción…"
                            color: root.clOnSurfaceV
                            font.pixelSize: 14
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.listModel

                    delegate: Item {
                        width: list.width
                        height: modelData.isHeader ? 30 : 36

                        Text {
                            visible: modelData.isHeader
                            text: modelData.isHeader ? (modelData.category + "  ·  " + modelData.count) : ""
                            color: root.clPrimary
                            font.pixelSize: 12
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.top: index === 0 ? undefined : parent.top
                            anchors.topMargin: index === 0 ? 0 : 10
                        }

                        RowLayout {
                            visible: !modelData.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: keyText.implicitWidth + 16
                                Layout.preferredHeight: 22
                                radius: 6
                                color: root.clSurfaceHi

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.key || ""
                                    color: root.clPrimary
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }
                            }

                            Text {
                                text: modelData.label || ""
                                color: root.clOnSurface
                                font.pixelSize: 13
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
