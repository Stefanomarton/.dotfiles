pragma Singleton
import Quickshell
import QtQuick

QtObject {
    // Main screen: the first of these that is connected (name or model), otherwise the first
    // screen. G9 on the desktop and on a docked laptop, else the laptop panel; never the Xiaomi.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]

    // Timer durations (in minutes)
    readonly property int focusMinutes: 45
    readonly property int shortBreakMinutes: 5
    readonly property int longBreakMinutes: 15
    readonly property int sessionsUntilLongBreak: 4

    // Colors come from the shared Theme.qml (~/.local/bin/theme)
    readonly property color focusColor: Theme.danger
    readonly property color breakColor: Theme.ok
    readonly property color pauseColor: Theme.warning

    // Screen frame
    readonly property int borderWidth: 4
    readonly property int cornerRadius: Theme.radius

    // Timer in the notch at the top
    readonly property int timerFontSize: Math.round(Theme.fontSize * Theme.textScale)
    readonly property int timerPaddingH: 28
    readonly property int timerPaddingV: 12

    // Song display
    readonly property bool songNotchEnabled: false
    readonly property int songFontSize: Math.round(Theme.fontSmall * Theme.textScale)
    readonly property int songPaddingH: 44
    readonly property int songPaddingV: 16
    readonly property int songMaxWidth: 700

    readonly property int colorTransitionMs: 200

    // Notifications
    readonly property bool notificationsEnabled: false
    readonly property int notificationDurationMs: 5000

    // Sounds (absolute file paths, empty = disabled)
    // Command used to play sounds, e.g. "paplay", "aplay", "mpv --no-video"
    readonly property string soundCommand: "mpv --no-video --audio-buffer=0"
    readonly property string focusStartSound: Quickshell.shellDir + "/sounds/muniz.mp3"
    readonly property string pauseSound: ""
    readonly property string breakSound: ""
    readonly property string intervalSound: ""

    // On-screen messages (empty = disabled)
    readonly property string focusStartMessage: "Non ti distrarre ti taglio la gola"
    readonly property string pauseMessage: "Metti in pausa perchè hai la frocite?"
    readonly property string breakMessage: "Riposati ma non troppo"
    readonly property string intervalMessage: "Sgobba"

    // Message display duration (ms)
    readonly property int messageDurationMs: 3000

    // Interval reminder during focus
    readonly property bool intervalEnabled: false
    readonly property int intervalMinutes: 15
}
