import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: clipboardWindow

    property var palette
    property int topPanelHeightWithMargins

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: -topPanelHeightWithMargins
    }

    visible: false
    color: "#D9121212" // Translucent dark overlay backdrop

    exclusionMode: Quickshell.ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Toggle window visibility and refresh state
    function toggle() {
        visible = !visible;
        if (visible) {
            historyLoader.start();
            listView.forceActiveFocus();
        }
    }

    ListModel {
        id: clipboardModel
    }

    // Background process to list stored clipboard items
    Process {
        id: listProcess
        command: ["python3", Quickshell.shellPath("clip_daemon.py"), "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var history = JSON.parse(this.text);
                    clipboardModel.clear();
                    for (var i = 0; i < history.length; i++) {
                        clipboardModel.append(history[i]);
                    }
                    if (listView.currentIndex < 0 || listView.currentIndex >= clipboardModel.count) {
                        listView.currentIndex = 0;
                    }
                } catch (e) {
                    console.log("Error parsing clipboard history: " + e);
                }
            }
        }
    }

    function copyItem(id) {
        Quickshell.execDetached(["python3", Quickshell.shellPath("clip_daemon.py"), "copy", id.toString()]);
        clipboardWindow.visible = false;
    }

    function deleteItem(id) {
        Quickshell.execDetached(["python3", Quickshell.shellPath("clip_daemon.py"), "delete", id.toString()]);
        historyLoader.start();
    }

    function clearAll() {
        Quickshell.execDetached(["python3", Quickshell.shellPath("clip_daemon.py"), "clear"]);
        historyLoader.start();
    }

    Timer {
        id: historyLoader
        interval: 80
        repeat: false
        onTriggered: {
            listProcess.running = true;
        }
    }

    // Dismiss overlay on background tap
    MouseArea {
        anchors.fill: parent
        onClicked: clipboardWindow.visible = false
    }

    Rectangle {
        id: mainCard
        width: 600
        height: 650
        anchors.centerIn: parent
        color: clipboardWindow.palette.bg
        radius: 16
        border.color: clipboardWindow.palette.main
        border.width: 3

        // Stop mouse clicks from closing the card
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // --- Header Layout ---
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "📋 CLIPBOARD HISTORY"
                        font.pixelSize: 20
                        font.bold: true
                        color: clipboardWindow.palette.main
                    }
                    Text {
                        text: "Select an item to copy back to the clipboard"
                        font.pixelSize: 12
                        color: clipboardWindow.palette.darkerText
                    }
                }

                // Clear All Button
                Rectangle {
                    width: 100
                    height: 35
                    radius: 8
                    color: clearMouse.containsMouse ? clipboardWindow.palette.accent : clipboardWindow.palette.secondaryBg
                    border.color: clearMouse.containsMouse ? "transparent" : clipboardWindow.palette.accent
                    border.width: 1
                    Layout.alignment: Qt.AlignRight

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: clipboardWindow.clearAll()
                    }
                }
            }

            // --- Scrollable list ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: clipboardWindow.palette.darkerkBg
                radius: 12
                border.color: clipboardWindow.palette.accent
                border.width: 1
                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: 8
                    model: clipboardModel
                    spacing: 6
                    focus: true
                    keyNavigationEnabled: true
                    clip: true

                    // Keyboard actions
                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            currentIndex--;
                        }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) {
                            currentIndex++;
                        }
                    }
                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            copyItem(model.get(currentIndex).id);
                        }
                    }
                    Keys.onEscapePressed: {
                        clipboardWindow.visible = false;
                    }

                    // --- Scrollbar UI ---
                    ScrollBar.vertical: ScrollBar {
                        active: true
                    }

                    // --- List Delegate ---
                    delegate: Item {
                        width: listView.width
                        height: 75

                        Rectangle {
                            id: itemCard
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: index === listView.currentIndex ? clipboardWindow.palette.secondaryBg : clipboardWindow.palette.bg
                            border.color: index === listView.currentIndex ? clipboardWindow.palette.main : "transparent"
                            border.width: 2

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: listView.currentIndex = index
                                onClicked: clipboardWindow.copyItem(id)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                // Icon / Image Area
                                Rectangle {
                                    width: 55
                                    height: 55
                                    radius: 6
                                    color: clipboardWindow.palette.bg
                                    clip: true
                                    Layout.alignment: Qt.AlignVCenter

                                    // Display actual image thumbnail if type is image
                                    Image {
                                        visible: type === "image"
                                        source: type === "image" ? "file://" + value : ""
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    // Otherwise fallback to text symbols
                                    Text {
                                        visible: type !== "image"
                                        anchors.centerIn: parent
                                        text: type === "files" ? "📁" : "📝"
                                        font.pixelSize: 24
                                    }
                                }

                                // Text details
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: type === "files" ? "FILES" : (type === "image" ? "IMAGE" : "TEXT")
                                            font.bold: true
                                            color: index === listView.currentIndex ? clipboardWindow.palette.text: clipboardWindow.palette.main
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            text: "• " + timestamp
                                            color: clipboardWindow.palette.darkerText
                                            font.pixelSize: 10
                                        }
                                    }

                                    Text {
                                        text: preview
                                        color: clipboardWindow.palette.text
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        maximumLineCount: 2
                                    }
                                }

                                // Delete single item button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: deleteMouse.containsMouse ? clipboardWindow.palette.accent : (index === listView.currentIndex ? clipboardWindow.palette.bg : clipboardWindow.palette.darkerkBg)
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🗑"
                                        color: "white"
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: deleteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: clipboardWindow.deleteItem(id)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state notification
                Text {
                    anchors.centerIn: parent
                    text: "No history found"
                    color: clipboardWindow.palette.darkerText
                    font.pixelSize: 16
                    visible: clipboardModel.count === 0
                }
            }

            // --- Action Tips Footer ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Text {
                    text: "↑↓ Navigate  •  Enter Copy  •  Esc Close"
                    font.pixelSize: 11
                    color: clipboardWindow.palette.darkerText
                    Layout.fillWidth: true
                }

                Text {
                    text: "Total: " + clipboardModel.count + " / 20"
                    font.pixelSize: 11
                    color: clipboardWindow.palette.main
                    font.bold: true
                }
            }
        }
    }
}
