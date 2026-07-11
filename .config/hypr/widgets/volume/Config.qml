pragma Singleton
import QtQuick

QtObject {
    // Which monitor to show the OSD on: "focused" or a monitor name (e.g. "DP-1")
    readonly property string osdMonitor: "focused"

    readonly property int osdTimeout: 1500   // ms the OSD stays after a change
    readonly property int osdWidth: 480
    readonly property int osdHeight: 116
    readonly property int osdRadius: Theme.radius
    // Nudge from the exact screen center (px). 0,0 = dead center.
    readonly property int osdOffsetX: 0
    readonly property int osdOffsetY: 0

    // Colors come from the shared Theme.qml (Hyprland cyan→green accent).
}
