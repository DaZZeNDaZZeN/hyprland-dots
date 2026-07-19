import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: volumeControl
    width: soundButton.width
    height: 30

    required property var panelWindow
    property var palette

    property int currentVolume: 50
    property bool isMuted: false
    property int scrollStep: 5

    function updateSystemVolume(val) {
        volumeControl.currentVolume = val;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val + "%"]);

        if (val > 0 && isMuted) {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
            isMuted = false;
        } else if (val === 0 && !isMuted) {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"]);
            isMuted = true;
        }
    }

    // Component.onCompleted triggers a query immediately when the bar loads up
    Component.onCompleted: {
        volumeQuery.running = true;
    }

    // Listens for active sink events reactively and triggers instant updates
    Process {
        id: volumeMonitor
        command: ["sh", "-c", "pactl subscribe | grep --line-buffered \"'change' on sink\""]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                volumeQuery.running = true;
            }
        }
    }

    // Reusable fast-query helper process to fetch state metrics
    Process {
        id: volumeQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let output = text.trim();
                if (output.startsWith("Volume:")) {
                    let isMutedState = output.includes("[MUTED]");
                    volumeControl.isMuted = isMutedState;

                    let parts = output.split(" ");
                    let volFloat = parseFloat(parts[1]);
                    volumeControl.currentVolume = Math.round(volFloat * 100);
                }
            }
        }
    }

    Rectangle {
        id: soundButton
        width: 68
        height: 28
        radius: 14
        color: soundButtonMouseArea.containsMouse ? volumeControl.palette.surface_container_low : volumeControl.palette.surface_container
        border.color: volumePopup.visible ? volumeControl.palette.primary : (soundButtonMouseArea.containsMouse ? volumeControl.palette.on_surface : volumeControl.palette.secondary)
        border.width: volumePopup.visible ? 2.0 : 1.0

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
                id: volumeIcon
                width: 14
                height: 14
                sourceSize.width: 14
                sourceSize.height: 14
                smooth: true
                anchors.verticalCenter: parent.verticalCenter

                source: {
                    let strokeColor = volumeControl.isMuted ? encodeURIComponent(volumeControl.palette.secondary) : encodeURIComponent(volumeControl.palette.primary);
                    let hoverColor = encodeURIComponent(volumeControl.palette.on_surface);
                    let activeColor = soundButtonMouseArea.containsMouse ? hoverColor : strokeColor;
                    if (volumeControl.isMuted || volumeControl.currentVolume === 0) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM23 9l-6 6M17 9l6 6'/></svg>";
                    } else if (volumeControl.currentVolume <= 50) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + activeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM15.54 8.46a5 5 0 0 1 0 7.07'/></svg>";
                    } else {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + activeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14'/></svg>";
                    }
                }
            }

            Text {
                text: volumeControl.isMuted ? "MUT" : volumeControl.currentVolume + "%"
                color: volumeControl.isMuted ? volumeControl.palette.secondary : volumeControl.palette.on_surface
                font.pixelSize: 11
                font.bold: true
                font.family: "Noto Sans"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: soundButtonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Qt.openUrlExternally("file:///usr/bin/pavucontrol");
                } else if (mouse.button === Qt.LeftButton) {
                    volumePopup.visible = !volumePopup.visible;
                }
            }

            onWheel: wheel => {
                let targetVolume = volumeControl.currentVolume;
                if (wheel.angleDelta.y > 0) {
                    targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                } else if (wheel.angleDelta.y < 0) {
                    targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                }
                volumeControl.updateSystemVolume(targetVolume);
            }
        }
    }

    PopupWindow {
        id: volumePopup
        anchor.window: volumeControl.panelWindow
        anchor.item: soundButton
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
            color: volumeControl.palette.surface_container
            border.color: volumeControl.palette.primary
            border.width: 1.5
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Slider {
                    id: verticalSlider
                    orientation: Qt.Vertical
                    from: 0
                    to: 100
                    value: volumeControl.currentVolume
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 120
                    Layout.preferredWidth: 32

                    background: Rectangle {
                        implicitWidth: 5
                        implicitHeight: 120
                        x: verticalSlider.leftPadding + verticalSlider.availableWidth / 2 - width / 2
                        y: verticalSlider.topPadding
                        radius: 2.5
                        color: volumeControl.palette.surface_container_low

                        Rectangle {
                            width: parent.width
                            height: (1.0 - verticalSlider.visualPosition) * parent.height
                            y: parent.height - height
                            color: volumeControl.palette.primary
                            radius: 2.5
                        }
                    }

                    handle: Rectangle {
                        x: verticalSlider.leftPadding + verticalSlider.availableWidth / 2 - width / 2
                        y: verticalSlider.topPadding + verticalSlider.visualPosition * (verticalSlider.availableHeight - height)
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: verticalSlider.pressed ? volumeControl.palette.on_surface : volumeControl.palette.primary
                        border.color: volumeControl.palette.primary
                        border.width: verticalSlider.hovered ? 2 : 0

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
                        volumeControl.updateSystemVolume(Math.round(value));
                    }
                }

                Text {
                    text: volumeControl.isMuted ? "MUTED" : volumeControl.currentVolume + "%"
                    color: volumeControl.isMuted ? volumeControl.palette.secondary : volumeControl.palette.on_surface
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
                    let targetVolume = volumeControl.currentVolume;
                    if (wheel.angleDelta.y > 0) {
                        targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                    } else if (wheel.angleDelta.y < 0) {
                        targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                    }
                    volumeControl.updateSystemVolume(targetVolume);
                }
            }
        }
    }
}