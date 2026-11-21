// Cápsula de vidrio abajo: ⏮ ⏯ ⏭ · mini portada + título · progreso ·
// volumen de la app · reproductor. Rueda del mouse = volumen.
import QtQuick
import "../dw/common" as DW

Glass {
    id: root

    property var    media
    property color  accent: "#c2c1ff"
    property color  textColor: "white"
    property color  subColor: "#d0d0d0"
    property string fontFamily: "Rubik"
    property string videoState: "idle"       // ver VideoToggle.qml
    signal videoToggled()

    readonly property var player: media ? media.active : null

    radius: height / 2
    height: 68

    WheelHandler {
        enabled: root.media?.volumeSupported ?? false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.media.setVolume(root.media.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        DW.PlayerControls {
            anchors.verticalCenter: parent.verticalCenter
            player: root.player
            size: 42
            fg: root.textColor
            accent: root.accent
        }

        DW.AlbumArt {
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            radius: 9
            sampleColor: false
            source: root.media ? root.media.artUrl(root.player) : ""
            placeholderColor: root.subColor
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 190
            Text {
                width: parent.width
                text: root.player ? root.player.trackTitle : ""
                elide: Text.ElideRight
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: root.player ? (root.player.trackArtist || "") : ""
                elide: Text.ElideRight
                color: root.subColor
                font.family: root.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        VideoToggle {
            anchors.verticalCenter: parent.verticalCenter
            state_: root.videoState
            accent: root.accent
            textColor: root.textColor
            subColor: root.subColor
            fontFamily: root.fontFamily
            onToggled: root.videoToggled()
        }
        DW.PlayerVolume {
            anchors.verticalCenter: parent.verticalCenter
            width: 110
            height: 22
            visible: available
            media: root.media
            textColor: root.textColor
            subColor: root.subColor
        }
        DW.PlayerChip {
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            media: root.media
            fontFamily: root.fontFamily
            textColor: root.textColor
            subColor: root.subColor
        }
    }

    DW.PlayerProgress {
        anchors.left: left.right
        anchors.leftMargin: 18
        anchors.right: right.left
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        player: root.player
        fontSize: 11
        fontFamily: root.fontFamily
        textColor: root.textColor
        subColor: root.subColor
        accent: root.accent
    }
}
