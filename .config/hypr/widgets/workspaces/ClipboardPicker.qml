import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Clipboard picker (Super+V): cliphist history with a preview of the highlighted entry.
// Enter pastes into the window that had focus, Shift+Enter only copies, Ctrl+Enter
// opens the text in the Emacs dettatura popup (C-c C-c pastes it back). The paste and
// the popup go through ~/.config/hypr/scripts/dettatura-emacs.sh.
PanelWindow {
    id: picker

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/dettatura-emacs.sh"
    readonly property string imgDir: Quickshell.env("XDG_RUNTIME_DIR") + "/appunti-preview"

    property bool open: false
    property var entries: []          // { id, text, image } from `cliphist list`, newest first
    property string filterText: ""
    property int selectedIndex: 0

    // Every typed word must appear in the line (cliphist keeps the first 100 characters)
    readonly property var results: {
        var words = filterText.toLowerCase().split(/\s+/).filter(function(w) { return w })
        if (words.length === 0) return entries
        return entries.filter(function(e) {
            var t = e.text.toLowerCase()
            return words.every(function(w) { return t.indexOf(w) >= 0 })
        })
    }
    readonly property var item: results[selectedIndex] ?? null

    onFilterTextChanged: selectedIndex = 0
    onItemChanged: {
        previewText = ""
        if (item) {
            previewProc.running = false
            previewProc.command = item.image
                ? ["sh", "-c", 'mkdir -p "$2"; f="$2/$1.png"; [ -s "$f" ] || cliphist decode "$1" > "$f"', "sh", item.id, imgDir]
                : ["sh", "-c", 'cliphist decode "$1" | head -c 20000', "sh", item.id]
            previewProc.running = true
        }
    }

    function show() {
        filterText = ""
        input.text = ""
        selectedIndex = 0
        listProc.running = true
        open = true
    }
    function hide() { open = false }
    function toggle() { if (open) hide(); else show() }

    // Enter: copy and paste · Shift: copy only · Ctrl: edit in Emacs (text only)
    function activate(row, modifiers) {
        if (!row) return
        if ((modifiers & Qt.ControlModifier) && !row.image) {
            hide()
            Quickshell.execDetached([script, "modifica", row.id])
            return
        }
        var copy = 'cliphist decode "$1" | wl-copy'
        hide()
        Quickshell.execDetached(["sh", "-c", (modifiers & Qt.ShiftModifier) ? copy : copy + ' && exec "$2" incolla',
                                 "sh", row.id, script])
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.entries = text.split("\n").filter(function(l) { return l }).map(function(l) {
                    var i = l.indexOf("\t")
                    var t = l.substring(i + 1)
                    return { id: l.substring(0, i), text: t, image: t.startsWith("[[ binary data") }
                })
            }
        }
    }

    property string previewText: ""
    Process {
        id: previewProc
        stdout: StdioCollector { onStreamFinished: if (!picker.item?.image) picker.previewText = text }
    }

    visible: open
    screen: Config.pickerScreen()

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "clipboard-picker"

    exclusionMode: ExclusionMode.Ignore
    color: Qt.rgba(0, 0, 0, Theme.dimAround)

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
            input.forceActiveFocus()
        } else {
            focusGrabActive = false
        }
    }
    HyprlandFocusGrab {
        windows: [picker]
        active: picker.focusGrabActive
        onCleared: picker.hide()
    }

    Rectangle {
        anchors.centerIn: parent
        width: layout.implicitWidth + 24
        height: layout.implicitHeight + 24
        radius: Config.pickerBorderRadius
        color: Theme.pickerBackground
        border.color: Theme.pickerBorder
        border.width: Theme.borderWidth

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: Config.pickerWidth
                Layout.alignment: Qt.AlignTop
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Appunti"
                    color: Theme.pickerText
                    font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                    font.family: Theme.fontFamily
                    font.bold: true
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
                        onTextChanged: picker.filterText = text

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !input.text
                            text: "Cerca negli appunti…"
                            color: Theme.pickerPlaceholder
                            font: input.font
                        }

                        Keys.onUpPressed: picker.selectedIndex = Math.max(0, picker.selectedIndex - 1)
                        Keys.onDownPressed: picker.selectedIndex = Math.max(0, Math.min(picker.results.length - 1, picker.selectedIndex + 1))
                        Keys.onReturnPressed: function(event) { picker.activate(picker.item, event.modifiers) }
                        Keys.onEnterPressed: function(event) { picker.activate(picker.item, event.modifiers) }
                        Keys.onEscapePressed: picker.hide()
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Config.pickerSmartVisibleRows * Config.pickerItemHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: picker.results
                    currentIndex: picker.selectedIndex
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: index === picker.selectedIndex

                        width: list.width
                        height: Config.pickerItemHeight
                        radius: Theme.radius
                        color: current ? Theme.pickerItemSelected : mouse.containsMouse ? Theme.pickerItemHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 24
                                radius: Theme.radius
                                color: Theme.accent
                                visible: row.current
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.image
                                      ? row.modelData.text.replace(/^\[\[ binary data /, "immagine · ").replace(/ \]\]$/, "")
                                      : row.modelData.text
                                color: row.modelData.image ? Theme.pickerSecondaryText : Theme.pickerText
                                font.pixelSize: Math.round(Config.pickerFontSize * Theme.textScale)
                                font.family: Theme.fontFamily
                                font.italic: row.modelData.image
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(m) {
                                picker.selectedIndex = row.index
                                picker.activate(row.modelData, m.modifiers)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: listProc.running ? "" : "Niente"
                        color: Theme.pickerSecondaryText
                        font.pixelSize: Math.round(Config.pickerFontSize * Theme.textScale)
                        font.family: Theme.fontFamily
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: picker.item?.image ? "Enter incolla · Shift+Enter copia · Esc"
                                             : "Enter incolla · Ctrl+Enter modifica in Emacs · Shift+Enter copia · Esc"
                    color: Theme.pickerSecondaryText
                    font.pixelSize: Math.round(Theme.fontSmall * Theme.textScale)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            // Preview: the whole text (first 20 000 bytes) or the image
            Rectangle {
                Layout.preferredWidth: Config.pickerWidth
                Layout.fillHeight: true
                radius: Theme.radius
                color: Theme.pickerInputBackground
                clip: true

                Text {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: !picker.item?.image
                    text: picker.previewText
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    color: Theme.pickerText
                    font.pixelSize: Math.round((Config.pickerFontSize - 2) * Theme.textScale)
                    font.family: Theme.fontFamily
                }
                Image {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: picker.item?.image ?? false
                    // set once the file is written (previewProc finished)
                    source: visible && !previewProc.running ? "file://" + picker.imgDir + "/" + picker.item.id + ".png" : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
            }
        }
    }
}
