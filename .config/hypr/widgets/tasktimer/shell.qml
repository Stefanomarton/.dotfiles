import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// The timer of Tasks (tasks.marton.dev) — a badge top left while one runs: «● titolo 0:42» (m:ss), wherever it was started
// (here, the web, the phone). Super+Shift+O then s: pick a task (rofi) and start it; x or a click on the badge: stop.
// Everything goes through tasks-cli (the tasks flake, cli/tasks-cli). Run with: qs -p .
ShellRoot {
    id: root

    property string taskId: ""
    property string title: ""
    property real startTs: 0           // unix seconds the timer started
    property real now: Date.now() / 1000
    readonly property bool running: taskId !== ""
    readonly property int elapsed: running ? Math.max(0, now - startTs) : 0

    readonly property var mainScreen: {
        for (var i = 0; i < Config.monitors.length; i++) {
            var want = Config.monitors[i]
            var s = Quickshell.screens.find(function(x) { return x.name === want || x.model === want })
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    // m:ss, h:mm:ss from the hour: the seconds tick, so a running timer is seen running
    function fmt(s) {
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60
        var mm = h > 0 && m < 10 ? "0" + m : "" + m
        return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec
    }
    function refresh() { if (!statusProc.running) statusProc.running = true }

    // tasks-cli status --json: {id, title, timer} or an empty line; on an error (offline, vault locked) the last state stays
    Process {
        id: statusProc
        command: ["tasks-cli", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t === "") { root.taskId = ""; return }
                try {
                    var r = JSON.parse(t)
                    root.taskId = r.id
                    root.title = r.title
                    root.startTs = Date.parse(r.timer.replace(" ", "T")) / 1000
                } catch (e) { console.warn("tasktimer: " + t) }
            }
        }
    }
    Timer { id: pollTimer; interval: Config.pollInterval; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { interval: 1000; running: root.running; repeat: true; onTriggered: root.now = Date.now() / 1000 }

    // the picker and the stop, then the badge asked again; a failure is a notification (the script's)
    Process { id: pickProc; command: [Quickshell.shellDir + "/pick.sh"]; onExited: root.refresh() }
    Process { id: stopProc; command: ["sh", "-c", "out=$(tasks-cli stop 2>&1) || notify-send -a Tasks 'Timer non fermato' \"$out\""]; onExited: root.refresh() }

    GlobalShortcut { name: "tasktimer-start"; description: "Pick a task and start its timer"; onPressed: if (!pickProc.running) pickProc.running = true }
    GlobalShortcut { name: "tasktimer-stop"; description: "Stop the timer of Tasks"; onPressed: if (!stopProc.running) stopProc.running = true }
    GlobalShortcut { name: "tasktimer-refresh"; description: "Ask the server for the running timer"; onPressed: root.refresh() }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.running && modelData === root.mainScreen

            anchors.top: true
            anchors.left: true
            margins.top: Config.badgeMargin
            margins.left: Config.badgeMargin
            implicitWidth: badgeRow.implicitWidth + 36
            implicitHeight: badgeRow.implicitHeight + 18
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "tasktimer-badge"
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
                        color: Config.dotColor
                        SequentialAnimation on opacity {
                            running: root.running; loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1200 }
                            NumberAnimation { to: 1; duration: 1200 }
                        }
                    }
                    Text {
                        text: root.title
                        color: Theme.pickerText
                        elide: Text.ElideRight
                        Layout.maximumWidth: Config.titleMax
                        font.pixelSize: Math.round(Config.badgeFontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                    }
                    Text {
                        text: root.fmt(root.elapsed)
                        color: Theme.pickerText
                        font.pixelSize: Math.round(Config.badgeFontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!stopProc.running) stopProc.running = true }
            }
        }
    }
}
