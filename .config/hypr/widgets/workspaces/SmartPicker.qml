import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// The Smart picker (Super+S): one ranked list of workspaces, windows, apps and
// shell commands, with a live mini-map of the highlighted row's workspace beside it.
PanelWindow {
    id: picker

    visible: SmartPickerManager.pickerVisible

    screen: Config.pickerScreen()

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "smart-picker"

    exclusionMode: ExclusionMode.Ignore
    color: Qt.rgba(0, 0, 0, Theme.dimAround)   // dims the backdrop (blurred via layer_rule)

    // Warm up the Wayland toplevel list at startup, so live captures are ready at first open
    Component.onCompleted: { var warm = ToplevelManager.toplevels }

    // Click outside closes (delayed so the opening click doesn't count)
    property bool focusGrabActive: false
    Timer {
        id: focusGrabDelay
        interval: 100
        onTriggered: picker.focusGrabActive = true
    }
    onVisibleChanged: {
        if (visible) {
            focusGrabDelay.start()
            input.text = ""
            input.forceActiveFocus()
        } else {
            focusGrabActive = false
        }
    }
    HyprlandFocusGrab {
        windows: [picker]
        active: picker.focusGrabActive
        onCleared: SmartPickerManager.hide()
    }

    readonly property var item: SmartPickerManager.selected
    // Preview beside the list when the screen has room, else below it
    readonly property bool wide: width >= Config.pickerWidth + previewPane.implicitWidth + 80

    readonly property string hints: {
        var n = SmartPickerManager.selectedWindows.length
        if (SmartPickerManager.moveMode) return "Enter move · Shift+Enter move and follow · Esc"
        if (n > 0) return n + " selected · Enter on a workspace: move there · Ctrl+Enter: here · Alt+Backspace close · Esc"
        var k = item ? item.kind : ""
        if (k === "win") return "Enter focus · Ctrl+Enter here · Tab select · Alt+Backspace close · Esc"
        if (k === "ws") return "Enter go · Ctrl+Enter to this monitor · Alt+Enter other monitor · Alt+Backspace close all · Esc"
        if (k === "app") return "Enter launch · Esc"
        if (k === "cmd") return "Enter run · Esc"
        if (k === "new") return "Enter create · Esc"
        return "Esc"
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: layout.implicitWidth + 24
        height: layout.implicitHeight + 24
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground
        border.color: Theme.pickerBorder
        border.width: Theme.borderWidth

        GridLayout {
            id: layout
            anchors.centerIn: parent
            columns: picker.wide ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            ColumnLayout {
                Layout.preferredWidth: Config.pickerWidth
                Layout.alignment: Qt.AlignTop
                spacing: 8

                // Active mode
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SmartPickerManager.moveMode
                          ? "Move \"" + (SmartPickerManager.openedTitle || "no focused window") + "\" to…"
                          : ({ w: "Workspaces", p: "Windows", a: "Applications", ">": "Run command" })[SmartPickerManager.parsed.letter] || "Smart"
                    color: SmartPickerManager.moveMode ? Theme.warning : Theme.pickerText
                    font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                    font.family: Theme.fontFamily
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Config.pickerInputHeight
                    radius: Theme.radius
                    color: Theme.pickerInputBackground
                    border.color: Theme.pickerInputFocusBorder
                    border.width: 2

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.pickerText
                        font.pixelSize: Math.round(Config.pickerFontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                        clip: true
                        focus: true

                        // Not bound to filterText (assigning text would break the binding):
                        // cleared on open instead. A typed prefix ("w ", "p ", "a ", "m ", ">") becomes the selector
                        onTextChanged: {
                            var m = SmartPickerManager.mode ? null
                                  : text.charAt(0) === ">" ? ">" : (text.match(/^([wpam]) /) || [])[1]
                            if (m) {
                                SmartPickerManager.mode = m
                                text = text.slice(m === ">" ? 1 : 2).replace(/^ /, "")
                                return
                            }
                            SmartPickerManager.filterText = text
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !input.text
                            text: ({ "": "Search workspaces, windows, apps…", w: "Workspace…", p: "Window…",
                                     a: "App…", m: "Move to workspace…", ">": "Shell command…" })[SmartPickerManager.mode]
                            color: Theme.pickerPlaceholder
                            font: input.font
                        }

                        Keys.onUpPressed: SmartPickerManager.selectedIndex = Math.max(0, SmartPickerManager.selectedIndex - 1)
                        Keys.onDownPressed: SmartPickerManager.selectedIndex =
                            Math.max(0, Math.min(SmartPickerManager.results.length - 1, SmartPickerManager.selectedIndex + 1))
                        Keys.onReturnPressed: function(event) { SmartPickerManager.activate(picker.item, event.modifiers) }
                        Keys.onEnterPressed: function(event) { SmartPickerManager.activate(picker.item, event.modifiers) }
                        Keys.onEscapePressed: SmartPickerManager.hide()
                        Keys.onTabPressed: function(event) {
                            if (picker.item && picker.item.kind === "win") SmartPickerManager.toggleSelection(picker.item.address)
                            event.accepted = true
                        }
                        Keys.onPressed: function(event) {
                            // Backspace on an empty field drops the selector
                            if (event.key === Qt.Key_Backspace && !input.text && SmartPickerManager.mode
                                && !(event.modifiers & Qt.AltModifier)) {
                                SmartPickerManager.mode = ""
                                event.accepted = true
                                return
                            }
                            if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
                                && (event.modifiers & Qt.AltModifier)) {
                                SmartPickerManager.closeItem(picker.item)
                                event.accepted = true
                            }
                        }
                    }
                }

                // Selectors: type the letter + space (or click); Backspace on empty = all
                Row {
                    spacing: 8
                    Repeater {
                        model: [["", "all"], ["w", "w  workspaces"], ["p", "p  windows"], ["a", "a  apps"],
                                ["m", "m  move"], [">", ">  command"]]
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool active: SmartPickerManager.mode === modelData[0]
                            width: chipLabel.implicitWidth + 20
                            height: chipLabel.implicitHeight + 8
                            radius: Theme.radius
                            color: active ? Theme.pickerItemSelected : "transparent"
                            border.color: active ? Theme.pickerInputFocusBorder : Theme.pickerBorder
                            border.width: 1
                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: chip.modelData[1]
                                color: chip.active ? Theme.pickerText : Theme.pickerSecondaryText
                                font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                                font.family: Theme.fontFamily
                                font.bold: chip.active
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { SmartPickerManager.mode = chip.modelData[0]; input.forceActiveFocus() }
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Config.pickerSmartVisibleRows * Config.pickerItemHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: SmartPickerManager.results
                    currentIndex: SmartPickerManager.selectedIndex
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool picked: modelData.kind === "win" && SmartPickerManager.isSelected(modelData.address)
                        readonly property bool current: index === SmartPickerManager.selectedIndex

                        width: list.width
                        height: Config.pickerItemHeight
                        radius: Theme.radius
                        color: picked ? Theme.accent
                             : current ? Theme.pickerItemSelected
                             : mouse.containsMouse ? Theme.pickerItemHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 24
                                radius: Theme.radius
                                color: row.picked ? Theme.accentText : Theme.accent
                                visible: row.current || row.picked
                            }

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                source: Quickshell.iconPath(row.modelData.icon)
                                sourceSize: Qt.size(24, 24)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    color: row.picked ? Theme.accentText : Theme.pickerText
                                    font.pixelSize: Math.round(Config.pickerFontSize * Theme.textScale)
                                    font.family: Theme.fontFamily
                                    font.bold: row.modelData.kind === "ws"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.subtitle
                                    color: row.picked ? Theme.accentText : Theme.pickerSecondaryText
                                    font.pixelSize: Math.round((Config.pickerFontSize - 4) * Theme.textScale)
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }
                            }

                            // Kind tag: ws · win · app · cmd · new
                            Text {
                                text: row.modelData.kind
                                color: row.picked ? Theme.accentText : Theme.pickerHintText
                                font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                                font.family: Theme.fontFamily
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(m) {
                                SmartPickerManager.selectedIndex = row.index
                                SmartPickerManager.activate(row.modelData, m.modifiers)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: SmartPickerManager.parsed.letter === ">" ? "Type a command" : "Nothing open"
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Math.round(Config.pickerFontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: picker.hints
                    color: Theme.pickerSecondaryText
                    font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            // Live mini-map of the highlighted row's workspace (empty for apps and commands;
            // the box keeps its size so nothing shifts)
            Rectangle {
                id: previewPane
                visible: Config.pickerWorkspacePreview
                Layout.alignment: Qt.AlignTop

                readonly property string wsName: !picker.item ? ""
                    : picker.item.kind === "ws" ? picker.item.name
                    : picker.item.kind === "win" ? picker.item.workspace : ""
                readonly property string selectedAddress: picker.item && picker.item.kind === "win" ? picker.item.address : ""
                readonly property var wins: wsName ? SmartPickerManager.windowsOn(wsName) : []
                readonly property var mon: wsName ? SmartPickerManager.monitorFor(wsName) : null
                // The real monitor, or the bounding box of the windows
                readonly property var frame: {
                    if (mon && mon.width > 0 && mon.height > 0) return mon
                    if (wins.length === 0) return null
                    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
                    for (var i = 0; i < wins.length; i++) {
                        var w = wins[i]
                        minX = Math.min(minX, w.x); minY = Math.min(minY, w.y)
                        maxX = Math.max(maxX, w.x + w.w); maxY = Math.max(maxY, w.y + w.h)
                    }
                    return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
                }
                readonly property bool hasPreview: wins.length > 0 && frame !== null

                readonly property int pad: 14
                // Fixed size from the picker screen's aspect ratio
                readonly property real aspect: picker.screen && picker.screen.width > 0
                    ? picker.screen.height / picker.screen.width : 9 / 16
                readonly property real mapW: Math.min(Config.pickerPreviewWidth - pad * 2, Config.pickerPreviewHeight / aspect)
                readonly property real mapH: mapW * aspect

                implicitWidth: mapW + pad * 2
                implicitHeight: pad + header.height + 8 + mapH + pad
                radius: Theme.radius
                color: "transparent"

                Column {
                    anchors.fill: parent
                    anchors.margins: previewPane.pad
                    spacing: 8

                    Row {
                        id: header
                        width: parent.width
                        spacing: 8
                        Text {
                            text: previewPane.wsName
                            color: Theme.pickerText
                            font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                            font.family: Theme.fontFamily
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width - countLabel.width - parent.spacing
                        }
                        Text {
                            id: countLabel
                            visible: previewPane.hasPreview
                            text: previewPane.wins.length + (previewPane.wins.length === 1 ? " window" : " windows")
                            color: Theme.pickerSecondaryText
                            font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                            font.family: Theme.fontFamily
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
                            model: previewPane.hasPreview ? previewPane.wins : []

                            delegate: Rectangle {
                                id: tile
                                required property var modelData
                                readonly property var f: previewPane.frame
                                readonly property bool isSelected: modelData.address === previewPane.selectedAddress

                                x: (modelData.x - f.x) / f.width * previewPane.mapW
                                y: (modelData.y - f.y) / f.height * previewPane.mapH
                                width: Math.max(6, modelData.w / f.width * previewPane.mapW)
                                height: Math.max(6, modelData.h / f.height * previewPane.mapH)
                                z: isSelected ? 1 : 0
                                radius: Theme.radius
                                color: Theme.pickerItemHover
                                border.color: isSelected ? Theme.pickerInputFocusBorder : Theme.outline
                                border.width: isSelected ? 3 : Theme.borderWidthInner
                                clip: true

                                ScreencopyView {
                                    id: cap
                                    anchors.fill: parent
                                    anchors.margins: tile.border.width
                                    captureSource: Config.pickerWorkspacePreviewLive ? tile.modelData.wayland : null
                                    // One frame when the tile appears: live capture at 144 Hz cost
                                    // ~7% CPU here, ~15% in Hyprland and ~10% GPU while open
                                    live: false
                                    paintCursor: false
                                    constraintSize: Qt.size(Math.max(1, tile.width), Math.max(1, tile.height))
                                    visible: captureSource !== null && hasContent
                                }

                                // App icon when there is no live capture
                                Image {
                                    anchors.centerIn: parent
                                    width: Math.min(28, parent.width * 0.6)
                                    height: width
                                    source: Quickshell.iconPath(tile.modelData.icon)
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    visible: !cap.visible
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
