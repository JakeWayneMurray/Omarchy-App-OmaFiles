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
    property var selectedItems: []
    property int selectionAnchor: -1
    property string previewText: "Select a file to preview it."
    property bool previewIsImage: false
    property string previewImageSource: ""
    property string notice: ""
    property string clipboardPath: ""
    property var clipboardPaths: []
    property string clipboardMode: ""
    property string busyPath: ""
    property var busyPaths: []
    property string sortKey: "name"
    property bool sortAscending: true
    property string helperPath: Qt.resolvedUrl("quatro_files.py").toString().replace("file://", "")
    readonly property string themeStatePath: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/current"
    property string keyParent: "h"
    property string keyOpen: "l"
    property string keyMoveDown: "j"
    property string keyMoveUp: "k"
    property string keySelect: "Space"
    property string keyCopy: "Ctrl+C"
    property string keyCut: "Ctrl+X"
    property string keyPaste: "Ctrl+V"
    property string keyLocalSend: "Ctrl+Shift+L"
    property string keyCompress: "C"
    property string keyUncompress: "U"
    property string keyRename: "r"
    property string keyQuickPath: "t"
    property string keyDelete: "d"
    property string keyNewFolder: "Ctrl+Shift+N"
    property string keyClearSelection: "Escape"

    function reloadThemeFiles() {
        themeColorsFile.reload()
        themeShellFile.reload()
    }

    property FileView themeNameFile: FileView {
        path: root.themeStatePath + "/theme.name"
        watchChanges: true
        printErrors: false
        onLoaded: root.reloadThemeFiles()
        onFileChanged: reload()
    }
    property FileView themeColorsFile: FileView {
        path: root.themeStatePath + "/theme/colors.toml"
        watchChanges: false
        printErrors: false
        onLoaded: Color.loadColors(text())
    }
    property FileView themeShellFile: FileView {
        path: root.themeStatePath + "/theme/shell.toml"
        watchChanges: false
        printErrors: false
        onLoaded: Color.loadShell(text())
        onLoadFailed: Color.loadShell("")
    }

    function send(payload) { helper.write(JSON.stringify(payload) + "\n") }
    function keyMatches(event, binding) {
        var parts = String(binding || "").toUpperCase().split("+")
        var key = parts.pop(), named = {"LEFT":Qt.Key_Left, "RIGHT":Qt.Key_Right, "UP":Qt.Key_Up, "DOWN":Qt.Key_Down, "SPACE":Qt.Key_Space, "ESCAPE":Qt.Key_Escape, "BACKSPACE":Qt.Key_Backspace, "RETURN":Qt.Key_Return, "ENTER":Qt.Key_Enter}
        var wantsCtrl = parts.indexOf("CTRL") >= 0, wantsShift = parts.indexOf("SHIFT") >= 0, wantsAlt = parts.indexOf("ALT") >= 0
        if (wantsCtrl !== ((event.modifiers & Qt.ControlModifier) !== 0) || wantsShift !== ((event.modifiers & Qt.ShiftModifier) !== 0) || wantsAlt !== ((event.modifiers & Qt.AltModifier) !== 0)) return false
        return named[key] !== undefined ? event.key === named[key] : key.length === 1 && event.key === key.charCodeAt(0)
    }
    function refresh() { send({op:"list", path:currentPath, hidden:showHidden, query:searchText, sort:sortKey, ascending:sortAscending}) }
    function completePath() { send({op:"complete", text:pathField.text}) }
    function select(item) { selected = item; previewIsImage = !!(item && item.image); previewImageSource = item && item.image ? "file://" + item.path : ""; previewText = item && item.image ? "" : "Select a file to preview it."; if (item) send({op:"preview", path:item.path}) }
    function isChosen(path) { for (var i = 0; i < selectedItems.length; i++) if (selectedItems[i].path === path) return true; return false }
    function isBusy(path) { for (var i = 0; i < busyPaths.length; i++) if (busyPaths[i] === path) return true; return false }
    function selectionOrCurrent() { return selectedItems.length ? selectedItems : (selected ? [selected] : []) }
    function clearSelection() { selectedItems = []; selectionAnchor = -1; notify("Selection cleared") }
    function toggleCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= entries.length) return
        var item = entries[list.currentIndex], next = []
        for (var i = 0; i < selectedItems.length; i++) if (selectedItems[i].path !== item.path) next.push(selectedItems[i])
        if (next.length === selectedItems.length) next.push(item)
        selectedItems = next; selectionAnchor = list.currentIndex; notify(selectedItems.length + " selected")
    }
    function moveBy(delta, extend) {
        if (!entries.length) return
        var nextIndex = Math.max(0, Math.min(entries.length - 1, list.currentIndex < 0 ? 0 : list.currentIndex + delta))
        if (extend) {
            if (selectionAnchor < 0) selectionAnchor = list.currentIndex < 0 ? 0 : list.currentIndex
            var start = Math.min(selectionAnchor, nextIndex), end = Math.max(selectionAnchor, nextIndex), range = []
            for (var i = start; i <= end; i++) range.push(entries[i])
            selectedItems = range
        }
        list.currentIndex = nextIndex
    }
    function enter(item) { if (item.directory) { currentPath = item.path; searchText = ""; selected = null; refresh() } else send({op:"open", path:item.path}) }
    function up() { var p = currentPath; if (p !== "/") { currentPath = p.substring(0, p.lastIndexOf("/")) || "/"; refresh() } }
    function notify(message) { notice = message; noticeTimer.restart() }
    function action(op, extra) { busyPath = selected ? selected.path : currentPath; send(Object.assign({op:op, path:selected ? selected.path : currentPath}, extra || {})) }
    function copySelected(mode) {
        var items = selectionOrCurrent()
        if (!items.length) return
        clipboardPath = items.length === 1 ? items[0].path : ""
        clipboardPaths = items.map(function(item) { return item.path })
        clipboardMode = mode
        notify((mode === "cut" ? "Cut " : "Copied ") + items.length + " item" + (items.length === 1 ? "" : "s"))
    }
    function pasteClipboard() {
        if (!clipboardPaths.length) { notify("Nothing to paste"); return }
        busyPaths = clipboardPaths
        send({op:"paste", sources:clipboardPaths, destination:currentPath, mode:clipboardMode})
    }
    function compressSelected() { if (selectionOrCurrent().length) { archiveName.text = "archive.zip"; compressDialog.open() } }
    function doCompress() { var items = selectionOrCurrent(); if (!items.length) return; busyPaths = items.map(function(item) { return item.path }); send({op:"compress", paths:busyPaths, destination:currentPath, name:archiveName.text.trim() || "archive.zip"}) }
    function uncompressSelected() { var items = selectionOrCurrent(); if (!items.length) return; busyPaths = items.map(function(item) { return item.path }); send({op:"uncompress", paths:busyPaths}) }
    function sendToLocalSend() { var items = selectionOrCurrent(); if (!items.length) { notify("Select a file or folder to send"); return }; busyPaths = items.map(function(item) { return item.path }); send({op:"localsend", paths:busyPaths}) }
    function trashSelected() { var items = selectionOrCurrent(); if (!items.length) return; busyPaths = items.map(function(item) { return item.path }); send({op:"trash", paths:busyPaths}) }
    function renameSelected() { if (selected) { renameName.text = selected.name; renameDialog.open() } }
    function prepareContext(item, index) { list.currentIndex = index; if (!isChosen(item.path)) { selectedItems = [item]; selectionAnchor = index }; select(item); contextMenu.popup() }
    function activateCurrent() {
        if (list.currentIndex < 0 || list.currentIndex >= entries.length) return
        var item = entries[list.currentIndex]
        if (item.archive) uncompressSelected()
        else enter(item)
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
    function applyConfig(data) {
        var keys = data && data.keybinds ? data.keybinds : {}
        keyParent = keys.parent || keyParent; keyOpen = keys.open || keyOpen; keyMoveDown = keys.moveDown || keyMoveDown; keyMoveUp = keys.moveUp || keyMoveUp
        keySelect = keys.select || keySelect; keyCopy = keys.copy || keyCopy; keyCut = keys.cut || keyCut; keyPaste = keys.paste || keyPaste
        keyLocalSend = keys.localSend || keyLocalSend; keyCompress = keys.compress || keyCompress; keyUncompress = keys.uncompress || keyUncompress; keyRename = keys.rename || keyRename; keyQuickPath = keys.quickPath || keyQuickPath; keyDelete = keys.delete || keyDelete; keyNewFolder = keys.newFolder || keyNewFolder; keyClearSelection = keys.clearSelection || keyClearSelection
    }
    function handle(data) {
        if (data.config !== undefined) { applyConfig(data.config); refresh() }
        else if (data.completions !== undefined) { if (data.completions.length === 1) { pathField.text = data.completions[0]; pathField.cursorPosition = pathField.text.length } else if (data.common && data.common.length > pathField.text.length) { pathField.text = data.common; pathField.cursorPosition = pathField.text.length } if (data.completions.length > 1) notify(data.completions.length + " matches") }
        else if (data.items !== undefined) { entries = data.items; if (!data.ok) notify(data.error) }
        else if (data.text !== undefined) { previewText = data.text; previewIsImage = !!data.image; previewImageSource = data.imagePath ? "file://" + data.imagePath : previewImageSource }
        else if (data.ok) { busyPath = ""; busyPaths = []; if (data.deleted) { selectedItems = []; selectionAnchor = -1 }; if (clipboardMode === "cut" && data.moved) { clipboardPath = ""; clipboardPaths = []; clipboardMode = "" }; notify("Done"); refresh() } else { busyPath = ""; busyPaths = []; notify(data.error || "Could not complete action") }
    }
    Timer { id: noticeTimer; interval: 2600 }
    Timer { id: startupRefresh; interval: 250; repeat: false; running: true; onTriggered: refresh() }
    Component.onCompleted: { send({op:"config"}); list.forceActiveFocus() }
    onCurrentPathChanged: pathField.text = currentPath
    onShowHiddenChanged: refresh()

    Shortcut { sequence: "Ctrl+L"; onActivated: pathField.forceActiveFocus() }
    Shortcut { sequence: root.keyNewFolder; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: newFolder.open() }
    Shortcut { sequence: root.keyCopy; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.copySelected("copy") }
    Shortcut { sequence: root.keyCut; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.copySelected("cut") }
    Shortcut { sequence: root.keyPaste; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.pasteClipboard() }
    Shortcut { sequence: root.keyLocalSend; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: root.sendToLocalSend() }
    Shortcut { sequence: root.keyQuickPath; enabled: !pathField.activeFocus && !searchField.activeFocus; onActivated: { pathField.forceActiveFocus(); pathField.selectAll() } }
    Shortcut { sequence: "Delete"; enabled: !confirmTrash.visible; onActivated: if (root.selectionOrCurrent().length) confirmTrash.open() }
    Shortcut { sequence: root.keyDelete; enabled: !confirmTrash.visible && !pathField.activeFocus && !searchField.activeFocus; onActivated: if (root.selectionOrCurrent().length) confirmTrash.open() }
    Shortcut { sequence: "Return"; enabled: confirmTrash.visible; onActivated: confirmTrash.accept() }
    Shortcut { sequence: "Escape"; enabled: confirmTrash.visible; onActivated: confirmTrash.reject() }
    Shortcut { sequence: root.keyClearSelection; enabled: !confirmTrash.visible; onActivated: { if (pathField.activeFocus || searchField.activeFocus) { if (searchField.activeFocus) { searchText = ""; searchField.clear() }; pathField.clearFocus(); searchField.clearFocus(); list.forceActiveFocus() } else if (selectedItems.length) root.clearSelection() } }

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
            TextField { id: pathField; Layout.fillWidth: true; text: root.currentPath; placeholderText: "Location"; onAccepted: { root.currentPath = text; root.refresh(); list.forceActiveFocus() } Keys.onPressed: function(event) { if (event.key === Qt.Key_Tab) { root.completePath(); event.accepted = true } } }
            TextField { id: searchField; Layout.preferredWidth: Style.space(220); placeholderText: "⌕  Search this folder"; onTextChanged: { root.searchText = text; root.refresh() } }
            Button { text: root.showHidden ? "Hidden on" : "Hidden"; bordered: true; onClicked: root.showHidden = !root.showHidden }
            Button { text: "＋ New folder"; bordered: true; onClicked: newFolder.open() }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Color.foreground, 0.12) }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: Style.space(14)
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: Qt.alpha(Color.foreground, 0.035); radius: Style.space(8)
                ListView { id: list; anchors.fill: parent; anchors.margins: Style.space(8); clip: true; model: root.entries; focus: true
                    onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.entries.length) root.select(root.entries[currentIndex])
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (currentIndex >= 0) root.enter(root.entries[currentIndex]); event.accepted = true }
                        else if (root.keyMatches(event, root.keyParent) || event.key === Qt.Key_H || event.key === Qt.Key_Backspace) { if (event.key === Qt.Key_H && (event.modifiers & Qt.ShiftModifier) !== 0) root.moveBy(-1, true); else root.up(); event.accepted = true }
                        else if (root.keyMatches(event, root.keyOpen) || event.key === Qt.Key_L) { if ((event.modifiers & Qt.ShiftModifier) !== 0) root.moveBy(1, true); else root.activateCurrent(); event.accepted = true }
                        else if (root.keyMatches(event, root.keyMoveDown) || event.key === Qt.Key_Down) { root.moveBy(1, (event.modifiers & Qt.ShiftModifier) !== 0); event.accepted = true }
                        else if (root.keyMatches(event, root.keyMoveUp) || event.key === Qt.Key_Up) { root.moveBy(-1, (event.modifiers & Qt.ShiftModifier) !== 0); event.accepted = true }
                        else if (event.key === Qt.Key_Right) { if ((event.modifiers & Qt.ShiftModifier) !== 0) root.moveBy(1, true); else if (currentIndex >= 0 && (root.entries[currentIndex].directory || root.entries[currentIndex].archive)) root.activateCurrent(); else root.moveBy(1, false); event.accepted = true }
                        else if (event.key === Qt.Key_Left) { root.moveBy(-1, (event.modifiers & Qt.ShiftModifier) !== 0); event.accepted = true }
                        else if (root.keyMatches(event, root.keySelect) || event.key === Qt.Key_Space || event.key === Qt.Key_S) { root.toggleCurrent(); event.accepted = true }
                        else if (root.keyMatches(event, root.keyCompress)) { root.compressSelected(); event.accepted = true }
                        else if (root.keyMatches(event, root.keyUncompress)) { root.uncompressSelected(); event.accepted = true }
                        else if (root.keyMatches(event, root.keyRename)) { root.renameSelected(); event.accepted = true }
                        else if ((event.key === Qt.Key_Delete || root.keyMatches(event, root.keyDelete)) && currentIndex >= 0) { root.select(root.entries[currentIndex]); confirmTrash.open(); event.accepted = true }
                    }
                    delegate: Rectangle { required property var modelData; required property int index; width: list.width; height: root.viewMode === 2 ? Style.space(92) : Style.space(48); radius: Style.space(6); color: root.isChosen(modelData.path) ? Qt.alpha(Color.accent, 0.22) : (root.selected && root.selected.path === modelData.path ? Qt.alpha(Color.foreground, 0.08) : "transparent"); opacity: root.clipboardMode === "cut" && root.clipboardPaths.indexOf(modelData.path) >= 0 ? 0.5 : 1
                        Row { anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(12)
                            Text { width: Style.space(28); text: root.isBusy(modelData.path) ? "…" : (root.isChosen(modelData.path) ? "✓" : (root.clipboardPaths.indexOf(modelData.path) >= 0 ? (root.clipboardMode === "cut" ? "✂" : "⧉") : (modelData.directory ? "□" : "·"))); color: root.isBusy(modelData.path) || root.isChosen(modelData.path) ? Color.accent : (modelData.directory ? Color.accent : Color.muted); font.pixelSize: Style.font.title; horizontalAlignment: Text.AlignHCenter }
                            Column { width: parent.width - Style.space(210); anchors.verticalCenter: parent.verticalCenter; Text { text: modelData.name; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight } Text { text: modelData.directory ? "Folder" : (root.formatBytes(modelData.size) + " · modified " + root.formatDate(modelData.modified)); color: Color.muted; font.pixelSize: Style.font.caption; elide: Text.ElideRight } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.directory ? "" : "↗"; color: Color.muted }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: {
                                if (mouse.button === Qt.RightButton) root.prepareContext(modelData, index)
                                else { list.currentIndex = index; root.select(modelData) }
                            }
                            onDoubleClicked: root.enter(modelData)
                        }
                    }
                }
                Text { anchors.centerIn: parent; visible: root.entries.length === 0; text: root.searchText ? "No matches" : "This folder is empty"; color: Color.muted; font.pixelSize: Style.font.body }
            }
            Rectangle { Layout.preferredWidth: Style.space(320); Layout.fillHeight: true; color: Qt.alpha(Color.foreground, 0.035); radius: Style.space(8)
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
            Text { Layout.fillWidth: true; text: root.notice || (root.selectedItems.length ? root.selectedItems.length + " selected · " + root.currentPath : root.entries.length + " items · " + root.currentPath); color: root.notice || root.selectedItems.length ? Color.accent : Color.muted; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
            Button { text: "C Compress"; enabled: root.selectionOrCurrent().length > 0; bordered: true; onClicked: root.compressSelected() }
            Button { text: "U Uncompress"; enabled: root.selectionOrCurrent().length > 0; bordered: true; onClicked: root.uncompressSelected() }
            Button { text: "Sort: " + root.sortLabel() + (root.sortAscending ? " ↑" : " ↓"); bordered: true; onClicked: root.nextSort() }
            Button { text: "⇅"; bordered: true; onClicked: { root.sortAscending = !root.sortAscending; root.refresh() } }
            Button { text: "List"; bordered: root.viewMode === 0; onClicked: root.viewMode = 0 }
            Button { text: "Compact"; bordered: root.viewMode === 1; onClicked: root.viewMode = 1 }
            Button { text: "Grid"; bordered: root.viewMode === 2; onClicked: root.viewMode = 2 }
        }
    }

    Dialog { id: newFolder; title: "New folder"; modal: true; focus: true; anchors.centerIn: Overlay.overlay; width: Style.space(420); padding: Style.space(16); Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { newFolder.reject(); event.accepted = true } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { newFolder.accept(); event.accepted = true } } background: Rectangle { color: Color.background; border.color: Qt.alpha(Color.accent, 0.55); border.width: 1; radius: Style.space(8) } header: Text { leftPadding: Style.space(16); rightPadding: Style.space(16); topPadding: Style.space(14); text: newFolder.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        TextField { id: folderName; width: Style.space(320); placeholderText: "Folder name"; onAccepted: newFolder.accept() }
        footer: Row { width: parent.width; spacing: Style.space(8); layoutDirection: Qt.RightToLeft; Button { text: "Create"; bordered: true; onClicked: newFolder.accept() } Button { text: "Cancel"; bordered: true; onClicked: newFolder.reject() } }
        onOpened: Qt.callLater(function() { folderName.forceActiveFocus(); folderName.selectAll() })
        onAccepted: { if (folderName.text.trim()) root.action("mkdir", {path:root.currentPath, name:folderName.text.trim()}); folderName.text = "" }
    }
    Dialog { id: renameDialog; title: "Rename"; modal: true; focus: true; anchors.centerIn: Overlay.overlay; width: Style.space(420); padding: Style.space(16); Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { renameDialog.reject(); event.accepted = true } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { renameDialog.accept(); event.accepted = true } } background: Rectangle { color: Color.background; border.color: Qt.alpha(Color.accent, 0.55); border.width: 1; radius: Style.space(8) } header: Text { leftPadding: Style.space(16); rightPadding: Style.space(16); topPadding: Style.space(14); text: renameDialog.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        TextField { id: renameName; width: Style.space(320); text: root.selected ? root.selected.name : ""; onAccepted: renameDialog.accept() }
        footer: Row { width: parent.width; spacing: Style.space(8); layoutDirection: Qt.RightToLeft; Button { text: "Rename"; bordered: true; onClicked: renameDialog.accept() } Button { text: "Cancel"; bordered: true; onClicked: renameDialog.reject() } }
        onAccepted: { if (renameName.text.trim() && root.selected) root.action("rename", {name:renameName.text.trim()}); }
    }
    Dialog { id: confirmTrash; title: "Move to Trash?"; modal: true; focus: true; anchors.centerIn: Overlay.overlay; width: Style.space(420); padding: Style.space(20); background: Rectangle { color: Color.background; border.color: Qt.alpha(Color.accent, 0.55); border.width: 1; radius: Style.space(8) } header: Text { leftPadding: Style.space(20); rightPadding: Style.space(20); topPadding: Style.space(16); bottomPadding: Style.space(4); text: confirmTrash.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        Text { width: parent.width; height: Style.space(34); verticalAlignment: Text.AlignVCenter; text: root.selectionOrCurrent().length > 1 ? "Move " + root.selectionOrCurrent().length + " items to Trash?" : (root.selected ? "Move “" + root.selected.name + "” to Trash?" : "Move this item to Trash?"); color: Color.foreground; wrapMode: Text.WordWrap }
        footer: DialogButtonBox { id: confirmTrashButtons; width: parent.width; height: Style.space(48); padding: Style.space(8); alignment: Qt.AlignRight; standardButtons: DialogButtonBox.Ok | DialogButtonBox.Cancel; background: Rectangle { color: "transparent" }
            onAccepted: confirmTrash.accept()
            onRejected: confirmTrash.reject()
        }
        Component.onCompleted: { var ok = confirmTrashButtons.standardButton(DialogButtonBox.Ok); var cancel = confirmTrashButtons.standardButton(DialogButtonBox.Cancel); ok.text = "Move to Trash"; cancel.text = "Cancel"; ok.font.family = Style.font.family; cancel.font.family = Style.font.family; ok.background = themedDialogButtonBackground.createObject(ok); cancel.background = themedDialogButtonBackground.createObject(cancel) }
        onOpened: Qt.callLater(function() { confirmTrashButtons.standardButton(DialogButtonBox.Ok).forceActiveFocus() })
        onAccepted: root.trashSelected()
    }
    Component { id: themedDialogButtonBackground
        Rectangle { implicitWidth: Style.space(112); implicitHeight: Style.space(36); radius: Style.space(18); color: parent && parent.down ? Qt.alpha(Color.accent, 0.28) : (parent && parent.hovered ? Qt.alpha(Color.accent, 0.12) : "transparent"); border.color: Color.accent; border.width: 1 }
    }
    Dialog { id: compressDialog; title: "Compress selection"; modal: true; focus: true; anchors.centerIn: Overlay.overlay; width: Style.space(420); padding: Style.space(16); Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { compressDialog.reject(); event.accepted = true } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { compressDialog.accept(); event.accepted = true } } background: Rectangle { color: Color.background; border.color: Qt.alpha(Color.accent, 0.55); border.width: 1; radius: Style.space(8) } header: Text { leftPadding: Style.space(16); rightPadding: Style.space(16); topPadding: Style.space(14); text: compressDialog.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        TextField { id: archiveName; width: Style.space(320); text: "archive.zip"; placeholderText: "Archive filename"; onAccepted: compressDialog.accept() }
        onOpened: { archiveName.forceActiveFocus(); archiveName.selectAll() }
        footer: Row { width: parent.width; spacing: Style.space(8); layoutDirection: Qt.RightToLeft; Button { text: "Compress"; bordered: true; onClicked: compressDialog.accept() } Button { text: "Cancel"; bordered: true; onClicked: compressDialog.reject() } }
        onAccepted: root.doCompress()
    }
    Menu { id: contextMenu
        MenuItem { text: "Open"; enabled: !!root.selected; onTriggered: root.activateCurrent() }
        MenuItem { text: "Rename"; enabled: !!root.selected; onTriggered: root.renameSelected() }
        MenuSeparator {}
        MenuItem { text: "Copy"; enabled: root.selectionOrCurrent().length > 0; onTriggered: root.copySelected("copy") }
        MenuItem { text: "Cut"; enabled: root.selectionOrCurrent().length > 0; onTriggered: root.copySelected("cut") }
        MenuItem { text: "Paste"; enabled: root.clipboardPaths.length > 0; onTriggered: root.pasteClipboard() }
        MenuItem { text: "Send with LocalSend"; enabled: root.selectionOrCurrent().length > 0; onTriggered: root.sendToLocalSend() }
        MenuSeparator {}
        MenuItem { text: "Compress…"; enabled: root.selectionOrCurrent().length > 0; onTriggered: root.compressSelected() }
        MenuItem { text: "Uncompress"; enabled: root.selectionOrCurrent().length > 0; onTriggered: root.uncompressSelected() }
        MenuItem { text: "Move to Trash"; enabled: root.selectionOrCurrent().length > 0; onTriggered: confirmTrash.open() }
    }
}
