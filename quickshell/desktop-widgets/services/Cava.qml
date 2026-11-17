// Espectro de audio con el programa `cava` (estéreo), en un proceso aparte.
//
// Solo corre mientras `active` (música sonando y widget visible): en pausa no
// hay proceso ni costo. La configuración se pasa por sustitución de procesos
// (sin archivos temporales); si cambia, cava se reinicia.
//
// `values`: 0..1 por barra. En estéreo cava entrega [izquierdo invertido,
// derecho] → graves en el centro, simétrico.
import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool active: false
    property int  bars: 32
    property int  framerate: 30
    property bool stereo: true
    property int  sensitivity: 100     // %
    property int  smoothing: 77        // noise_reduction de cava (0..100)

    readonly property int barCount: stereo ? Math.max(2, bars - bars % 2) : Math.max(1, bars)
    property var values: zeros(barCount)

    function zeros(n) {
        return new Array(n).fill(0)
    }

    readonly property string config: [
        "[general]",
        "bars = " + barCount,
        "framerate = " + framerate,
        "autosens = 1",
        "sensitivity = " + sensitivity,
        "[input]",
        "method = pipewire",
        "source = auto",
        "[output]",
        "method = raw",
        "channels = " + (stereo ? "stereo" : "mono"),
        "mono_option = average",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = 1000",
        "bar_delimiter = 59",
        "frame_delimiter = 10",
        "[smoothing]",
        "noise_reduction = " + smoothing
    ].join("\n")

    // Reinicio corto cuando cambia la configuración
    property bool restarting: false
    onConfigChanged: {
        restarting = true
        restartTimer.restart()
    }
    Timer {
        id: restartTimer
        interval: 200
        onTriggered: root.restarting = false
    }

    property string lastLine: ""

    Process {
        id: proc
        running: root.active && !root.restarting
        command: ["bash", "-c", "exec cava -p <(printf '%s\\n' \"$1\")", "cava", root.config]

        stdout: SplitParser {
            onRead: line => {
                if (line === root.lastLine)      // silencio: no repintar
                    return
                root.lastLine = line
                const parts = line.split(";")
                const n = root.barCount
                const out = new Array(n)
                for (let i = 0; i < n; ++i)
                    out[i] = Math.min(1, (parseInt(parts[i]) || 0) / 1000)
                root.values = out
            }
        }

        onRunningChanged: if (!running) {
            root.lastLine = ""
            root.values = root.zeros(root.barCount)
        }
    }

    onBarCountChanged: values = zeros(barCount)
}
