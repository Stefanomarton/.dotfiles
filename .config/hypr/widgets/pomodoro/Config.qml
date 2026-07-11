pragma Singleton

import QtQuick

QtObject {
    // Timer durations (in minutes)
    readonly property int focusMinutes: 45
    readonly property int shortBreakMinutes: 5
    readonly property int longBreakMinutes: 15
    readonly property int sessionsUntilLongBreak: 4

    // Colors
    readonly property color focusColor: "#FF0000"       // Red
    readonly property color breakColor: "#5f8787"       // Green
    readonly property color pauseColor: "#444444"       // Amber/Yellow

    // Display
    readonly property bool primaryMonitorOnly: true

    // Border styling
    readonly property int borderWidth: 10
    readonly property int cornerRadius: 15

    // Timer display
    readonly property int timerFontSize: 22
    readonly property string timerFontFamily: "JuliaMono"
    readonly property int timerPaddingH: 28
    readonly property int timerPaddingV: 14
    readonly property int timerTopMargin: 12
    readonly property real timerOpacity: 0.95

    // Song display
    readonly property bool songNotchEnabled: false
    readonly property int songFontSize: 18
    readonly property int songPaddingH: 44
    readonly property int songPaddingV: 20
    readonly property int songMaxWidth: 700

    // Animations
    readonly property int colorTransitionMs: 200

    // Fluid border animation
    readonly property bool fluidBorderAnimation: true
    readonly property int fluidAnimationDurationMs: 4000  // one full shimmer cycle
    readonly property real fluidMinBrightness: 0.3        // 0.0 = full mix, 1.0 = no change
    readonly property color focusMixColor: "#3d0000"
    readonly property color breakMixColor: "#003d15"
    readonly property color pauseMixColor: "#3d3300"

    // Notifications
    readonly property bool notificationsEnabled: false
    readonly property int notificationDurationMs: 5000

    // Sounds (absolute file paths, empty = disabled)
    // Command used to play sounds, e.g. "paplay", "aplay", "mpv --no-video"
    readonly property string soundCommand: "mpv --no-video --audio-buffer=0"
    readonly property string focusStartSound: "/home/sm/projects/pomodoro-widget/sounds/muniz.mp3"
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
