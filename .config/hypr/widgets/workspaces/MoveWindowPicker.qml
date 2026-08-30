import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Move the focused window to a workspace you pick.
// Enter = move (stay) · Shift+Enter = move + follow · Esc = cancel.
PanelWindow {
    id: picker

    visible: MoveWindowManager.pickerVisible

    // Show on configured monitor
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
    WlrLayershell.namespace: "move-window-picker"

    exclusionMode: ExclusionMode.Ignore
    color: Qt.rgba(0, 0, 0, Theme.dimAround)   // dims the backdrop (blurred via layer_rule)

    // Warm up the Wayland toplevel manager for live preview captures.
    Component.onCompleted: { var warm = ToplevelManager.toplevels }

    // Click-outside-to-close (delayed to allow focus to settle)
    property bool focusGrabActive: false
    Timer {
        id: focusGrabDelay
        interval: 100
        onTriggered: picker.focusGrabActive = true
    }
    onVisibleChanged: {
        if (visible) {
            focusGrabDelay.start()
        } else {
            focusGrabActive = false
        }
    }
    HyprlandFocusGrab {
        windows: [picker]
        active: picker.focusGrabActive
        onCleared: MoveWindowManager.hide()
    }

    // Main card container
    Rectangle {
        id: card
        // List on top, preview pane below — center the whole stack vertically.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: previewPane.visible ? -(previewPane.height + 16) / 2 : 0
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        width: Config.pickerWidth
        height: {
            var natural = 30 + titleColumn.height + Config.pickerInputHeight + 16 + listContainer.implicitHeight + hintsRow.height + 32
            var cap = Config.pickerMaxHeight
            if (previewPane.visible)
                cap = Math.min(cap, picker.height - previewPane.height - 60)
            return Math.min(cap, natural)
        }
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground

        // Border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.pickerBorder
            border.width: Theme.borderWidth
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Title + which window is being moved
            ColumnLayout {
                id: titleColumn
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 4
                spacing: 1

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Move window → workspace"
                    color: Theme.base0A
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "moving: " + (MoveWindowManager.currentWindowTitle || "(no focused window)")
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.maximumWidth: card.width - 40
                }
            }

            // Search/filter input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Config.pickerInputHeight
                radius: Theme.radius
                color: Theme.pickerInputBackground
                border.color: searchInput.activeFocus ? Theme.pickerInputFocusBorder : Theme.pickerInputBorder
                border.width: searchInput.activeFocus ? 2 : 1

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.pickerText
                    font.pixelSize: Config.pickerFontSize
                    selectByMouse: true
                    clip: true

                    text: MoveWindowManager.filterText
                    onTextChanged: MoveWindowManager.filterText = text

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search or type a new workspace..."
                        color: Theme.pickerPlaceholder
                        font.pixelSize: Config.pickerFontSize
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                    Keys.onUpPressed: {
                        if (MoveWindowManager.selectedIndex > 0)
                            MoveWindowManager.selectedIndex--
                    }
                    Keys.onDownPressed: {
                        if (MoveWindowManager.selectedIndex < MoveWindowManager.filteredWorkspaces.length - 1)
                            MoveWindowManager.selectedIndex++
                    }

                    // Enter = move (stay), Shift+Enter = move + follow
                    Keys.onReturnPressed: function(event) {
                        MoveWindowManager.moveToSelected((event.modifiers & Qt.ShiftModifier) !== 0)
                    }
                    Keys.onEnterPressed: function(event) {
                        MoveWindowManager.moveToSelected((event.modifiers & Qt.ShiftModifier) !== 0)
                    }

                    Keys.onEscapePressed: MoveWindowManager.hide()

                    Component.onCompleted: forceActiveFocus()
                }

                Connections {
                    target: MoveWindowManager
                    function onPickerVisibleChanged() {
                        if (MoveWindowManager.pickerVisible)
                            searchInput.forceActiveFocus()
                    }
                }
            }

            // Workspace list
            Rectangle {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                implicitHeight: {
                    var natural = Math.max(workspaceList.contentHeight, 80)
                    var cap = Config.pickerMaxHeight - 30 - Config.pickerInputHeight - hintsRow.height - 56
                    if (Config.pickerWorkspacePreview)
                        cap = Math.min(cap, Config.pickerWorkspaceVisibleRows * 108)
                    return Math.min(natural, cap)
                }

                ListView {
                    id: workspaceList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: MoveWindowManager.filteredWorkspaces
                    currentIndex: MoveWindowManager.selectedIndex
                    clip: true

                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: itemDelegate
                        required property var modelData
                        required property int index

                        width: workspaceList.width
                        height: hasWindows ? expandedHeight : compactHeight
                        radius: Theme.radius
                        color: index === MoveWindowManager.selectedIndex
                               ? Theme.pickerItemSelected
                               : itemMouseArea.containsMouse
                                 ? Theme.pickerItemHover
                                 : "transparent"

                        readonly property bool hasWindows: itemDelegate.modelData.windowList && itemDelegate.modelData.windowList.length > 0
                        readonly property int windowCount: itemDelegate.modelData.windowList ? itemDelegate.modelData.windowList.length : 0
                        readonly property int compactHeight: 60
                        readonly property int expandedHeight: compactHeight + 48

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: itemDelegate.modelData.name
                                    color: Theme.pickerText
                                    font.pixelSize: Config.pickerFontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: itemDelegate.modelData.windows + " window" + (itemDelegate.modelData.windows !== 1 ? "s" : "")
                                    color: Theme.pickerSecondaryText
                                    font.pixelSize: Config.pickerFontSize - 4
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: itemDelegate.hasWindows

                                Repeater {
                                    model: Math.min(itemDelegate.windowCount, 4)

                                    RowLayout {
                                        spacing: 6
                                        Image {
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            source: Quickshell.iconPath(itemDelegate.modelData.windowList[index]?.icon ?? "application-x-executable")
                                            sourceSize: Qt.size(18, 18)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            mipmap: true
                                        }
                                        Text {
                                            text: itemDelegate.modelData.windowList[index]?.title ||
                                                  itemDelegate.modelData.windowList[index]?.class ||
                                                  "Window"
                                            color: Theme.pickerSecondaryText
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 120
                                        }
                                    }
                                }

                                Text {
                                    visible: itemDelegate.windowCount > 4
                                    text: "+" + (itemDelegate.windowCount - 4) + " more"
                                    color: Theme.pickerHintText
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                MoveWindowManager.selectedIndex = itemDelegate.index
                                MoveWindowManager.moveToWorkspace(itemDelegate.modelData.name,
                                                                  (mouse.modifiers & Qt.ShiftModifier) !== 0)
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: MoveWindowManager.filterText
                              ? "Press Enter to move to new \"" + MoveWindowManager.filterText + "\""
                              : "No workspaces"
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Config.pickerFontSize
                        visible: workspaceList.count === 0
                    }
                }
            }

            // Hint keys row
            Row {
                id: hintsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 14

                Text {
                    text: "↑↓ Navigate"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Enter Move"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Shift+Enter Move+Follow"
                    color: Theme.base0A
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: "Esc Cancel"
                    color: Theme.pickerHintText
                    font.pixelSize: 13
                }
            }
        }
    }

    // === Target-workspace layout preview (live mini-map) ===
    Rectangle {
        id: previewPane

        property var wsItem: {
            var f = MoveWindowManager.filteredWorkspaces
            var idx = MoveWindowManager.selectedIndex
            if (f.length > 0 && idx >= 0 && idx < f.length) return f[idx]
            return null
        }
        property var wsWindows: wsItem ? MoveWindowManager.windowsForWorkspace(wsItem.name) : []
        property var mon: wsItem ? MoveWindowManager.monitorForWorkspace(wsItem.name) : null

        property var frame: {
            if (mon && mon.width > 0 && mon.height > 0) return mon
            if (wsWindows.length === 0) return null
            var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
            for (var i = 0; i < wsWindows.length; i++) {
                var w = wsWindows[i]
                minX = Math.min(minX, w.x); minY = Math.min(minY, w.y)
                maxX = Math.max(maxX, w.x + w.w); maxY = Math.max(maxY, w.y + w.h)
            }
            return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
        }

        // Content only when the highlighted workspace has windows; the pane
        // always reserves its space so nothing shifts while searching.
        readonly property bool hasPreview: wsItem !== null && wsWindows.length > 0 && frame !== null
        visible: Config.pickerWorkspacePreview

        readonly property int pad: 16
        // Reserve a fixed size from the picker screen's aspect ratio, so the
        // preview box never resizes as the highlighted workspace changes.
        readonly property real aspect: picker.screen && picker.screen.width > 0
            ? picker.screen.height / picker.screen.width
            : (9 / 16)
        readonly property real mapW: Math.min(Config.pickerPreviewWidth - pad * 2, Config.pickerPreviewHeight / aspect)
        readonly property real mapH: mapW * aspect

        width: mapW + pad * 2
        height: pad + previewHeader.height + 8 + mapH + pad
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground

        anchors.top: card.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.pickerBorder
            border.width: Theme.borderWidth
        }

        Column {
            anchors.fill: parent
            anchors.margins: previewPane.pad
            spacing: 8

            Row {
                id: previewHeader
                width: parent.width
                spacing: 8
                Text {
                    text: previewPane.wsItem ? previewPane.wsItem.name : ""
                    color: Theme.pickerText
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - countLabel.width - parent.spacing
                }
                Text {
                    id: countLabel
                    visible: previewPane.hasPreview
                    text: previewPane.wsWindows.length + (previewPane.wsWindows.length === 1 ? " window" : " windows")
                    color: Theme.pickerSecondaryText
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: previewPane.mapW
                height: previewPane.mapH
                radius: Theme.radius
                color: Theme.pickerListBackground
                clip: true

                Repeater {
                    model: previewPane.hasPreview ? previewPane.wsWindows : []

                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        property var f: previewPane.frame

                        x: f ? (modelData.x - f.x) / f.width * previewPane.mapW : 0
                        y: f ? (modelData.y - f.y) / f.height * previewPane.mapH : 0
                        width: f ? Math.max(8, modelData.w / f.width * previewPane.mapW) : 0
                        height: f ? Math.max(8, modelData.h / f.height * previewPane.mapH) : 0

                        radius: Theme.radius
                        color: Theme.pickerItemHover
                        border.color: Theme.outline
                        border.width: Theme.borderWidthInner
                        clip: true

                        property var tl: Config.pickerWorkspacePreviewLive
                            ? picker.findToplevel(modelData.class, modelData.title)
                            : null

                        ScreencopyView {
                            id: cap
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
                            width: Math.min(40, parent.width * 0.6)
                            height: width
                            source: Quickshell.iconPath(modelData.icon)
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            visible: !cap.visible
                        }
                    }
                }
            }
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
