// Panel de la tarjeta: reproductor, título, artista, progreso, ⏮ ⏯ ⏭ y
// volumen. Compuesto con las piezas Player* (que el vinilo coloca a su
// manera). Las medidas salen de `unit` (alto de referencia de la tarjeta).
import QtQuick

Item {
    id: root

    property var    media
    property var    opts: ({})
    property real   unit: 152
    property color  textColor: "white"
    property color  subColor: "#cccccc"
    property color  accent: "#c2c1ff"
    property string fontFamily: "Rubik"
    readonly property var player: media ? media.active : null

    PlayerChip {
        id: chip
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(root.unit * 0.12)
        visible: root.opts.showPlayerName !== false
        media: root.media
        fontFamily: root.fontFamily
        textColor: root.textColor
        subColor: root.subColor
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.right: chip.visible ? chip.left : parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        text: root.player ? root.player.trackTitle : ""
        elide: Text.ElideRight
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.unit * 0.115)
        font.weight: Font.DemiBold
        color: root.textColor
    }
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: 1
        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
        elide: Text.ElideRight
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.unit * 0.088)
        color: root.subColor
    }

    PlayerProgress {
        id: progress
        visible: root.opts.showProgress !== false && available
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: controls.top
        anchors.bottomMargin: 2
        height: Math.round(root.unit * 0.13)
        player: root.player
        fontSize: Math.round(root.unit * 0.068)
        fontFamily: root.fontFamily
        textColor: root.textColor
        subColor: root.subColor
        accent: root.accent
    }

    PlayerControls {
        id: controls
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        player: root.player
        size: Math.round(root.unit * 0.25)
        fg: root.textColor
        accent: root.accent
    }

    PlayerVolume {
        visible: root.opts.showVolume !== false && available
        anchors.left: controls.right
        anchors.leftMargin: Math.round(root.unit * 0.06)
        anchors.right: parent.right
        anchors.verticalCenter: controls.verticalCenter
        height: Math.round(root.unit * 0.18)
        media: root.media
        textColor: root.textColor
        subColor: root.subColor
    }
}
