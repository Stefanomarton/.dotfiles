pragma Singleton
import QtQuick

QtObject {
    // Popup and badge on the main screen: the first of these that is connected (name or model),
    // otherwise the first screen. G9 on the desktop and on a docked laptop, else the laptop panel.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]
    readonly property int popupTimeout: 2500   // ms
    readonly property int popupWidth: 560
    readonly property int popupHeight: 116

    // Badge shown while recording, top center
    readonly property int badgeMargin: Theme.gap      // offset from the top edge
    readonly property int badgeFontSize: Theme.fontSize

    readonly property color recColor: Theme.danger   // the red dot
    readonly property int pollInterval: 1000      // ms between systemd state checks
}
