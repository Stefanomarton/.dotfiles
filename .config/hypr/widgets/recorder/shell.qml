import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Call recorder — badge + start/stop popup for `meet-rec toggle` (Super+Shift+R).
// The recording runs as the systemd user service "meet-rec", so it survives a
// reload of this widget; here we only poll its state and show it.
// Run with: qs -p .
ShellRoot {
    id: root

    readonly property string recCmd: Quickshell.env("HOME") + "/.local/bin/meet-rec"

    property string state: ""          // systemd ActiveState of meet-rec
    property real startTs: 0           // unix seconds the recording started
    property real now: Date.now() / 1000
    property string mic: ""
    property string file: ""
    readonly property bool recording: state === "active" || state === "deactivating"
    readonly property int elapsed: recording ? Math.max(0, now - startTs) : 0

    function fmt(s) {
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, x = s % 60
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (x < 10 ? "0" : "") + x
    }
    function toggle() { toggleProc.running = true; pollTimer.restart() }

    readonly property var mainScreen: {
        for (var i = 0; i < Config.monitors.length; i++) {
            var want = Config.monitors[i]
            var s = Quickshell.screens.find(function(x) { return x.name === want || x.model === want })
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    // ── systemd state ────────────────────────────────────────────────────────
    Process {
        id: pollProc
        command: ["systemctl", "--user", "show", "meet-rec", "--timestamp=unix",
                  "-p", "ActiveState", "-p", "ActiveEnterTimestamp"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = {}
                text.split("\n").forEach(function(l) {
                    var i = l.indexOf("="); if (i > 0) p[l.substring(0, i)] = l.substring(i + 1)
                })
                var ts = parseFloat((p.ActiveEnterTimestamp || "").replace("@", ""))
                if (!isNaN(ts)) root.startTs = ts
                root.setState(p.ActiveState || "inactive")
            }
        }
    }
    Timer {
        id: pollTimer
        interval: Config.pollInterval; repeat: true; running: true; triggeredOnStart: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
    Timer {
        interval: 1000; repeat: true; running: root.recording
        onTriggered: root.now = Date.now() / 1000
    }

    property bool ready: false   // no popup for the state found at startup
    property int lastElapsed: 0
    function setState(s) {
        var prev = state
        if (s === prev) return
        if (recording) lastElapsed = elapsed
        state = s
        now = Date.now() / 1000
        if (s === "active") { mic = ""; infoTimer.restart() }
        if (!ready) { ready = true; return }
        if (s === "active") pendingStart = true
        else if (s === "failed") popup.show("error")
        else if (s === "inactive" && (prev === "active" || prev === "deactivating")) popup.show("stop")
    }

    // Mic and file name, printed by meet-rec at start ("Microfono: …", "File: …");
    // retried until they show up, then the start popup can name the mic.
    property bool pendingStart: false
    Timer {
        id: infoTimer
        interval: 400
        onTriggered: if (!infoProc.running) infoProc.running = true
    }
    Process {
        id: infoProc
        command: ["journalctl", "--user", "-u", "meet-rec", "-o", "cat", "--since", "@" + Math.floor(root.startTs)]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(function(l) {
                    if (l.startsWith("Microfono: ")) root.mic = l.substring(11).replace(/ \([^)]*\)$/, "")
                    if (l.startsWith("File: ")) root.file = l.substring(6)
                })
                if (root.mic === "" && root.recording) { infoTimer.restart(); return }
                if (root.pendingStart) { root.pendingStart = false; popup.show("start") }
            }
        }
    }
    Process { id: toggleProc; command: [root.recCmd, "toggle"] }

    // ── Badge while recording, on the main screen (click to stop) ──────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.recording && modelData === root.mainScreen

            anchors.top: true
            margins.top: Config.badgeMargin
            implicitWidth: badgeRow.implicitWidth + 36
            implicitHeight: badgeRow.implicitHeight + 18
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "recorder-badge"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.pickerBackground
                border.color: Theme.outline
                border.width: Theme.borderWidth

                RowLayout {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        color: Config.recColor
                        SequentialAnimation on opacity {
                            running: root.recording; loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                    Text {
                        text: (root.state === "deactivating" ? "chiusura… " : "REC ") + root.fmt(root.elapsed)
                        color: Theme.pickerText
                        font.pixelSize: Math.round((Config.badgeFontSize) * Theme.textScale)
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggle() }
            }
        }
    }

    // ── Start/stop popup (centered, click-through, like the volume OSD) ─────
    PanelWindow {
        id: popup
        property string kind: "start"   // start | stop | error

        screen: root.mainScreen

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "recorder-popup"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}

        property real shown: 0
        Behavior on shown { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        visible: shown > 0.01

        Timer { id: hideTimer; interval: Config.popupTimeout; onTriggered: popup.shown = 0 }
        function show(k) { kind = k; shown = 1; hideTimer.restart() }

        readonly property bool defaultMic: root.mic.startsWith("predefinito")
        readonly property color tint: kind === "error" ? Theme.warning
                                    : kind === "stop" ? Theme.ok : Config.recColor

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(Config.popupWidth * Theme.textScale)
            height: Math.round(Config.popupHeight * Theme.textScale)
            radius: Theme.radius
            color: Theme.pickerBackground
            border.color: popup.kind === "error" ? Theme.warning : Theme.outline
            border.width: Theme.borderWidth
            opacity: popup.shown
            scale: 0.94 + 0.06 * popup.shown

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pad
                anchors.rightMargin: Theme.pad
                spacing: Theme.pad

                // ● recording, ■ saved, ! error
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: popup.kind === "start" ? 17 : 0
                    color: popup.kind === "error" ? "transparent" : popup.tint
                    Text {
                        anchors.centerIn: parent
                        visible: popup.kind === "error"
                        text: "!"; color: popup.tint; font.pixelSize: Math.round(34 * Theme.textScale); font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: popup.kind === "start" ? "Registrazione avviata"
                            : popup.kind === "stop" ? "Salvata · " + root.fmt(root.lastElapsed)
                            : "Registrazione interrotta"
                        color: Theme.pickerText
                        font.pixelSize: Math.round(Theme.fontLarge * Theme.textScale)
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: popup.kind === "start" ? "Mic: " + root.mic
                            : popup.kind === "stop" ? root.file.replace(/^.*\//, "")
                            : "journalctl --user -u meet-rec"
                        color: popup.kind === "start" && popup.defaultMic ? Theme.warning : Theme.pickerSecondaryText
                        font.pixelSize: Math.round(Theme.fontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
