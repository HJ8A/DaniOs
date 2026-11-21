// Botón del videoclip + estado. Clic = activar/desactivar (se guarda).
//
//   disabled   videocam_off (tenue)   "Videoclip apagado"
//   resolving  girando                "Buscando videoclip…"
//   loading    girando                "Cargando video…"
//   playing    videocam (acento)      —
//   none       videocam_off           "Sin videoclip"
//   error      wifi_off               "No se pudo cargar"
//
// El giro solo corre mientras busca/carga (unos segundos).
import QtQuick

Rectangle {
    id: root

    property string state_: "idle"
    property color  accent: "white"
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property string fontFamily: "Rubik"
    signal toggled()

    readonly property bool busy: state_ === "resolving" || state_ === "loading"
    readonly property string icon: state_ === "playing" ? "videocam"
                                 : busy ? "progress_activity"
                                 : state_ === "error" ? "wifi_off"
                                 : "videocam_off"
    readonly property string label: state_ === "disabled" ? "Videoclip apagado"
                                  : state_ === "resolving" ? "Buscando videoclip…"
                                  : state_ === "loading" ? "Cargando video…"
                                  : state_ === "none" ? "Sin videoclip"
                                  : state_ === "error" ? "No se pudo cargar"
                                  : ""

    visible: state_ !== "idle"
    implicitHeight: 30
    implicitWidth: row.implicitWidth + 18
    radius: height / 2
    color: Qt.alpha(textColor, ma.containsMouse ? 0.16 : 0.08)
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: root.state_ === "playing" ? root.accent : root.state_ === "disabled" ? Qt.alpha(root.subColor, 0.6) : root.subColor

            RotationAnimator on rotation {
                running: root.busy && root.visible
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                onRunningChanged: if (!running) glyph.rotation = 0
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font.family: root.fontFamily
            font.pixelSize: 12
            color: root.subColor
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
