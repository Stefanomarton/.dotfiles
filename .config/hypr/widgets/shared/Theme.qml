pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Shared theme for all Hyprland widgets (workspaces / corner / volume / notifications /
// recorder / whichkey / pomodoro). Colours come from ~/.local/state/theme/theme.json,
// written by ~/.local/bin/theme (chiaro / scuro / nero), and change live when
// the theme changes. The defaults below are "nero", for when the file is not there yet.
// An accent frame means "this has the keyboard", window or widget alike.
QtObject {
    id: theme

    property FileView file: FileView {
        path: Quickshell.env("HOME") + "/.local/state/theme/theme.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: t
            property color bg: "#000000"         // widget / popup surface
            property color surface: "#0d0d0d"    // inputs, hover
            property color rule: "#1f1f1f"       // 1px lines
            property color ink: "#f2f2f2"        // text
            property color ink2: "#d6d8db"
            property color ink3: "#a3a6ab"       // secondary text
            property color accent: "#7a9bf5"
            property color accent2: "#97b1f7"    // hover / second highlight
            property color soft: "#121a2e"       // selected row
            property color frame: "#3e4e7b"      // frame of the panels with the keyboard: accent toned down
            property color accentText: "#0a0f1c"   // text on an accent fill
            property color ok: "#4cc38a"
            property color warn: "#e6b071"
            property color danger: "#e5675e"
            property int radius: 4
            property int border: 1
            property real dim: 0.45
        }
    }

    // ── Type ────────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JuliaMono"   // one face everywhere, like the terminal and Emacs
    // Every text size is multiplied by this. Larger on the G9 (desktop, or a docked laptop),
    // where the widgets show whenever it is connected; 1 on the laptop panel.
    readonly property real textScale: Quickshell.screens.some(function(s) { return s.model === "Odyssey G91F" }) ? 1.3 : 1.0
    // Three text sizes for every widget (px, before textScale); the corner badge and icons have their own
    readonly property int fontSmall: 14   // secondary lines, hints, tags
    readonly property int fontSize:  18   // body
    readonly property int fontLarge: 22   // titles, the volume figure

    // ── Spacing (px, 4px grid) ──────────────────────────────────────────────
    readonly property int gap:  12   // between elements, list-row padding
    readonly property int pad:  20   // inside cards and panels
    readonly property int edge: 40   // from the screen edge

    // ── Palette ─────────────────────────────────────────────────────────────
    readonly property color accent:  t.accent
    readonly property color accent2: t.accent2
    readonly property color accentText: t.accentText
    readonly property color ok:      t.ok
    readonly property color warning: t.warn      // critical, muted volume, DND count
    readonly property color danger:  t.danger    // recording

    readonly property int radius: t.radius
    readonly property int borderWidth: t.border        // widget frame
    readonly property int borderWidthInner: 1          // preview tiles etc.
    // Modal backdrop for the pickers: everything behind is dimmed (this scrim) + blurred
    // (the Hyprland layer_rule in modules/rules.lua). 0.0 = no dim, 1.0 = black.
    readonly property real dimAround: t.dim

    // ── Surfaces ────────────────────────────────────────────────────────────
    readonly property color surface: t.bg
    readonly property color outline: t.rule

    // ── Corner indicator ────────────────────────────────────────────────────
    readonly property color cornerBackground:  t.bg
    readonly property color cornerBorderColor: t.rule
    readonly property color cornerText:        t.ink

    // ── Pickers and popups (smart picker / exposé / menu / notifications) ──────
    readonly property color pickerBackground: t.bg
    readonly property color pickerBorder: t.frame       // panels with the keyboard: toned-down accent
    readonly property color pickerInputBackground: t.surface
    readonly property color pickerInputBorder: t.rule
    readonly property color pickerInputFocusBorder: t.accent
    readonly property color pickerListBackground: t.bg
    readonly property color pickerItemSelected: t.soft
    readonly property color pickerItemHover: t.surface
    readonly property color pickerText: t.ink
    readonly property color pickerSecondaryText: t.ink3
    readonly property color pickerPlaceholder: t.ink3
    readonly property color pickerHintText: t.ink3
}
