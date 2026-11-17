// ⏮ ⏯ ⏭ del reproductor activo.
import QtQuick

Row {
    id: root

    property var   player
    property real  size: 34          // diámetro del botón de play
    property color fg: "white"
    property color accent: "#c2c1ff"

    spacing: Math.round(size * 0.16)

    MediaButton {
        icon: "skip_previous"
        size: Math.round(root.size * 0.88)
        fg: root.fg
        enabledBtn: root.player?.canGoPrevious ?? false
        onClicked: root.player.previous()
        anchors.verticalCenter: parent.verticalCenter
    }
    MediaButton {
        icon: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
        primary: true
        size: root.size
        bg: root.accent
        enabledBtn: root.player?.canTogglePlaying ?? false
        onClicked: root.player.togglePlaying()
        anchors.verticalCenter: parent.verticalCenter
    }
    MediaButton {
        icon: "skip_next"
        size: Math.round(root.size * 0.88)
        fg: root.fg
        enabledBtn: root.player?.canGoNext ?? false
        onClicked: root.player.next()
        anchors.verticalCenter: parent.verticalCenter
    }
}
