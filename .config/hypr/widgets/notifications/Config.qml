pragma Singleton
import QtQuick

QtObject {
    // Main screen for popups and history: the first of these that is connected (name or model),
    // otherwise the first screen. G9 on the desktop and on a docked laptop, else the laptop panel.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]

    readonly property int topMargin: Theme.edge      // popups: top center, this far from the edge
    readonly property int width: 800
    readonly property int maxVisible: 3      // the others wait below a "+N" line
    readonly property int spacing: Theme.gap
    readonly property int fontSize: Theme.fontSize
    readonly property int iconSize: 64
    readonly property int bodyLines: 4

    // ms on screen when the app doesn't ask for its own timeout; 0 = until closed
    readonly property int timeoutLow: 3000
    readonly property int timeoutNormal: 8000
    readonly property int timeoutCritical: 0
    readonly property int idleSeconds: 120   // away from the PC: popups don't expire
    readonly property int historyLength: 100

    // Do not disturb (Super+D): popups go straight to history; a moon stays in the corner
    readonly property bool dndAllowCritical: true   // critical ones (Claude waiting, calls) still show
    readonly property string dndCorner: "top-left"  // "top-left", "top-right", "bottom-left", "bottom-right"
    readonly property int dndMargin: Theme.pad
    readonly property int dndSize: 34                // moon diameter (px)

    // Rules (were dunst's): "hide" = history only, "critical" = stays until closed, "" = as sent.
    function rule(n) {
        // Claude Code waiting for an answer
        if (n.appName === "kitty" && n.body.indexOf("needs your input") >= 0) return "critical"
        // Phone (KDE Connect): history only, except calls and messages
        if (/connect/i.test(n.appName) && !/call|hiamat|^messag|SMS/i.test(n.summary)) return "hide"
        return ""
    }
}
