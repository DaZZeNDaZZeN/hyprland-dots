//@ pragma UseQApplication

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ShellRoot {
    id: root

    property color bgColor: '#1a1a1a'
    property color bgBorderColor: "#9044FF"
    property real bgBorderWidth: 3.0

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Wallpaper {
        topPanelHeightWithMargins: panelWindow.heightWithMargin
    }

    PanelWindow {
        id: panelWindow
        surfaceFormat.opaque: false
        color: "#00000000"
        anchors {
            left: true
            top: true
            right: true
        }
        margins {
            top: 5
            left: 10
            right: 10
        }
        implicitHeight: 40
        property int heightWithMargin: implicitHeight + margins.top

        // --- Background Shapes ---
        Rectangle {
            width: 40
            height: 40
            radius: width * 0.5
            anchors {
                left: bgRect.left
                leftMargin: -20
            }
            color: bgColor
            border.color: bgBorderColor
            border.width: bgBorderWidth
        }
        Rectangle {
            width: 40
            height: 40
            radius: width * 0.5
            anchors {
                left: bgRect.right
                leftMargin: -20
            }
            color: bgColor
            border.color: bgBorderColor
            border.width: bgBorderWidth
        }
        Rectangle {
            id: bgRect
            color: bgColor
            anchors.fill: parent
            anchors {
                leftMargin: 40
                rightMargin: 40
            }
            border.color: bgBorderColor
            border.width: bgBorderWidth
        }
        Rectangle { // left compensation
            color: bgColor
            width: 40
            height: 40 - bgBorderWidth * 2
            anchors {
                left: bgRect.left
                verticalCenter: bgRect.verticalCenter
            }
        }
        Rectangle { // right compensation
            color: bgColor
            width: 40
            height: 40 - bgBorderWidth * 2
            anchors {
                left: bgRect.right
                leftMargin: -40
                verticalCenter: bgRect.verticalCenter
            }
        }

        // --- Panel Content Layout ---

        // Left Side Content
        Row {
            id: leftContentRow
            spacing: 15
            anchors {
                left: parent.left
                leftMargin: 40
                verticalCenter: parent.verticalCenter
            }

            BrightnessWidget {
                panelWindow: panelWindow
            }
        }

        // Center Content
        Row {
            spacing: 20
            anchors.centerIn: parent

            Text {
                id: datetimeText
                font.pixelSize: 18
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "hh:mm:ss | MM.dd.yyyy")
            }

            Row {
                id: workspaceButtons
                spacing: 10
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
                    Item {
                        width: 25
                        height: 25
                        Rectangle {
                            id: customButton
                            anchors.fill: parent
                            color: Hyprland.focusedWorkspace.id == parseInt(modelData) ? "#4A90E2" : "#444444"
                            radius: width / 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 12
                                color: "white"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData + " })")
                        }
                    }
                }
            }
        }

        // Right Side Content
        Row {
            id: rightContentRow
            spacing: 15
            anchors {
                right: parent.right
                rightMargin: 40
                verticalCenter: parent.verticalCenter
            }

            // System Tray
            Row {
                id: sysTray
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        width: 24
                        height: 24
                        Image {
                            anchors.fill: parent
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    var globalCoords = mapToGlobal(mouse.x, mouse.y);
                                    modelData.display(panelWindow, globalCoords.x, globalCoords.y);
                                } else {
                                    modelData.activate();
                                }
                            }
                        }
                    }
                }
            }

            BatteryWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            VolumeWidget {
                panelWindow: panelWindow
            }
        }
    }
}
