pragma Singleton
import QtQuick

QtObject {
    // Main screen: the first of these that is connected (name or model), otherwise the first
    // screen. G9 on the desktop and on a docked laptop, else the laptop panel; never the Xiaomi.
    readonly property var monitors: ["Odyssey G91F", "eDP-1"]

    readonly property int osdTimeout: 1500   // ms the OSD stays after a change
    readonly property int osdWidth: 480
    readonly property int osdHeight: 92
    readonly property int osdRadius: Theme.radius
    // Nudge from the exact screen center (px). 0,0 = dead center.
    readonly property int osdOffsetX: 0
    readonly property int osdOffsetY: 0

    // Colors come from the shared Theme.qml (~/.local/bin/theme).
}
