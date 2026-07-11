pragma Singleton
import QtQuick

QtObject {
    // Corner indicator (workspace name badge)
    readonly property bool   showCorner:          true
    readonly property string cornerPositionH:     "right"  // "left", "center", "right"
    readonly property string cornerPositionV:     "top"    // "top", "center", "bottom"
    readonly property int    cornerMinWidth:      230      // minimum width (px)
    readonly property int    cornerMinHeight:     120      // minimum height (px)
    readonly property int    cornerMaxWidth:      720      // maximum width (px)
    readonly property int    cornerPaddingH:      28       // horizontal padding
    readonly property int    cornerPaddingV:      18       // vertical padding
    readonly property int    cornerRadius:        Theme.radius  // from shared Theme (0 = square)
    readonly property int    cornerMargin:        50       // offset from screen edges
    readonly property int    cornerFontSize:      56
    // "all" = every monitor, or a specific connector name e.g. "DP-1"
    readonly property string cornerMonitor:       "all"
    // Fade the badge out while the cursor is over it (so you can see under it).
    // The badge is always click-through; this just controls the hover fade,
    // which is driven by polling the cursor position.
    readonly property bool   cornerHoverFade:     true
}
