import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Workspace Corner Indicator — mostra il nome del workspace attivo.
// Il badge è sempre click-through (non blocca i click sotto di sé). Il fade
// on-hover è ottenuto leggendo la posizione del cursore (hyprctl cursorpos),
// perché una superficie click-through non riceve eventi hover.
// Eseguire con: qs -p .
ShellRoot {
    id: root

    // Posizione globale del cursore (logica), aggiornata dal poller qui sotto.
    property real curX: -1
    property real curY: -1

    Process {
        id: curProc
        command: ["hyprctl", "cursorpos", "-j"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => curProc.buffer += data
        }
        onRunningChanged: {
            if (!running && buffer !== "") {
                try {
                    var p = JSON.parse(buffer)
                    root.curX = p.x
                    root.curY = p.y
                } catch (e) {}
                buffer = ""
            }
        }
    }

    Timer {
        interval: 120
        repeat: true
        running: Config.showCorner && Config.cornerHoverFade
        onTriggered: {
            if (!curProc.running) {
                curProc.buffer = ""
                curProc.running = true
            }
        }
    }

    // ── Corner indicator — one instance per monitor ─────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: cornerWin
            property var modelData
            screen: modelData

            readonly property string monitorWsName: {
                for (var i = 0; i < Hyprland.monitors.values.length; i++) {
                    var m = Hyprland.monitors.values[i]
                    if (m.name === modelData.name) {
                        var ws = m.activeWorkspace
                        if (!ws) return "?"
                        var name = ws.name || String(ws.id)
                        if (name.match(/^\d+:/)) {
                            name = name.substring(name.indexOf(":") + 1)
                        }
                        if (name.startsWith("special:")) {
                            name = name.substring(8)
                        }
                        return name
                    }
                }
                return "?"
            }

            visible: Config.showCorner &&
                     (Config.cornerMonitor === "all" ||
                      modelData.name === Config.cornerMonitor)

            // Posizione verticale
            anchors.top:    Config.cornerPositionV === "top"
            anchors.bottom: Config.cornerPositionV === "bottom"
            margins.top:    Config.cornerPositionV === "top" ? Config.cornerMargin : 0
            margins.bottom: Config.cornerPositionV === "bottom" ? Config.cornerMargin : 0

            // Posizione orizzontale
            anchors.left:   Config.cornerPositionH === "left"
            anchors.right:  Config.cornerPositionH === "right"
            margins.left:   Config.cornerPositionH === "left" ? Config.cornerMargin : 0
            margins.right:  Config.cornerPositionH === "right" ? Config.cornerMargin : 0

            WlrLayershell.layer:         WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace:     "workspaces-corner"

            exclusionMode:  ExclusionMode.Ignore
            color:          "transparent"

            // Non catturare mai il click: passa sempre alle finestre sotto.
            mask: Region {}

            // Dimensioni
            readonly property int minWidth: Config.cornerMinWidth
            readonly property int minHeight: Config.cornerMinHeight
            readonly property int maxWidth: Config.cornerMaxWidth
            readonly property int paddingH: Config.cornerPaddingH
            readonly property int paddingV: Config.cornerPaddingV

            implicitWidth: Math.min(maxWidth, Math.max(minWidth, wsText.implicitWidth + paddingH * 2))
            implicitHeight: Math.max(minHeight, wsText.implicitHeight + paddingV * 2)

            // Rettangolo del badge in coordinate globali logiche, per capire se
            // il cursore ci passa sopra (la superficie non riceve hover events).
            readonly property real badgeX: {
                if (Config.cornerPositionH === "left")  return modelData.x + Config.cornerMargin
                if (Config.cornerPositionH === "right") return modelData.x + modelData.width - Config.cornerMargin - width
                return modelData.x + (modelData.width - width) / 2
            }
            readonly property real badgeY: {
                if (Config.cornerPositionV === "top")    return modelData.y + Config.cornerMargin
                if (Config.cornerPositionV === "bottom") return modelData.y + modelData.height - Config.cornerMargin - height
                return modelData.y + (modelData.height - height) / 2
            }
            readonly property bool hovered: Config.cornerHoverFade &&
                root.curX >= badgeX && root.curX <= badgeX + width &&
                root.curY >= badgeY && root.curY <= badgeY + height

            Rectangle {
                id: cornerRect
                anchors.fill: parent
                radius: Config.cornerRadius
                color: Theme.cornerBackground
                opacity: cornerWin.hovered ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Theme.cornerBorderColor
                    border.width: Theme.borderWidth
                }

                Text {
                    id: wsText
                    anchors.centerIn: parent
                    anchors.leftMargin: paddingH
                    anchors.rightMargin: paddingH
                    width: Math.min(implicitWidth, parent.width - paddingH * 2)
                    text:           cornerWin.monitorWsName
                    color:          Theme.cornerText
                    font.pixelSize: Config.cornerFontSize
                    font.bold:      true
                    font.family:    "sans-serif"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
