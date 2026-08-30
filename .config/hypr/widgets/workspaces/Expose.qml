import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// macOS Exposé-style overview. Every workspace is a live mini-map grouped under
// its monitor. Drag a window tile onto another workspace to move it (view stays
// put). Click a window to focus it; click an empty part of a cell to switch to
// that workspace. Esc or a background click closes.
PanelWindow {
    id: root

    visible: ExposeManager.visible

    screen: {
        if (Config.pickerMonitor === "focused") {
            return Quickshell.screens.find(function(s) {
                return Hyprland.focusedMonitor !== null && s.name === Hyprland.focusedMonitor.name
            }) ?? Quickshell.screens[0]
        } else {
            return Quickshell.screens.find(function(s) {
                return s.name === Config.pickerMonitor
            }) ?? Quickshell.screens[0]
        }
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "expose"

    exclusionMode: ExclusionMode.Ignore
    color: Qt.rgba(0, 0, 0, Theme.dimAround)   // dims the backdrop (blurred via layer_rule)

    Component.onCompleted: { var warm = ToplevelManager.toplevels }

    // Background click closes the overview (cells sit above and handle their own).
    MouseArea {
        anchors.fill: parent
        onClicked: ExposeManager.hide()
    }

    // Keyboard focus holder for Esc.
    FocusScope {
        id: fs
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ExposeManager.hide()

        Column {
            id: content
            anchors.centerIn: parent
            width: Math.min(root.width - 120, 2600)
            spacing: 28

            // One section per monitor.
            Repeater {
                model: ExposeManager.monitors
                delegate: Column {
                    id: monSection
                    required property var modelData
                    readonly property var mon: modelData
                    width: content.width
                    spacing: 10

                    Text {
                        text: monSection.mon.name
                        color: Theme.pickerHintText
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 2
                    }

                    Flow {
                        width: content.width
                        spacing: 20

                        Repeater {
                            model: ExposeManager.workspacesForMonitor(monSection.mon.id)

                            // === Workspace cell ===
                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                readonly property string wsName: modelData.name
                                readonly property var frame: monSection.mon
                                readonly property real aspect: (frame && frame.width > 0) ? frame.height / frame.width : (9 / 16)
                                readonly property int mapW: Config.exposeCellWidth
                                readonly property int mapH: Math.round(mapW * aspect)
                                readonly property var wins: ExposeManager.windowsForWorkspace(wsName)
                                readonly property bool isActive: Hyprland.activeWorkspace ? Hyprland.activeWorkspace.name === wsName : false

                                width: mapW
                                height: labelRow.height + 6 + mapH
                                color: "transparent"

                                Column {
                                    anchors.fill: parent
                                    spacing: 6

                                    Row {
                                        id: labelRow
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            text: cell.wsName
                                            color: cell.isActive ? Theme.base0A : Theme.pickerText
                                            font.pixelSize: 15
                                            font.bold: true
                                            elide: Text.ElideRight
                                            width: parent.width - cnt.width - parent.spacing
                                        }
                                        Text {
                                            id: cnt
                                            text: cell.wins.length
                                            color: Theme.pickerSecondaryText
                                            font.pixelSize: 13
                                        }
                                    }

                                    Rectangle {
                                        id: minimap
                                        width: cell.mapW
                                        height: cell.mapH
                                        radius: Theme.radius
                                        color: Theme.pickerListBackground
                                        clip: true
                                        border.color: dropArea.containsDrag ? Theme.accent2
                                                     : cell.isActive ? Theme.base0A : Theme.pickerBorder
                                        border.width: (dropArea.containsDrag || cell.isActive) ? Theme.borderWidth : Theme.borderWidthInner

                                        DropArea {
                                            id: dropArea
                                            anchors.fill: parent
                                            onDropped: (drop) => ExposeManager.moveWindow(ghost.windowAddress, cell.wsName)
                                        }

                                        // Click empty area → switch to this workspace.
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: ExposeManager.switchTo(cell.wsName)
                                        }

                                        // Window tiles at real scaled positions.
                                        Repeater {
                                            model: cell.wins

                                            delegate: Rectangle {
                                                id: tile
                                                required property var modelData
                                                property var f: cell.frame

                                                x: f ? (modelData.x - f.x) / f.width * cell.mapW : 0
                                                y: f ? (modelData.y - f.y) / f.height * cell.mapH : 0
                                                width: f ? Math.max(10, modelData.w / f.width * cell.mapW) : 0
                                                height: f ? Math.max(10, modelData.h / f.height * cell.mapH) : 0

                                                radius: Theme.radius
                                                color: Theme.pickerItemHover
                                                border.color: tileMa.containsMouse ? Theme.accent2 : Theme.outline
                                                border.width: tileMa.containsMouse ? Theme.borderWidth : Theme.borderWidthInner
                                                clip: true

                                                property var tl: Config.pickerWorkspacePreviewLive
                                                    ? root.findToplevel(modelData.class, modelData.title)
                                                    : null

                                                ScreencopyView {
                                                    id: capv
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    captureSource: tile.tl
                                                    live: true
                                                    paintCursor: false
                                                    constraintSize: Qt.size(Math.max(1, tile.width), Math.max(1, tile.height))
                                                    visible: tile.tl !== null && hasContent
                                                }

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: Math.min(48, parent.width * 0.6)
                                                    height: width
                                                    source: Quickshell.iconPath(modelData.icon)
                                                    sourceSize: Qt.size(48, 48)
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    mipmap: true
                                                    visible: !capv.visible
                                                }

                                                // Drag to move, click to focus.
                                                MouseArea {
                                                    id: tileMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    preventStealing: true
                                                    property bool dragging: false
                                                    property point pressPt

                                                    onPressed: (mouse) => {
                                                        dragging = false
                                                        pressPt = Qt.point(mouse.x, mouse.y)
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (!pressed) return
                                                        if (!dragging) {
                                                            var dx = mouse.x - pressPt.x
                                                            var dy = mouse.y - pressPt.y
                                                            if (dx * dx + dy * dy < 49) return   // 7px threshold
                                                            dragging = true
                                                            ghost.begin(tile.modelData.address, tile.modelData.icon,
                                                                        tile.width, tile.height)
                                                        }
                                                        var gp = mapToItem(dragLayer, mouse.x, mouse.y)
                                                        ghost.x = gp.x - ghost.width / 2
                                                        ghost.y = gp.y - ghost.height / 2
                                                    }
                                                    onReleased: (mouse) => {
                                                        if (dragging) {
                                                            ghost.Drag.drop()
                                                            ghost.finish()
                                                            dragging = false
                                                        } else {
                                                            ExposeManager.focusWindow(tile.modelData.address)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Hint row
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drag a window to move it · Click a window to focus · Click a workspace to switch · Esc to close"
                color: Theme.pickerHintText
                font.pixelSize: 13
            }
        }
    }

    // === Floating drag ghost (above everything, un-clipped) ===
    Item {
        id: dragLayer
        anchors.fill: parent
        z: 1000

        Rectangle {
            id: ghost
            visible: false
            property string windowAddress: ""
            width: 160
            height: 100
            radius: Theme.radius
            color: Theme.pickerItemSelected
            border.color: Theme.accent2
            border.width: Theme.borderWidth
            opacity: 0.9

            Drag.active: ghost.visible
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            Image {
                id: ghostIcon
                anchors.centerIn: parent
                width: 40
                height: 40
                sourceSize: Qt.size(48, 48)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            function begin(addr, icon, w, h) {
                windowAddress = addr
                ghostIcon.source = Quickshell.iconPath(icon)
                width = Math.max(120, w)
                height = Math.max(80, h)
                visible = true
            }
            function finish() {
                visible = false
                windowAddress = ""
            }
        }
    }

    // Grab keyboard focus for Esc whenever the overview opens.
    Connections {
        target: ExposeManager
        function onVisibleChanged() {
            if (ExposeManager.visible) fs.forceActiveFocus()
        }
    }

    // Match a Wayland toplevel to a Hyprland window for a live capture.
    function findToplevel(appId, title) {
        if (!appId) return null
        var tls = ToplevelManager.toplevels.values
        var appOnly = null
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i]
            if (t.appId === appId && t.title === title) return t
            if (t.appId === appId && appOnly === null) appOnly = t
        }
        return appOnly
    }
}
