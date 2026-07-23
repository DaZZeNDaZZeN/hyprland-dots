import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: volumeControl
    width: soundButton.width
    height: 30

    required property var panelWindow
    property var palette

    // Bind directly to Pipewire default audio sink and source
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Track all audio nodes so volume, mute state, and metadata update reactively
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio !== null)
    }

    // Reactively compute Master volume & mute
    readonly property int currentVolume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool isMuted: sink?.audio?.muted ?? false

    // Reactively compute Microphone volume & mute
    readonly property int micVolume: Math.round((source?.audio?.volume ?? 0) * 100)
    readonly property bool isMicMuted: source?.audio?.muted ?? false

    // Filter application streams dynamically from Pipewire node list
    readonly property var appStreams: Pipewire.nodes.values.filter(node => node.audio !== null && node.isStream)

    property int scrollStep: 5

    function updateSystemVolume(val) {
        if (sink && sink.audio) {
            let clamped = Math.max(0, Math.min(100, val));
            sink.audio.volume = clamped / 100.0;
            if (clamped > 0 && sink.audio.muted)
                sink.audio.muted = false;
            else if (clamped === 0 && !sink.audio.muted)
                sink.audio.muted = true;
        }
    }

    function toggleMasterMute() {
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function updateMicVolume(val) {
        if (source && source.audio) {
            let clamped = Math.max(0, Math.min(100, val));
            source.audio.volume = clamped / 100.0;
            if (clamped > 0 && source.audio.muted)
                source.audio.muted = false;
            else if (clamped === 0 && !source.audio.muted)
                source.audio.muted = true;
        }
    }

    function toggleMicMute() {
        if (source && source.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }

    Rectangle {
        id: soundButton
        width: 68
        height: 28
        radius: 14
        color: soundButtonMouseArea.containsMouse ? volumeControl.palette.surface_container_low : volumeControl.palette.surface_container
        border.color: mixerPopup.visible ? volumeControl.palette.primary : (soundButtonMouseArea.containsMouse ? volumeControl.palette.on_surface : volumeControl.palette.secondary)
        border.width: mixerPopup.visible ? 2.0 : 1.0

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

            onClicked: mixerPopup.visible = !mixerPopup.visible

            onWheel: wheel => {
                let targetVolume = volumeControl.currentVolume;
                if (wheel.angleDelta.y > 0)
                    targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                else if (wheel.angleDelta.y < 0)
                    targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                volumeControl.updateSystemVolume(targetVolume);
            }
        }
    }

    PopupWindow {
        id: mixerPopup
        anchor.window: volumeControl.panelWindow
        anchor.item: soundButton
        anchor.gravity: Edges.Bottom
        anchor.edges: Edges.Bottom
        anchor.margins.top: 8
        width: 340
        implicitHeight: mixerLayout.implicitHeight + 28
        height: Math.min(460, implicitHeight)
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
                id: mixerLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Volume Mixer"
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "Noto Sans"
                        color: volumeControl.palette.on_surface
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: volumeControl.palette.outline_variant
                }

                // Master Output
                Item {
                    Layout.fillWidth: true
                    implicitHeight: masterColumn.implicitHeight

                    ColumnLayout {
                        id: masterColumn
                        anchors.fill: parent
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: masterMuteArea.containsMouse ? volumeControl.palette.surface_container_high : volumeControl.palette.surface_container_low

                                Image {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    smooth: true
                                    source: {
                                        let strokeColor = volumeControl.isMuted ? encodeURIComponent(volumeControl.palette.error) : encodeURIComponent(volumeControl.palette.primary);
                                        if (volumeControl.isMuted || volumeControl.currentVolume === 0) {
                                            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM23 9l-6 6M17 9l6 6'/></svg>";
                                        } else {
                                            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14'/></svg>";
                                        }
                                    }
                                }

                                MouseArea {
                                    id: masterMuteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: volumeControl.toggleMasterMute()
                                }
                            }

                            Text {
                                text: "Master Volume"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Noto Sans"
                                color: volumeControl.palette.on_surface
                                Layout.fillWidth: true
                            }

                            Text {
                                text: volumeControl.isMuted ? "MUTED" : volumeControl.currentVolume + "%"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Noto Sans"
                                color: volumeControl.isMuted ? volumeControl.palette.error : volumeControl.palette.primary
                            }
                        }

                        Slider {
                            id: masterSlider
                            Layout.fillWidth: true
                            implicitHeight: 30
                            from: 0
                            to: 100
                            value: volumeControl.currentVolume

                            background: Rectangle {
                                x: masterSlider.leftPadding
                                y: masterSlider.topPadding + masterSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: masterSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: volumeControl.palette.surface_container_low

                                Rectangle {
                                    width: masterSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: volumeControl.isMuted ? volumeControl.palette.outline : volumeControl.palette.primary
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: masterSlider.leftPadding + masterSlider.visualPosition * (masterSlider.availableWidth - width)
                                y: masterSlider.topPadding + masterSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: masterSlider.pressed ? volumeControl.palette.on_surface : volumeControl.palette.primary
                                border.color: volumeControl.palette.primary
                                border.width: masterSlider.hovered ? 2 : 0
                            }

                            onMoved: volumeControl.updateSystemVolume(Math.round(value))
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            let targetVolume = volumeControl.currentVolume;
                            if (wheel.angleDelta.y > 0)
                                targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                            else if (wheel.angleDelta.y < 0)
                                targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                            volumeControl.updateSystemVolume(targetVolume);
                        }
                    }
                }

                // Microphone Input
                Item {
                    Layout.fillWidth: true
                    implicitHeight: micColumn.implicitHeight

                    ColumnLayout {
                        id: micColumn
                        anchors.fill: parent
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: micMuteArea.containsMouse ? volumeControl.palette.surface_container_high : volumeControl.palette.surface_container_low

                                Image {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    smooth: true
                                    source: {
                                        let strokeColor = volumeControl.isMicMuted ? encodeURIComponent(volumeControl.palette.error) : encodeURIComponent(volumeControl.palette.primary);
                                        if (volumeControl.isMicMuted || volumeControl.micVolume === 0) {
                                            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='1' y1='1' x2='23' y2='23'/><path d='M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V5a3 3 0 0 0-5.94-.6'/><path d='M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23'/><line x1='12' y1='19' x2='12' y2='22'/></svg>";
                                        } else {
                                            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3z'/><path d='M19 10v2a7 7 0 0 1-14 0v-2'/><line x1='12' y1='19' x2='12' y2='22'/></svg>";
                                        }
                                    }
                                }

                                MouseArea {
                                    id: micMuteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: volumeControl.toggleMicMute()
                                }
                            }

                            Text {
                                text: "Microphone"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Noto Sans"
                                color: volumeControl.palette.on_surface
                                Layout.fillWidth: true
                            }

                            Text {
                                text: volumeControl.isMicMuted ? "MUTED" : volumeControl.micVolume + "%"
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Noto Sans"
                                color: volumeControl.isMicMuted ? volumeControl.palette.error : volumeControl.palette.primary
                            }
                        }

                        Slider {
                            id: micSlider
                            Layout.fillWidth: true
                            implicitHeight: 30
                            from: 0
                            to: 100
                            value: volumeControl.micVolume

                            background: Rectangle {
                                x: micSlider.leftPadding
                                y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: micSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: volumeControl.palette.surface_container_low

                                Rectangle {
                                    width: micSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: volumeControl.isMicMuted ? volumeControl.palette.outline : volumeControl.palette.primary
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
                                y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
                                implicitWidth: 16
                                implicitHeight: 16
                                radius: 8
                                color: micSlider.pressed ? volumeControl.palette.on_surface : volumeControl.palette.primary
                                border.color: volumeControl.palette.primary
                                border.width: micSlider.hovered ? 2 : 0
                            }

                            onMoved: volumeControl.updateMicVolume(Math.round(value))
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            let targetVolume = volumeControl.micVolume;
                            if (wheel.angleDelta.y > 0)
                                targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                            else if (wheel.angleDelta.y < 0)
                                targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                            volumeControl.updateMicVolume(targetVolume);
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: volumeControl.palette.outline_variant
                }

                // Applications Section
                Text {
                    text: "Applications"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Noto Sans"
                    color: volumeControl.palette.on_surface
                }

                ScrollView {
                    id: appScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 60
                    clip: true

                    ColumnLayout {
                        width: appScrollView.availableWidth
                        spacing: 12

                        Text {
                            visible: volumeControl.appStreams.length === 0
                            text: "No active application audio streams"
                            font.pixelSize: 11
                            font.italic: true
                            font.family: "Noto Sans"
                            color: volumeControl.palette.on_surface_variant
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                        }

                        Repeater {
                            model: volumeControl.appStreams

                            delegate: Item {
                                id: appDelegate
                                Layout.fillWidth: true
                                implicitHeight: appColumn.implicitHeight
                                height: implicitHeight

                                property var streamNode: modelData
                                property bool isAppMuted: streamNode.audio?.muted ?? false
                                property int appVolume: Math.round((streamNode.audio?.volume ?? 0) * 100)
                                property string appName: streamNode.properties["application.name"] || streamNode.properties["media.name"] || streamNode.description || streamNode.name || ("Application " + streamNode.id)

                                ColumnLayout {
                                    id: appColumn
                                    anchors.fill: parent
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: appMuteArea.containsMouse ? volumeControl.palette.surface_container_high : volumeControl.palette.surface_container_low

                                            Image {
                                                anchors.centerIn: parent
                                                width: 14
                                                height: 14
                                                smooth: true
                                                source: {
                                                    let strokeColor = appDelegate.isAppMuted ? encodeURIComponent(volumeControl.palette.error) : encodeURIComponent(volumeControl.palette.primary);
                                                    if (appDelegate.isAppMuted || appDelegate.appVolume === 0) {
                                                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM23 9l-6 6M17 9l6 6'/></svg>";
                                                    } else {
                                                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M11 5L6 9H2v6h4l5 4V5zM15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14'/></svg>";
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: appMuteArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appDelegate.streamNode && appDelegate.streamNode.audio) {
                                                        appDelegate.streamNode.audio.muted = !appDelegate.streamNode.audio.muted;
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: appDelegate.appName
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Noto Sans"
                                            color: volumeControl.palette.on_surface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: appDelegate.isAppMuted ? "MUTED" : appDelegate.appVolume + "%"
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Noto Sans"
                                            color: appDelegate.isAppMuted ? volumeControl.palette.error : volumeControl.palette.primary
                                        }
                                    }

                                    Slider {
                                        id: appSlider
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        from: 0
                                        to: 100
                                        value: appDelegate.appVolume

                                        background: Rectangle {
                                            x: appSlider.leftPadding
                                            y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                            implicitWidth: 200
                                            implicitHeight: 6
                                            width: appSlider.availableWidth
                                            height: implicitHeight
                                            radius: 3
                                            color: volumeControl.palette.surface_container_low

                                            Rectangle {
                                                width: appSlider.visualPosition * parent.width
                                                height: parent.height
                                                color: appDelegate.isAppMuted ? volumeControl.palette.outline : volumeControl.palette.primary
                                                radius: 3
                                            }
                                        }

                                        handle: Rectangle {
                                            x: appSlider.leftPadding + appSlider.visualPosition * (appSlider.availableWidth - width)
                                            y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                            implicitWidth: 16
                                            implicitHeight: 16
                                            radius: 8
                                            color: appSlider.pressed ? volumeControl.palette.on_surface : volumeControl.palette.primary
                                            border.color: volumeControl.palette.primary
                                            border.width: appSlider.hovered ? 2 : 0
                                        }

                                        onMoved: {
                                            if (appDelegate.streamNode && appDelegate.streamNode.audio) {
                                                appDelegate.streamNode.audio.volume = Math.round(value) / 100.0;
                                            }
                                        }
                                    }
                                }

                                // MouseWheel support for app streams
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: wheel => {
                                        if (appDelegate.streamNode && appDelegate.streamNode.audio) {
                                            let targetVolume = appDelegate.appVolume;
                                            if (wheel.angleDelta.y > 0) {
                                                targetVolume = Math.min(100, targetVolume + volumeControl.scrollStep);
                                            } else if (wheel.angleDelta.y < 0) {
                                                targetVolume = Math.max(0, targetVolume - volumeControl.scrollStep);
                                            }

                                            appDelegate.streamNode.audio.volume = targetVolume / 100.0;
                                            if (targetVolume > 0 && appDelegate.streamNode.audio.muted) {
                                                appDelegate.streamNode.audio.muted = false;
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
    }
}
