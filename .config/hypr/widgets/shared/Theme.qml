pragma Singleton
import QtQuick

// Shared theme for all Hyprland widgets (workspaces / corner / window / smart /
// volume …). Dark "Black Metal"-ish base with the SAME cyan→green accent that
// Hyprland uses for the active window border, so the widgets feel coherent with
// the desktop.  Active border in appearance.lua: rgba(33ccff) → rgba(00ff99).
QtObject {
    // ── Accent (matches Hyprland's active border gradient) ──────────────────
    readonly property color accent:  "#33ccff"   // cyan   (gradient start)
    readonly property color accent2: "#00ff99"   // green  (gradient end)
    readonly property color warning: "#e0a06a"   // amber — destructive hints

    // Global corner rounding — 0 = sharp corners, like the rest of Hyprland.
    readonly property int radius: 0
    // Frame border thickness (px) — the bright cyan outline, like the corner.
    readonly property int borderWidth: 2

    // ── Grayscale base (Black Metal) ────────────────────────────────────────
    readonly property color base00: "#000000"
    readonly property color base01: "#111113"
    readonly property color base02: "#1c1c20"
    readonly property color base03: "#2b2b31"
    readonly property color base04: "#8a8a90"
    readonly property color base05: "#d6d6da"
    readonly property color base06: "#9a9aa0"
    readonly property color base07: "#e6e6ea"
    // Accent-carrying slots point at the Hyprland accent
    readonly property color base08: accent        // workspace / primary marker
    readonly property color base09: "#aaaaaa"
    readonly property color base0A: warning        // search/close hints
    readonly property color base0B: accent2        // selection / insert / multi-select
    readonly property color base0C: accent
    readonly property color base0D: accent         // functions / window marker / section
    readonly property color base0E: "#9a9aa0"
    readonly property color base0F: "#444444"

    // ── Surfaces ────────────────────────────────────────────────────────────
    readonly property color surface:          "#000000"   // hard black
    readonly property color surfaceContainer: "#000000"
    readonly property color surfaceDim:       base00
    readonly property color surfaceBright:    base02
    readonly property color surfaceVariant:   base03
    readonly property color outline:          Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    readonly property color outlineVariant:   Qt.rgba(base03.r, base03.g, base03.b, 0.6)

    // ── Grid / cells (workspace grid, legacy) ───────────────────────────────
    readonly property color gridBackground: surface
    readonly property color gridBorder: outline
    readonly property color cellBackground: surfaceContainer
    readonly property color cellBorder: Qt.rgba(base04.r, base04.g, base04.b, 0.20)
    readonly property color cellActiveBackground: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
    readonly property color cellActiveBorder: accent
    readonly property color windowBackground: Qt.rgba(base03.r, base03.g, base03.b, 0.85)
    readonly property color windowBorder: Qt.rgba(base04.r, base04.g, base04.b, 0.30)
    readonly property color bgNumber: base04
    readonly property color cardBackground: surface
    readonly property color cardBorder: outline
    readonly property color activeCircle: accent
    readonly property color inactiveCircle: base02
    readonly property color activeText: base00
    readonly property color inactiveText: base04
    readonly property color activeDot: base05
    readonly property color inactiveDot: base03

    // ── Corner indicator ────────────────────────────────────────────────────
    readonly property color cornerBackground: "#000000"
    readonly property color cornerBorder:     outline
    readonly property color cornerBorderColor: accent      // matches Hyprland border
    readonly property color cornerText:       base05

    // ── Pickers (workspace / window / smart) ────────────────────────────────
    readonly property color pickerBackground: "#000000"
    readonly property color pickerBorder: accent      // bright cyan frame, like the corner
    readonly property color pickerInputBackground: Qt.rgba(1, 1, 1, 0.05)   // subtle lift so inputs/track read on black
    readonly property color pickerInputBorder: Qt.rgba(base04.r, base04.g, base04.b, 0.30)
    readonly property color pickerInputFocusBorder: accent
    readonly property color pickerListBackground: "#000000"
    readonly property color pickerItemSelected: Qt.rgba(accent.r, accent.g, accent.b, 0.20)
    readonly property color pickerItemHover: Qt.rgba(base04.r, base04.g, base04.b, 0.10)
    readonly property color pickerText: base05
    readonly property color pickerSecondaryText: base04
    readonly property color pickerPlaceholder: base04
    readonly property color pickerHintText: Qt.rgba(base04.r, base04.g, base04.b, 0.65)
}
