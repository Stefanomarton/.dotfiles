import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// Workspace Corner Indicator — mostra il nome del workspace attivo.
// Il badge è sempre click-through (non blocca i click sotto di sé). Il fade
// on-hover è ottenuto leggendo la posizione del cursore dal socket di Hyprland,
// perché una superficie click-through non riceve eventi hover.
// Eseguire con: qs -p .
ShellRoot {
    id: root

    // Posizione globale del cursore (logica), aggiornata dal poller qui sotto.
    property real curX: -1
    property real curY: -1

    // "j/cursorpos" direttamente sul socket (una richiesta per connessione): prima era un
    // `hyprctl cursorpos` ogni 120 ms, ~80 processi ogni 10 s e ~9% di un core.
    Socket {
        id: curSock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
        parser: SplitParser {
            onRead: line => {
                var m = /"(x|y)": (-?[\d.]+)/.exec(line)
                if (m) root[m[1] === "x" ? "curX" : "curY"] = Number(m[2])
                if (line === "}") curSock.connected = false   // close first: else a PeerClosedError warning per poll
            }
        }
        onConnectedChanged: if (connected) { write("j/cursorpos"); flush() }
    }

    // lastIpcObject (activeWorkspace = the regular one, specialWorkspace apart) is only
    // refreshed on request: after a scratchpad toggle activeWorkspace can stay "special:…",
    // so the hidden-workspace check reads the regular name from here.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^(workspace|activespecial|focusedmon|moveworkspace)/.test(event.name))
                Hyprland.refreshMonitors()
        }
    }

    Timer {
        interval: 120
        repeat: true
        running: Config.showCorner && Config.cornerHoverFade
        onTriggered: if (!curSock.connected) curSock.connected = true
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
                        var name = ws ? (ws.name || String(ws.id)) : ""
                        // never a scratchpad (special:…): the monitor's regular workspace instead
                        if (name === "" || name.startsWith("special:")) name = regularWsName
                        if (!name) return "?"
                        if (name.match(/^\d+:/)) {
                            name = name.substring(name.indexOf(":") + 1)
                        }
                        return name
                    }
                }
                return "?"
            }

            // The monitor's regular workspace, even while a scratchpad (special:…) is shown on it
            readonly property string regularWsName: {
                for (var i = 0; i < Hyprland.monitors.values.length; i++) {
                    var m = Hyprland.monitors.values[i]
                    if (m.name === modelData.name) {
                        var o = m.lastIpcObject
                        return (o && o.activeWorkspace && o.activeWorkspace.name) ? o.activeWorkspace.name : ""
                    }
                }
                return ""
            }

            visible: Config.showCorner &&
                     (Config.cornerMonitor === "all" ||
                      modelData.name === Config.cornerMonitor) &&
                     Config.cornerHiddenWorkspaces.indexOf(monitorWsName) < 0 &&
                     Config.cornerHiddenWorkspaces.indexOf(regularWsName) < 0

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

            // ceil: the text width is fractional, a window rounded down by half a pixel elided "temi" to "te…"
            implicitWidth: Math.min(maxWidth, Math.max(minWidth, Math.ceil(wsText.implicitWidth) + paddingH * 2))
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

            // One pulse when a workspace on this monitor takes the focus (switch, or focus
            // coming here from the other monitor)
            Connections {
                target: Hyprland
                function onFocusedWorkspaceChanged() {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === cornerWin.modelData.name)
                        pulseAnim.restart()
                }
            }

            Rectangle {
                id: cornerRect
                anchors.fill: parent
                radius: Config.cornerRadius
                color: Theme.cornerBackground
                opacity: cornerWin.hovered ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Accent glow, 0 except during the pulse
                Rectangle {
                    id: pulseFill
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.accent
                    opacity: 0
                }

                Rectangle {
                    id: cornerBorder
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Theme.cornerBorderColor
                    border.width: Theme.borderWidth
                }

                ParallelAnimation {
                    id: pulseAnim
                    ColorAnimation { target: cornerBorder; property: "border.color"; from: Theme.accent; to: Theme.cornerBorderColor; duration: 700; easing.type: Easing.OutCubic }
                    NumberAnimation { target: cornerBorder; property: "border.width"; from: 5; to: Theme.borderWidth; duration: 700; easing.type: Easing.OutCubic }
                    NumberAnimation { target: pulseFill; property: "opacity"; from: 0.35; to: 0; duration: 700; easing.type: Easing.OutCubic }
                }

                Text {
                    id: wsText
                    anchors.centerIn: parent
                    anchors.leftMargin: paddingH
                    anchors.rightMargin: paddingH
                    width: Math.min(implicitWidth, parent.width - paddingH * 2)
                    text:           cornerWin.monitorWsName
                    color:          Theme.cornerText
                    font.pixelSize: Math.round((Config.cornerFontSize) * Theme.textScale)
                    font.bold:      true
                    font.family:    Theme.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── Cornice intorno al monitor appena messo in focus ─────────────────────
    // Solo quando il focus passa a un altro monitor (non a ogni cambio di workspace).
    // Stesso impulso del badge; mappata solo mentre pulsa (un overlay sempre presente
    // sopra un'app a schermo intero le toglierebbe la direct scanout).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: frameWin
            property var modelData
            screen: modelData
            visible: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace:     "focus-frame"

            exclusionMode: ExclusionMode.Ignore
            color:         "transparent"
            mask:          Region {}

            Connections {
                target: Hyprland
                function onFocusedMonitorChanged() {
                    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === frameWin.modelData.name)
                        frameWin.pulse()
                }
            }
            function pulse() {
                visible = true
                frameAnim.restart()
            }

            Rectangle {
                id: frame
                anchors.fill: parent
                color: "transparent"
                border.color: Theme.accent
                border.width: 6
                opacity: 0
            }

            NumberAnimation {
                id: frameAnim
                target: frame; property: "opacity"
                from: 1; to: 0; duration: 700; easing.type: Easing.OutCubic
                onFinished: frameWin.visible = false
            }
        }
    }

    // ── Dettatura (hyprwhspr-rs) — microfono in basso al centro ─────────────
    // Legge lo stato che hyprwhspr-rs scrive in ~/.cache/hyprwhspr-rs/status.json:
    // alt = inactive | active (registra) | processing (trascrive) | error.
    FileView {
        path: `${Quickshell.env("HOME")}/.cache/hyprwhspr-rs/status.json`
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: whspr
            property string text: ""
            property string tooltip: ""
            property string alt: ""
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            visible: modelData.model === "Odyssey G91F" &&
                     (whspr.alt === "active" || whspr.alt === "processing" || whspr.alt === "error")

            anchors.bottom: true
            margins.bottom: Config.cornerMargin

            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace:     "dictation-indicator"

            exclusionMode: ExclusionMode.Ignore
            color:         "transparent"
            mask:          Region {}

            implicitWidth:  micRow.implicitWidth + Config.cornerPaddingH * 2
            implicitHeight: micRow.implicitHeight + Config.cornerPaddingV * 2

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.cornerBackground
                border.width: Theme.borderWidth
                border.color: whspr.alt === "active" ? Theme.ok : Theme.warning

                Row {
                    id: micRow
                    anchors.centerIn: parent
                    spacing: Theme.gap

                    Text {
                        id: micIcon
                        text: whspr.text
                        color: whspr.alt === "active" ? Theme.ok : Theme.warning
                        font.pixelSize: Math.round((32) * Theme.textScale)
                        font.family: "Symbols Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter

                        // Pulsa mentre registra
                        SequentialAnimation on opacity {
                            running: whspr.alt === "active"
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) micIcon.opacity = 1
                            NumberAnimation { to: 0.35; duration: 600 }
                            NumberAnimation { to: 1;    duration: 600 }
                        }
                    }

                    Text {
                        text: whspr.alt === "active" ? "Registro…"
                            : whspr.alt === "processing" ? "Trascrivo…"
                            : whspr.tooltip
                        color: Theme.cornerText
                        font.pixelSize: Math.round(Theme.fontLarge * Theme.textScale)
                        font.bold: true
                        font.family: Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
