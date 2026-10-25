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

    screen: Config.pickerScreen()

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "expose"

    exclusionMode: ExclusionMode.Ignore
    // Darker than the pickers' scrim: behind a grid of thumbnails the windows compete with them
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)

    // Height each monitor section may use for its row of thumbnails
    readonly property real sectionMapH: (height - 260) / Math.max(1, ExposeManager.monitors.length) - 140

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
            width: root.width - 200
            spacing: 36

            // One section per monitor: workspaces with windows as big thumbnails on one row,
            // empty ones as small named boxes below (still drop targets).
            Repeater {
                model: ExposeManager.monitors
                delegate: Column {
                    id: monSection
                    required property var modelData
                    readonly property var mon: modelData
                    readonly property var all: ExposeManager.workspacesForMonitor(mon.id)
                    readonly property var full: all.filter(function(ws) { return ExposeManager.windowsForWorkspace(ws.name).length > 0 })
                    readonly property var empty: all.filter(function(ws) { return ExposeManager.windowsForWorkspace(ws.name).length === 0 })
                    readonly property real aspect: (mon && mon.width > 0) ? mon.height / mon.width : (9 / 16)
                    // Fit the row to the width, at most half of it, and to this section's height
                    readonly property real cellW: Math.min((content.width - 24 * (full.length - 1)) / Math.max(1, full.length),
                                                           content.width / 2, root.sectionMapH / aspect)
                    // Centered, as wide as its widest row; the rows stay left-aligned with the label
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(cellsRow.implicitWidth, chipsRow.implicitWidth, monLabel.implicitWidth)
                    spacing: 12

                    // Monitor model ("Odyssey G91F"), not the connector name
                    Text {
                        id: monLabel
                        text: (Quickshell.screens.find(function(s) { return s.name === monSection.mon.name }) || {}).model || monSection.mon.name
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Math.round(Theme.fontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: 2
                    }

                    Row {
                        id: cellsRow
                        spacing: 24

                        Repeater {
                            model: monSection.full

                            // === Workspace cell ===
                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                readonly property string wsName: modelData.name
                                readonly property var frame: monSection.mon
                                readonly property int mapW: Math.round(monSection.cellW)
                                readonly property int mapH: Math.round(mapW * monSection.aspect)
                                readonly property var wins: ExposeManager.windowsForWorkspace(wsName)
                                readonly property bool isActive: Hyprland.activeWorkspace ? Hyprland.activeWorkspace.name === wsName : false

                                width: mapW
                                height: labelRow.height + 8 + mapH
                                color: "transparent"

                                Column {
                                    anchors.fill: parent
                                    spacing: 8

                                    Row {
                                        id: labelRow
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            text: cell.wsName
                                            color: cell.isActive ? Theme.accent : Theme.pickerText
                                            font.pixelSize: Math.round(Theme.fontLarge * Theme.textScale)
                                            font.family: Theme.fontFamily
                                            font.bold: true
                                            elide: Text.ElideRight
                                            width: parent.width - cnt.width - parent.spacing
                                        }
                                        Text {
                                            id: cnt
                                            anchors.bottom: parent.bottom
                                            text: cell.wins.length + (cell.wins.length === 1 ? " window" : " windows")
                                            color: Theme.pickerSecondaryText
                                            font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                                            font.family: Theme.fontFamily
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
                                                     : cell.isActive ? Theme.accent : Theme.pickerBorder
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
                                                    // One frame when the tile appears, as in the Smart picker:
                                                    // live capture of every window cost CPU and GPU while open
                                                    live: false
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

                                                // Window title, readable over any content
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    height: titleText.implicitHeight + 8
                                                    visible: tile.height > height * 2
                                                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.75)
                                                    Text {
                                                        id: titleText
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        x: 8
                                                        width: parent.width - 16
                                                        text: tile.modelData.title || tile.modelData.class
                                                        color: Theme.pickerText
                                                        font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                                                        font.family: Theme.fontFamily
                                                        elide: Text.ElideRight
                                                    }
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

                    // Empty workspaces: small boxes with the name; click to switch, drop to move
                    Row {
                        id: chipsRow
                        spacing: 12
                        visible: monSection.empty.length > 0

                        Repeater {
                            model: monSection.empty
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool isActive: Hyprland.activeWorkspace ? Hyprland.activeWorkspace.name === modelData.name : false
                                width: Math.max(Math.round(110 * Theme.textScale), chipText.implicitWidth + 32)
                                height: Math.round(52 * Theme.textScale)
                                radius: Theme.radius
                                color: chipDrop.containsDrag ? Theme.pickerItemSelected : Theme.pickerListBackground
                                border.color: chipDrop.containsDrag ? Theme.accent2 : chip.isActive ? Theme.accent : Theme.pickerBorder
                                border.width: (chipDrop.containsDrag || chip.isActive) ? Theme.borderWidth : Theme.borderWidthInner

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: chip.modelData.name
                                    color: chip.isActive ? Theme.accent : Theme.pickerSecondaryText
                                    font.pixelSize: Math.round(Theme.fontSize * Theme.textScale)
                                    font.family: Theme.fontFamily
                                    font.bold: true
                                }
                                DropArea {
                                    id: chipDrop
                                    anchors.fill: parent
                                    onDropped: (drop) => ExposeManager.moveWindow(ghost.windowAddress, chip.modelData.name)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: ExposeManager.switchTo(chip.modelData.name)
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
                color: Theme.pickerSecondaryText
                font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                font.family: Theme.fontFamily
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
