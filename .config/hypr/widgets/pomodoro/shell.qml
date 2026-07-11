import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property string currentSong: ""

    Process {
        id: playerctlProcess
        command: ["sh", "-c", "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo"]
        stdout: SplitParser {
            onRead: data => root.currentSong = data.trim()
        }
    }

    Timer {
        interval: 3000
        running: Config.songNotchEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!playerctlProcess.running)
                playerctlProcess.running = true
        }
    }

    GlobalShortcut {
        name: "pomodoro-start"
        description: "Start Pomodoro timer"
        onPressed: PomodoroState.start()
    }

    GlobalShortcut {
        name: "pomodoro-pause"
        description: "Pause/Resume Pomodoro timer"
        onPressed: PomodoroState.togglePause()
    }

    GlobalShortcut {
        name: "pomodoro-stop"
        description: "Stop Pomodoro timer"
        onPressed: PomodoroState.stop()
    }

    GlobalShortcut {
        name: "pomodoro-skip"
        description: "Skip to next phase"
        onPressed: PomodoroState.skip()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: borderOverlay

            property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pomodoro-border"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}

            visible: PomodoroState.running && (!Config.primaryMonitorOnly || modelData === Quickshell.screens[0])

            // Hidden text to measure timer width
            Text {
                id: timerTextMeasure
                visible: false
                text: PomodoroState.timeDisplay
                font {
                    pixelSize: Config.timerFontSize
                    bold: true
                    family: Config.timerFontFamily
                }
            }

            // Hidden text to measure song width
            Text {
                id: songTextMeasure
                visible: false
                text: root.currentSong
                font {
                    pixelSize: Config.songFontSize
                    family: Config.timerFontFamily
                }
            }

            Canvas {
                id: borderCanvas
                anchors.fill: parent

                property color borderColor: PomodoroState.currentColor
                property int bw: Config.borderWidth
                property int r: Config.cornerRadius
                property real notchWidth: timerTextMeasure.width + Config.timerPaddingH
                property real notchHeight: timerTextMeasure.height + Config.timerPaddingV
                property real notchRadius: notchHeight / 2

                property real songNotchW: Config.songNotchEnabled && root.currentSong !== ""
                    ? Math.min(songTextMeasure.width + Config.songPaddingH, Config.songMaxWidth)
                    : 0
                property real songNotchH: Config.songNotchEnabled && root.currentSong !== ""
                    ? songTextMeasure.height + Config.songPaddingV
                    : 0
                property real songNotchR: songNotchH / 2

                property real fluidPhase: 0

                NumberAnimation on fluidPhase {
                    running: Config.fluidBorderAnimation
                    from: 0
                    to: 1
                    duration: Config.fluidAnimationDurationMs
                    loops: Animation.Infinite
                }

                Behavior on borderColor {
                    ColorAnimation { duration: Config.colorTransitionMs }
                }

                onBorderColorChanged: requestPaint()
                onFluidPhaseChanged: if (Config.fluidBorderAnimation) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onNotchWidthChanged: requestPaint()
                onSongNotchWChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var w = width
                    var h = height
                    var bw = borderCanvas.bw
                    var r = borderCanvas.r
                    var nw = notchWidth
                    var nh = notchHeight
                    var nr = notchRadius

                    var centerX = w / 2
                    var notchLeft = centerX - nw / 2
                    var notchRight = centerX + nw / 2

                    if (Config.fluidBorderAnimation) {
                        var fp = borderCanvas.fluidPhase
                        // Smooth sine pulse: 0 → 1 → 0 per cycle
                        var t = 0.5 - 0.5 * Math.cos(fp * 2 * Math.PI)
                        var bc = borderColor
                        var mc = PomodoroState.isPaused ? Config.pauseMixColor
                               : PomodoroState.isBreak  ? Config.breakMixColor
                               :                          Config.focusMixColor
                        var blend = t * (1 - Config.fluidMinBrightness)
                        ctx.fillStyle = Qt.rgba(
                            bc.r + (mc.r - bc.r) * blend,
                            bc.g + (mc.g - bc.g) * blend,
                            bc.b + (mc.b - bc.b) * blend,
                            bc.a)
                    } else {
                        ctx.fillStyle = borderColor
                    }

                    // Top edge left of notch
                    ctx.fillRect(r, 0, notchLeft - nr - r, bw)

                    // Top edge right of notch
                    ctx.fillRect(notchRight + nr, 0, w - r - notchRight - nr, bw)

                    // Notch shape
                    ctx.beginPath()
                    ctx.moveTo(notchLeft - nr, 0)
                    ctx.lineTo(notchLeft - nr, bw)
                    // Left curve down into notch
                    ctx.quadraticCurveTo(notchLeft, bw, notchLeft, bw + nr)
                    ctx.lineTo(notchLeft, nh - nr)
                    // Bottom left corner of notch
                    ctx.quadraticCurveTo(notchLeft, nh, notchLeft + nr, nh)
                    ctx.lineTo(notchRight - nr, nh)
                    // Bottom right corner of notch
                    ctx.quadraticCurveTo(notchRight, nh, notchRight, nh - nr)
                    ctx.lineTo(notchRight, bw + nr)
                    // Right curve up from notch
                    ctx.quadraticCurveTo(notchRight, bw, notchRight + nr, bw)
                    ctx.lineTo(notchRight + nr, 0)
                    ctx.closePath()
                    ctx.fill()

                    // Bottom edge (with optional song notch)
                    var snw = borderCanvas.songNotchW
                    var snh = borderCanvas.songNotchH
                    var snr = borderCanvas.songNotchR

                    if (snw > 0) {
                        var sLeft = centerX - snw / 2
                        var sRight = centerX + snw / 2

                        ctx.fillRect(r, h - bw, sLeft - snr - r, bw)
                        ctx.fillRect(sRight + snr, h - bw, w - r - sRight - snr, bw)

                        ctx.beginPath()
                        ctx.moveTo(sLeft - snr, h)
                        ctx.lineTo(sLeft - snr, h - bw)
                        ctx.quadraticCurveTo(sLeft, h - bw, sLeft, h - bw - snr)
                        ctx.lineTo(sLeft, h - snh + snr)
                        ctx.quadraticCurveTo(sLeft, h - snh, sLeft + snr, h - snh)
                        ctx.lineTo(sRight - snr, h - snh)
                        ctx.quadraticCurveTo(sRight, h - snh, sRight, h - snh + snr)
                        ctx.lineTo(sRight, h - bw - snr)
                        ctx.quadraticCurveTo(sRight, h - bw, sRight + snr, h - bw)
                        ctx.lineTo(sRight + snr, h)
                        ctx.closePath()
                        ctx.fill()
                    } else {
                        ctx.fillRect(r, h - bw, w - 2 * r, bw)
                    }

                    // Left edge
                    ctx.fillRect(0, r, bw, h - 2 * r)

                    // Right edge
                    ctx.fillRect(w - bw, r, bw, h - 2 * r)

                    // Top-left corner
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(r, 0)
                    ctx.lineTo(r, bw)
                    ctx.arcTo(bw, bw, bw, r, r - bw)
                    ctx.lineTo(bw, r)
                    ctx.lineTo(0, r)
                    ctx.closePath()
                    ctx.fill()

                    // Top-right corner
                    ctx.beginPath()
                    ctx.moveTo(w, 0)
                    ctx.lineTo(w - r, 0)
                    ctx.lineTo(w - r, bw)
                    ctx.arcTo(w - bw, bw, w - bw, r, r - bw)
                    ctx.lineTo(w - bw, r)
                    ctx.lineTo(w, r)
                    ctx.closePath()
                    ctx.fill()

                    // Bottom-left corner
                    ctx.beginPath()
                    ctx.moveTo(0, h)
                    ctx.lineTo(r, h)
                    ctx.lineTo(r, h - bw)
                    ctx.arcTo(bw, h - bw, bw, h - r, r - bw)
                    ctx.lineTo(bw, h - r)
                    ctx.lineTo(0, h - r)
                    ctx.closePath()
                    ctx.fill()

                    // Bottom-right corner
                    ctx.beginPath()
                    ctx.moveTo(w, h)
                    ctx.lineTo(w - r, h)
                    ctx.lineTo(w - r, h - bw)
                    ctx.arcTo(w - bw, h - bw, w - bw, h - r, r - bw)
                    ctx.lineTo(w - bw, h - r)
                    ctx.lineTo(w, h - r)
                    ctx.closePath()
                    ctx.fill()

                }
            }

            // Timer text inside the notch
            Text {
                id: timerText
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Config.timerPaddingV / 2
                }
                text: PomodoroState.timeDisplay
                color: "white"
                font {
                    pixelSize: Config.timerFontSize
                    bold: true
                    family: Config.timerFontFamily
                }
            }

            // Song text inside the bottom notch
            Text {
                id: songText
                visible: Config.songNotchEnabled && root.currentSong !== ""
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: Config.songPaddingV / 2
                }
                text: root.currentSong
                color: "white"
                width: Config.songMaxWidth - Config.songPaddingH
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font {
                    pixelSize: Config.songFontSize
                    family: Config.timerFontFamily
                }
            }

            // On-screen message overlay — pill centered on screen
            Rectangle {
                id: messageOverlay
                anchors.centerIn: parent
                width: overlayText.width + Config.timerPaddingH
                height: overlayText.height + Config.timerPaddingV
                radius: height / 2
                color: PomodoroState.currentColor
                opacity: 0
                visible: opacity > 0

                Text {
                    id: overlayText
                    anchors.centerIn: parent
                    color: "white"
                    font {
                        pixelSize: Config.timerFontSize
                        bold: true
                        family: Config.timerFontFamily
                    }
                }

                SequentialAnimation {
                    id: messageAnim
                    NumberAnimation { target: messageOverlay; property: "opacity"; to: 1; duration: 200 }
                    PauseAnimation { duration: Config.messageDurationMs }
                    NumberAnimation { target: messageOverlay; property: "opacity"; to: 0; duration: 600 }
                }
            }

            Connections {
                target: PomodoroState
                function onShowMessage(text) {
                    overlayText.text = text
                    messageAnim.restart()
                }
            }
        }
    }
}
