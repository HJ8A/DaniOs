// Fondo a pantalla completa: el videoclip (sin audio) sincronizado con la
// canción; mientras se busca o si no hay video, la portada desenfocada.
//
// Carga: el video se carga aunque la ventana esté oculta (precarga) y al
// ocultarla solo se PAUSA (sin CPU ni red); al volver sigue al instante.
//
// Sincronización (medido: saltar cada vez que había desvío dejaba el video
// "cargando" en bucle y se veía congelado):
//   · al cargar, UN salto a la posición de Spotify (+ un margen por la carga);
//   · después, desvíos pequeños se corrigen acelerando o frenando un poco
//     (±10 %), sin saltos; solo un desvío grande (> 3 s, p. ej. el usuario
//     movió la barra) provoca un salto;
//   · nunca se corrige mientras el video está cargando.
// Rendimiento: el video lo decodifica la GPU (VA-API).
import QtQuick
import QtQuick.Effects
import QtMultimedia

Item {
    id: root

    property var    player                // MprisPlayer
    property string videoUrl: ""
    property string artUrl: ""
    property bool   active: true          // false = ventana oculta → pausa
    property real   dim: 0.35             // oscurecer para que se lea lo de encima
    property var    crop: null            // franjas negras del video: {x,y,w,h,vw,vh} o null
    // No se pudo reproducir la URL (error o no arrancó en 15 s): plan B
    signal failed()

    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool loaded: mp.mediaStatus === MediaPlayer.BufferedMedia
                                   || mp.mediaStatus === MediaPlayer.BufferingMedia
                                   || mp.mediaStatus === MediaPlayer.LoadedMedia
                                   || mp.mediaStatus === MediaPlayer.EndOfMedia
    readonly property bool videoShown: loaded && mp.position > 0
    readonly property bool shouldPlay: active && playing

    // Posición de Spotify en ms (MPRIS la da en segundos)
    function spotifyMs() {
        if (!player)
            return 0
        player.positionChanged()
        return Math.max(0, Math.round(player.position * 1000))
    }

    property bool seeking: false
    property int  pendingSeek: -1
    // Un salto tarda 3–4 s en completarse (MP4 por internet, medido) y la
    // canción sigue avanzando: se salta un poco por delante. El ajuste fino de
    // velocidad corrige el resto.
    readonly property int seekLead: 3500

    function seekTo(ms) {
        mp.playbackRate = 1
        const target = Math.min(ms, Math.max(0, mp.duration - 500))
        if (!mp.seekable) {               // aún no admite saltos: se hace en cuanto pueda
            pendingSeek = target
            return
        }
        pendingSeek = -1
        seeking = true
        mp.position = target
    }

    // Arranque/pausa según la música y la visibilidad
    function applyState() {
        if (!loaded || mp.duration <= 0)
            return
        if (shouldPlay) {
            const target = spotifyMs()
            if (target >= mp.duration - 300) {      // el video es más corto que la canción
                mp.pause()
                return
            }
            if (Math.abs(mp.position - target) > 3000)
                seekTo(target + seekLead)
            if (mp.playbackState !== MediaPlayer.PlayingState)
                mp.play()
        } else if (mp.playbackState === MediaPlayer.PlayingState) {
            if (Math.abs(mp.position - spotifyMs()) > 3000)
                seekTo(spotifyMs())          // el fotograma de la posición actual
            mp.pause()
            mp.playbackRate = 1
        } else if (mp.playbackState === MediaPlayer.StoppedState) {
            // primera carga en pausa: mostrar el fotograma de la posición actual
            seekTo(spotifyMs())
            mp.play()
            mp.pause()
        }
    }

    // Corrección fina: velocidad ±10 % hasta alcanzar a Spotify
    function nudge() {
        // "Buffering" también vale: con video por internet Qt se queda ahí
        // aunque reproduce con normalidad
        if (!shouldPlay || seeking || !loaded || mp.playbackState !== MediaPlayer.PlayingState)
            return
        const drift = mp.position - spotifyMs()           // > 0: el video va adelantado
        if (Math.abs(drift) > 3000)
            seekTo(spotifyMs() + seekLead)
        else if (Math.abs(drift) > 250)
            mp.playbackRate = drift > 0 ? 0.9 : 1.1
        else
            mp.playbackRate = 1
    }

    // ── Portada desenfocada (siempre debajo; se ve mientras no hay video) ────
    Image {
        id: art
        anchors.fill: parent
        source: root.artUrl
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        visible: art.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.25
        brightness: -0.1
    }

    // ── Video ────────────────────────────────────────────────────────────────
    MediaPlayer {
        id: mp
        source: root.videoUrl             // también oculto: precarga
        videoOutput: video
        // sin audioOutput: no suena (el audio es el de Spotify)
        property bool settled: false
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.BufferedMedia)
                root.seeking = false
            // Primera vez que hay datos: sincronizar (salto a la posición de
            // Spotify) y pausar si la ventana está oculta o la música en pausa
            if (root.loaded && !settled) {
                settled = true
                root.applyState()
            }
            if (mediaStatus === MediaPlayer.LoadingMedia || mediaStatus === MediaPlayer.NoMedia)
                settled = false
        }
        onSourceChanged: {
            root.seeking = false
            root.pendingSeek = -1
            playbackRate = 1
            // Qt (backend FFmpeg) no termina de cargar un video por internet
            // hasta que se le da play (medido: ~25 s contra 1–2 s). Se arranca
            // ya; applyState() lo pausa si no toca reproducir.
            if (source.toString() !== "")
                play()
        }
        onErrorOccurred: (error, errorString) => {
            console.warn("danios-music: video:", errorString)
            root.failed()
        }
        onSeekableChanged: if (seekable && root.pendingSeek >= 0) root.seekTo(root.pendingSeek)
        // Si tras un salto ya avanza, el salto terminó (algunos formatos no
        // pasan por "Buffered" de nuevo)
        onPositionChanged: if (root.seeking && playbackState === MediaPlayer.PlayingState) seekDone.restart()
    }

    // Sin franjas: llenar recortando. Con franjas: se amplía el video para que
    // la ZONA ÚTIL (sin las franjas) llene el fondo. En proporciones, así vale
    // igual en 720p que en 1080p.
    Item {
        anchors.fill: parent
        clip: true
        opacity: root.videoShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }

        VideoOutput {
            id: video
            readonly property var c: root.crop
            readonly property real fx: c ? c.x / c.vw : 0
            readonly property real fy: c ? c.y / c.vh : 0
            readonly property real fw: c ? c.w / c.vw : 1
            readonly property real fh: c ? c.h / c.vh : 1
            // tamaño del cuadro completo para que la zona útil cubra el fondo
            readonly property real aspect: c ? c.vw / c.vh : 16 / 9
            readonly property real cover: c ? Math.max(parent.width / (fw * aspect), parent.height / fh) : 1
            width: c ? cover * aspect : parent.width
            height: c ? cover : parent.height
            x: c ? (parent.width - fw * width) / 2 - fx * width : 0
            y: c ? (parent.height - fh * height) / 2 - fy * height : 0
            fillMode: c ? VideoOutput.Stretch : VideoOutput.PreserveAspectCrop
        }
    }

    // Si en 15 s no hay datos, la URL no sirve (p. ej. 403 de YouTube)
    Timer {
        id: loadWatchdog
        interval: 15000
        running: root.videoUrl !== "" && !root.loaded
        onTriggered: root.failed()
    }

    Timer {
        id: seekDone
        interval: 400
        onTriggered: root.seeking = false
    }

    onShouldPlayChanged: applyState()

    // Comprobación de desvío: cada 2 s solo mientras se ve y suena
    Timer {
        interval: 2000
        repeat: true
        running: root.shouldPlay && root.loaded
        onTriggered: root.nudge()
    }

    // ── Oscurecer + viñeta para que se lea lo de encima ─────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.dim)
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 0.7; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }
}
