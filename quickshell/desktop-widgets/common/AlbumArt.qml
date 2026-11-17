// Portada del álbum con esquinas redondeadas y su color más vivo.
//
// `vivid` (color o null) sale de una captura pequeña de la portada ya cargada
// (el cuantizador de Quickshell no lee URLs remotas) y se publica en
// `media.artColor` para cava. Se calcula una vez por portada.
import QtQuick
import Quickshell
import Quickshell.Widgets

ClippingRectangle {
    id: root

    property var    media
    property string source: ""
    property color  placeholderColor: "#cccccc"
    property string iconFont: "Material Symbols Rounded"

    readonly property bool ready: image.status === Image.Ready
    property color vividColor: "transparent"
    readonly property var vivid: vividColor.a > 0 ? vividColor : null

    color: Qt.alpha(placeholderColor, 0.15)

    Text {
        anchors.centerIn: parent
        visible: !root.ready
        text: "music_note"
        font.family: root.iconFont
        font.pixelSize: parent.width * 0.4
        color: root.placeholderColor
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        onStatusChanged: if (status === Image.Ready) root.sample()
    }

    readonly property string samplePath: Quickshell.env("XDG_RUNTIME_DIR") + "/desktop-widgets-art.png"

    function sample() {
        image.grabToImage(result => {
            if (result.saveToFile(root.samplePath)) {
                quantizer.source = ""
                quantizer.source = "file://" + root.samplePath
            }
        }, Qt.size(48, 48))
    }

    ColorQuantizer {
        id: quantizer
        depth: 3
        rescaleSize: 48
        onColorsChanged: {
            let best = null, score = -1
            for (const c of quantizer.colors) {
                const s = c.hsvSaturation * c.hsvValue
                if (c.hsvValue > 0.35 && s > score) {
                    score = s
                    best = c
                }
            }
            root.vividColor = best ? Qt.hsva(best.hsvHue, Math.min(1, best.hsvSaturation * 1.1), Math.max(0.75, best.hsvValue), 1) : "transparent"
            if (root.media)
                root.media.artColor = root.vividColor
        }
    }
}
