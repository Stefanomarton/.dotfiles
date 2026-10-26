pragma Singleton
import QtQuick

QtObject {
    // Badge on the main screen: the first of these that is connected (name or model),
    // otherwise the first screen. G9 on the desktop and on a docked laptop, else the laptop panel.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]

    // Badge while a timer of Tasks runs, top left
    readonly property int badgeMargin: Theme.gap      // offset from the top and left edges
    readonly property int badgeFontSize: Theme.fontSize
    readonly property int titleMax: 420               // px of the title, then …
    readonly property color dotColor: Theme.ok

    // How often the server is asked (a timer started on the phone or the web shows up within this)
    readonly property int pollInterval: 30000         // ms
}
