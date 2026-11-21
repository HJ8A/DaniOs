// Tarjeta de vidrio con la portada, el título y el artista. La portada
// (AlbumArt de desktop-widgets) calcula además el color vivo de la canción.
// Es clicable (abre el buscador): cursor de mano y crece un poco al pasar.
import QtQuick
import "../dw/common" as DW

Glass {
    id: root

    property var    media
    property real   coverSize: 220
    property color  textColor: "white"
    property color  subColor: "#d0d0d0"
    property string fontFamily: "Rubik"

    readonly property var player: media ? media.active : null
    readonly property var vivid: cover.vivid       // color de la canción (o null)
    readonly property string artUrl: media ? media.artUrl(player) : ""
    signal clicked()

    scale: cardMa.pressed ? 0.98 : cardMa.containsMouse ? 1.035 : 1
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    radius: 26
    width: coverSize + 36
    height: coverSize + 36 + titleText.implicitHeight + artistText.implicitHeight + 14

    DW.AlbumArt {
        id: cover
        x: 18
        y: 18
        width: root.coverSize
        height: width
        radius: 16
        media: root.media
        source: root.artUrl
        placeholderColor: root.subColor
    }

    Text {
        id: titleText
        anchors.top: cover.bottom
        anchors.topMargin: 12
        anchors.left: cover.left
        anchors.right: cover.right
        horizontalAlignment: Text.AlignHCenter
        text: root.player ? root.player.trackTitle : ""
        elide: Text.ElideRight
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.coverSize * 0.085)
        font.weight: Font.DemiBold
    }
    Text {
        id: artistText
        anchors.top: titleText.bottom
        anchors.left: cover.left
        anchors.right: cover.right
        horizontalAlignment: Text.AlignHCenter
        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
        elide: Text.ElideRight
        color: root.subColor
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.coverSize * 0.065)
    }

    MouseArea {
        id: cardMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
