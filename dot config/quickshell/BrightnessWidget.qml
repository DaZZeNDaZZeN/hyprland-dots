import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: brightnessControl
    width: brightnessButton.width
    height: 30

    required property var panelWindow
    property var palette

    property int currentBrightness: 50
    property int scrollStep: 5

    function updateBrightness(val) {
        brightnessControl.currentBrightness = val;
        Quickshell.execDetached(["brightnessctl", "set", val + "%"]);
    }

    Timer {
        id: brightnessPoller
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: brightnessReader.running = true
    }

    Process {
        id: brightnessReader
        command: ["sh", "-c", "if command -v brightnessctl >/dev/null; then brightnessctl -m | cut -d, -f4 | tr -d '%'; else echo 50; fi"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let output = text.trim();
                let parsed = parseInt(output);
                if (!isNaN(parsed)) {
                    brightnessControl.currentBrightness = parsed;
                }
            }
        }
    }

    Rectangle {
        id: brightnessButton
        width: 68
        height: 28
        radius: 14
        color: brightnessButtonMouseArea.containsMouse ? brightnessControl.palette.secondaryBg : brightnessControl.palette.bg
        border.color: brightnessPopup.visible ? brightnessControl.palette.main : (brightnessButtonMouseArea.containsMouse ? brightnessControl.palette.text : brightnessControl.palette.secondaryBg)
        border.width: brightnessPopup.visible ? 2.0 : 1.2

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Image {
                id: brightnessIcon
                width: 14
                height: 14
                sourceSize.width: 14
                sourceSize.height: 14
                smooth: true
                anchors.verticalCenter: parent.verticalCenter
                source: {
                    let strokeColor = encodeURIComponent(brightnessControl.palette.main);
                    let hoverColor = encodeURIComponent(brightnessControl.palette.text);
                    let activeColor = brightnessButtonMouseArea.containsMouse ? hoverColor : strokeColor;
                    let rayLength = 1.2 + (brightnessControl.currentBrightness / 100.0) * 3.8;
                    return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + activeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='4'/><g transform='rotate(0 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(45 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(90 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(135 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(180 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(225 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(270 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g><g transform='rotate(315 12 12)'><line x1='12' y1='6.5' x2='12' y2='" + (6.5 - rayLength) + "' /></g></svg>";
                }
            }

            Text {
                text: brightnessControl.currentBrightness + "%"
                color: brightnessControl.palette.text
                font.pixelSize: 11
                font.bold: true
                font.family: "Noto Sans"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: brightnessButtonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            onClicked: {
                brightnessPopup.visible = !brightnessPopup.visible;
                if (brightnessPopup.visible) {
                    brightnessReader.running = true;
                }
            }

            onWheel: wheel => {
                let target = brightnessControl.currentBrightness;
                if (wheel.angleDelta.y > 0) {
                    target = Math.min(100, target + brightnessControl.scrollStep);
                } else if (wheel.angleDelta.y < 0) {
                    target = Math.max(1, target - brightnessControl.scrollStep);
                }
                brightnessControl.updateBrightness(target);
            }
        }
    }

    PopupWindow {
        id: brightnessPopup
        anchor.window: brightnessControl.panelWindow
        anchor.item: brightnessButton
        anchor.gravity: Edges.Bottom
        anchor.edges: Edges.Bottom
        anchor.margins.top: 8
        width: 70
        height: 190
        visible: false
        grabFocus: true
        surfaceFormat.opaque: false
        color: "#00000000"

        Rectangle {
            anchors.fill: parent
            color: brightnessControl.palette.bg
            border.color: brightnessControl.palette.main
            border.width: 1.5
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Slider {
                    id: brightnessSlider
                    orientation: Qt.Vertical
                    from: 1
                    to: 100
                    value: brightnessControl.currentBrightness
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 120
                    Layout.preferredWidth: 32

                    background: Rectangle {
                        implicitWidth: 5
                        implicitHeight: 120
                        x: brightnessSlider.leftPadding + brightnessSlider.availableWidth / 2 - width / 2
                        y: brightnessSlider.topPadding
                        radius: 2.5
                        color: brightnessControl.palette.secondaryBg

                        Rectangle {
                            width: parent.width
                            height: (1.0 - brightnessSlider.visualPosition) * parent.height
                            y: parent.height - height
                            color: brightnessControl.palette.main
                            radius: 2.5
                        }
                    }

                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.availableWidth / 2 - width / 2
                        y: brightnessSlider.topPadding + brightnessSlider.visualPosition * (brightnessSlider.availableHeight - height)
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: brightnessSlider.pressed ? brightnessControl.palette.text : brightnessControl.palette.darkerText
                        border.color: brightnessControl.palette.main
                        border.width: brightnessSlider.hovered ? 2 : 0

                        Behavior on border.width {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }

                    onMoved: {
                        brightnessControl.updateBrightness(Math.round(value));
                    }
                }

                Text {
                    text: brightnessControl.currentBrightness + "%"
                    color: brightnessControl.palette.text
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Noto Sans"
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true

                onWheel: wheel => {
                    let target = brightnessControl.currentBrightness;
                    if (wheel.angleDelta.y > 0) {
                        target = Math.min(100, target + brightnessControl.scrollStep);
                    } else if (wheel.angleDelta.y < 0) {
                        target = Math.max(1, target - brightnessControl.scrollStep);
                    }
                    brightnessControl.updateBrightness(target);
                }
            }
        }
    }
}