import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

FloatingWindow {
    id: root
    title: "OmaFiles"
    color: Color.background
    visible: true
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(860, 560)
    property string currentPath: Quickshell.env("HOME") || "/"
    property string searchText: ""
    property bool showHidden: false
    property int viewMode: 0
    property var entries: []
    property var selected: null
    property string previewText: "Select a file to preview it."
    property bool previewIsImage: false
    property string previewImageSource: ""
    property string notice: ""
    property string clipboardPath: ""
    property string clipboardMode: ""
    property string busyPath: ""
    property string sortKey: "name"
    property bool sortAscending: true
    property string helperPath: Qt.resolvedUrl("quatro_files.py").toString().replace("file://", "")

    function send(payload) { helper.write(JSON.stringify(payload) + "\n"); helper.flush() }
    function refresh() { send({op:"list", path:currentPath, hidden:showHidden, query:searchText, sort:sortKey, ascending:sortAscending}) }
    function select(item) { selected = item; previewIsImage = !!(item && item.image); previewImageSource = item && item.image ? "file://" + item.path : ""; previewText = item && item.image ? "" : "Select a file to preview it."; if (item) send({op:"preview", path:item.path}) }
    function enter(item) { if (item.directory) { currentPath = item.path; searchText = ""; selected = null; refresh() } else send({op:"open", path:item.path}) }
    function up() { var p = currentPath; if (p !== "/") { currentPath = p.substring(0, p.lastIndexOf("/")) || "/"; refresh() } }
    function notify(message) { notice = message; noticeTimer.restart() }
    function action(op, extra) { busyPath = selected ? selected.path : currentPath; send(Object.assign({op:op, path:selected ? selected.path : currentPath}, extra || {})) }
    function copySelected(mode) {
        if (!selected) return
        clipboardPath = selected.path; clipboardMode = mode
        notify((mode === "cut" ? "Cut " : "Copied ") + selected.name)
    }
    function pasteClipboard() {
        if (!clipboardPath) { notify("Nothing to paste"); return }
        busyPath = clipboardPath
        send({op:"paste", source:clipboardPath, destination:currentPath, mode:clipboardMode})
    }
    function nextSort() {
        var keys = ["name", "size", "modified", "created"]
        var index = keys.indexOf(sortKey)
        sortKey = keys[(index + 1) % keys.length]
        sortAscending = true
        refresh()
    }
    function sortLabel() { return {name:"Name", size:"Size", modified:"Modified", created:"Created"}[sortKey] }
    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(1) + " GB"
    }
    function formatDate(seconds) { return Qt.formatDateTime(new Date(Number(seconds) * 1000), "yyyy-MM-dd HH:mm") }

    Process {
        id: helper
        command: ["python3", root.helperPath]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: function(line) { try { root.handle(JSON.parse(line)) } catch (e) { root.notify(String(e)) } } }
    }
    function handle(data) {
        if (data.items !== undefined) { entries = data.items; if (!data.ok) notify(data.error) }
        else if (data.text !== undefined) { previewText = data.text; previewIsImage = !!data.image; previewImageSource = data.imagePath ? "file://" + data.imagePath : previewImageSource }
        else if (data.ok) { busyPath = ""; if (clipboardMode === "cut" && data.moved) { clipboardPath = ""; clipboardMode = "" }; notify("Done"); refresh() } else { busyPath = ""; notify(data.error || "Could not complete action") }
    }
    Timer { id: noticeTimer; interval: 2600 }
    Timer { id: startupRefresh; interval: 250; repeat: false; running: true; onTriggered: refresh() }
    Component.onCompleted: list.forceActiveFocus()
    onCurrentPathChanged: pathField.text = currentPath
    onShowHiddenChanged: refresh()

    Shortcut { sequence: "Ctrl+L"; onActivated: pathField.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: newFolder.open() }
    Shortcut { sequence: "Ctrl+C"; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.copySelected("copy") }
    Shortcut { sequence: "Ctrl+X"; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.copySelected("cut") }
    Shortcut { sequence: "Ctrl+V"; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.pasteClipboard() }
    Shortcut { sequence: "Delete"; onActivated: if (selected) confirmTrash.open() }
    Shortcut { sequence: "Escape"; onActivated: if (searchField.activeFocus) { searchText = ""; searchField.clearFocus(); refresh() } }

    ColumnLayout { anchors.fill: parent; anchors.margins: Style.space(20); spacing: Style.space(12)
        RowLayout { Layout.fillWidth: true; spacing: Style.space(12)
            Text { text: "◈"; color: Color.accent; font.pixelSize: Style.font.iconLarge }
            ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: "OmaFiles"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
                Text { text: "A calm place for your files"; color: Color.muted; font.pixelSize: Style.font.caption }
            }
            Button { text: "⌂ Home"; bordered: true; onClicked: { currentPath = Quickshell.env("HOME") || "/"; refresh() } }
            Button { text: "↻"; bordered: true; onClicked: refresh() }
        }
        RowLayout { Layout.fillWidth: true; spacing: Style.space(8)
            Button { text: "‹"; bordered: true; onClicked: up() }
            TextField { id: pathField; Layout.fillWidth: true; text: root.currentPath; placeholderText: "Location"; onAccepted: { root.currentPath = text; root.refresh() } }
            TextField { id: searchField; Layout.preferredWidth: Style.space(220); placeholderText: "⌕  Search this folder"; onTextChanged: { root.searchText = text; root.refresh() } }
            Button { text: root.showHidden ? "Hidden on" : "Hidden"; bordered: true; onClicked: root.showHidden = !root.showHidden }
            Button { text: "＋ New folder"; bordered: true; onClicked: newFolder.open() }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Color.foreground, 0.12) }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: Style.space(14)
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: Qt.alpha(Color.foreground, 0.035); radius: Style.radius.normal
                ListView { id: list; anchors.fill: parent; anchors.margins: Style.space(8); clip: true; model: root.entries; focus: true
                    onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.entries.length) root.select(root.entries[currentIndex])
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (currentIndex >= 0) root.enter(root.entries[currentIndex]); event.accepted = true }
                        else if (event.key === Qt.Key_Backspace) { root.up(); event.accepted = true }
                        else if (event.key === Qt.Key_H) { root.up(); event.accepted = true }
                        else if (event.key === Qt.Key_L) { if (currentIndex >= 0) root.enter(root.entries[currentIndex]); event.accepted = true }
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { currentIndex = Math.min(count - 1, currentIndex + 1); event.accepted = true }
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { currentIndex = Math.max(0, currentIndex - 1); event.accepted = true }
                        else if (event.key === Qt.Key_Delete && currentIndex >= 0) { root.select(root.entries[currentIndex]); confirmTrash.open(); event.accepted = true }
                    }
                    delegate: Rectangle { required property var modelData; required property int index; width: list.width; height: root.viewMode === 2 ? Style.space(92) : Style.space(48); radius: Style.radius.small; color: root.selected && root.selected.path === modelData.path ? Qt.alpha(Color.accent, 0.18) : "transparent"; opacity: root.clipboardMode === "cut" && root.clipboardPath === modelData.path ? 0.5 : 1
                        Row { anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(12)
                            Text { width: Style.space(28); text: root.busyPath === modelData.path ? "…" : (root.clipboardPath === modelData.path ? (root.clipboardMode === "cut" ? "✂" : "⧉") : (modelData.directory ? "□" : "·")); color: root.busyPath === modelData.path ? Color.accent : (modelData.directory ? Color.accent : Color.muted); font.pixelSize: Style.font.title; horizontalAlignment: Text.AlignHCenter }
                            Column { width: parent.width - Style.space(210); anchors.verticalCenter: parent.verticalCenter; Text { text: modelData.name; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight } Text { text: modelData.directory ? "Folder" : (root.formatBytes(modelData.size) + " · modified " + root.formatDate(modelData.modified)); color: Color.muted; font.pixelSize: Style.font.caption; elide: Text.ElideRight } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.directory ? "" : "↗"; color: Color.muted }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { list.currentIndex = index; root.select(modelData) }
                            onDoubleClicked: root.enter(modelData)
                        }
                    }
                }
                Text { anchors.centerIn: parent; visible: root.entries.length === 0; text: root.searchText ? "No matches" : "This folder is empty"; color: Color.muted; font.pixelSize: Style.font.body }
            }
            Rectangle { Layout.preferredWidth: Style.space(320); Layout.fillHeight: true; color: Qt.alpha(Color.foreground, 0.035); radius: Style.radius.normal
                Column { anchors.fill: parent; anchors.margins: Style.space(16); spacing: Style.space(10)
                    Text { text: root.selected ? root.selected.name : "Preview"; color: Color.foreground; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight; width: parent.width }
                    Text { visible: !!root.selected; text: root.selected ? (root.selected.directory ? "Folder" : root.formatBytes(root.selected.size)) + "\nModified  " + root.formatDate(root.selected.modified) + "\nCreated   " + root.formatDate(root.selected.created) : ""; color: Color.muted; font.pixelSize: Style.font.caption; lineHeight: 1.15 }
                    Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.foreground, 0.12) }
                    Image { visible: root.previewIsImage && !!root.selected; width: parent.width; height: Math.max(100, parent.height - Style.space(170)); source: root.previewImageSource; fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false }
                    ScrollView { visible: !root.previewIsImage; width: parent.width; height: Math.max(100, parent.height - Style.space(170)); Text { width: parent.width; text: root.previewText; color: Color.muted; font.family: "monospace"; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; textFormat: Text.PlainText } }
                    Row { spacing: Style.space(8); Button { text: "Open"; enabled: !!root.selected; bordered: true; onClicked: root.enter(root.selected) } Button { text: "Rename"; enabled: !!root.selected; bordered: true; onClicked: renameDialog.open() } Button { text: "Trash"; enabled: !!root.selected; bordered: true; onClicked: confirmTrash.open() } }
                }
            }
        }
        RowLayout { Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.notice || (root.entries.length + " items · " + root.currentPath); color: root.notice ? Color.accent : Color.muted; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
            Button { text: "Sort: " + root.sortLabel() + (root.sortAscending ? " ↑" : " ↓"); bordered: true; onClicked: root.nextSort() }
            Button { text: "⇅"; bordered: true; onClicked: { root.sortAscending = !root.sortAscending; root.refresh() } }
            Button { text: "List"; bordered: root.viewMode === 0; onClicked: root.viewMode = 0 }
            Button { text: "Compact"; bordered: root.viewMode === 1; onClicked: root.viewMode = 1 }
            Button { text: "Grid"; bordered: root.viewMode === 2; onClicked: root.viewMode = 2 }
        }
    }

    Dialog { id: newFolder; title: "New folder"; standardButtons: Dialog.Ok | Dialog.Cancel; modal: true; anchors.centerIn: Overlay.overlay
        TextField { id: folderName; width: Style.space(320); placeholderText: "Folder name"; onAccepted: newFolder.accept() }
        onAccepted: { if (folderName.text.trim()) root.action("mkdir", {path:root.currentPath, name:folderName.text.trim()}); folderName.text = "" }
    }
    Dialog { id: renameDialog; title: "Rename"; standardButtons: Dialog.Ok | Dialog.Cancel; modal: true; anchors.centerIn: Overlay.overlay
        TextField { id: renameName; width: Style.space(320); text: root.selected ? root.selected.name : ""; onAccepted: renameDialog.accept() }
        onAccepted: { if (renameName.text.trim() && root.selected) root.action("rename", {name:renameName.text.trim()}); }
    }
    Dialog { id: confirmTrash; title: "Move to Trash?"; standardButtons: Dialog.Ok | Dialog.Cancel; modal: true; anchors.centerIn: Overlay.overlay
        Text { text: root.selected ? "Move “" + root.selected.name + "” to Trash?" : "Move this item to Trash?"; color: Color.foreground }
        onAccepted: if (root.selected) root.action("trash")
    }
}
