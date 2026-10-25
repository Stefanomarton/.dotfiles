import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Volume OSD — a small centered popup that appears when the volume changes.
// Reacts to any Pipewire volume/mute change (e.g. the wpctl volume keybinds).
// Run with: qs -p .
ShellRoot {
    id: root

    // Keep the default sink's audio properties live.
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool isMuted: (sink && sink.audio) ? sink.audio.muted : false

    // Ignore the initial values that arrive as Pipewire connects at startup.
    property bool ready: false
    Timer { interval: 800; running: true; repeat: false; onTriggered: root.ready = true }

    onVolumeChanged: if (root.ready) osd.trigger()
    onIsMutedChanged: if (root.ready) osd.trigger()

    PanelWindow {
        id: osd

        screen: {
            // the first of Config.monitors that is connected, otherwise the first screen
            for (var i = 0; i < Config.monitors.length; i++) {
                var want = Config.monitors[i]
                var s = Quickshell.screens.find(function(x) { return x.name === want || x.model === want })
                if (s) return s
            }
            return Quickshell.screens[0]
        }

        // Fullscreen transparent overlay; the card is centered inside it.
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "volume-osd"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}   // fully click-through — never steals input

        // 0 = hidden, 1 = shown (drives fade + pop). Window is only mapped while > 0.
        property real shown: 0
        Behavior on shown { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        visible: shown > 0.01

        Timer { id: hideTimer; interval: Config.osdTimeout; onTriggered: osd.shown = 0 }
        function trigger() { osd.shown = 1; hideTimer.restart() }

        Rectangle {
            id: card
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Config.osdOffsetX
            anchors.verticalCenterOffset: Config.osdOffsetY
            width: Math.round(Config.osdWidth * Theme.textScale)
            height: Math.round(Config.osdHeight * Theme.textScale)
            radius: Config.osdRadius
            color: Theme.pickerBackground
            border.color: Theme.outline
            border.width: Theme.borderWidth

            opacity: osd.shown
            scale: 0.94 + 0.06 * osd.shown

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.pad

                // Hand-drawn speaker (theme-independent); waves reflect the level.
                Canvas {
                    id: spk
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    property real vol: Math.max(0, Math.min(1, root.volume))
                    property bool mut: root.isMuted
                    property color col: mut ? Theme.warning : Theme.pickerText
                    onVolChanged: requestPaint()
                    onMutChanged: requestPaint()
                    onColChanged: requestPaint()
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        var s = width / 30
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = col
                        ctx.strokeStyle = col
                        ctx.lineWidth = 2 * s
                        ctx.lineCap = "round"
                        // speaker body: box + cone
                        ctx.beginPath()
                        ctx.moveTo(3 * s, 11 * s)
                        ctx.lineTo(9 * s, 11 * s)
                        ctx.lineTo(16 * s, 5 * s)
                        ctx.lineTo(16 * s, 25 * s)
                        ctx.lineTo(9 * s, 19 * s)
                        ctx.lineTo(3 * s, 19 * s)
                        ctx.closePath()
                        ctx.fill()
                        if (mut) {
                            ctx.beginPath(); ctx.moveTo(20 * s, 9 * s);  ctx.lineTo(28 * s, 21 * s); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(28 * s, 9 * s);  ctx.lineTo(20 * s, 21 * s); ctx.stroke()
                        } else {
                            var cx = 16 * s, cy = 15 * s
                            if (vol > 0.001) { ctx.beginPath(); ctx.arc(cx, cy, 5 * s,  -Math.PI/4, Math.PI/4); ctx.stroke() }
                            if (vol > 0.34)  { ctx.beginPath(); ctx.arc(cx, cy, 9 * s,  -Math.PI/4, Math.PI/4); ctx.stroke() }
                            if (vol > 0.67)  { ctx.beginPath(); ctx.arc(cx, cy, 13 * s, -Math.PI/4, Math.PI/4); ctx.stroke() }
                        }
                    }
                }

                // Volume bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: Theme.radius
                    color: Theme.pickerInputBackground

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, root.volume))
                        radius: parent.radius
                        // accent → accent2 of the theme
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.isMuted ? Theme.warning : Theme.accent }
                            GradientStop { position: 1.0; color: root.isMuted ? Theme.warning : Theme.accent2 }
                        }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    Layout.preferredWidth: 76
                    horizontalAlignment: Text.AlignRight
                    text: root.isMuted ? "muted" : (Math.round(root.volume * 100) + "%")
                    color: root.isMuted ? Theme.warning : Theme.pickerText
                    font.pixelSize: Math.round((root.isMuted ? Theme.fontSize : Theme.fontLarge) * Theme.textScale)
                    font.family: Theme.fontFamily
                    font.bold: true
                }
            }
        }
    }
}
