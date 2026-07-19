import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notifs

Item {
    id: centerRoot

    // Required properties bound to shell.qml globals
    required property var palette
    required property int topPanelHeightWithMargins

    // Toggle states
    property bool dndMode: false

    // Robust icon resolver that handles custom images, system icon themes, and app fallbacks (e.g., Discord)
    function getIconSource(appIcon, appName, imagePath) {
        // 1. Direct preview or user avatar image path (e.g. Discord avatars or screenshots)
        if (imagePath && imagePath !== "") {
            if (imagePath.startsWith("/") || imagePath.startsWith("file://") || imagePath.startsWith("image://")) {
                return imagePath;
            }
        }

        // 2. Named application icon
        if (appIcon && appIcon !== "") {
            if (appIcon.startsWith("/") || appIcon.startsWith("file://") || appIcon.startsWith("image://")) {
                return appIcon;
            }
            // Use Quickshell's native platform iconTheme finder
            return Quickshell.iconPath(appIcon);
        }

        // 3. Application name fallbacks (resolves blank icons for common services)
        if (appName) {
            let nameLower = appName.toLowerCase();
            if (nameLower.includes("discord")) {
                return Quickshell.iconPath("discord") || Quickshell.iconPath("discord-canary") || "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%235865F2'><path d='M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.46-.63.874-1.295 1.226-1.994.021-.041.001-.09-.041-.106a13.094 13.094 0 0 1-1.873-.894.077.077 0 0 1-.008-.128c.126-.093.252-.19.372-.287a.075.075 0 0 1 .077-.011c3.92 1.793 8.18 1.793 12.061 0a.073.073 0 0 1 .078.009c.12.099.246.195.373.289a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.894.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.156-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.156 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.156-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.156 2.418z'/></svg>";
            } else if (nameLower.includes("firefox")) {
                return Quickshell.iconPath("firefox");
            } else if (nameLower.includes("spotify")) {
                return Quickshell.iconPath("spotify");
            } else if (nameLower.includes("chrome") || nameLower.includes("chromium")) {
                return Quickshell.iconPath("google-chrome");
            } else if (nameLower.includes("slack")) {
                return Quickshell.iconPath("slack");
            } else if (nameLower.includes("signal")) {
                return Quickshell.iconPath("signal");
            } else if (nameLower.includes("telegram")) {
                return Quickshell.iconPath("telegram");
            }
        }

        // Default system notification bell fallback
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.primary) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0'/></svg>";
    }

    // Models for handling notification states
    ListModel {
        id: popupModel
    }

    ListModel {
        id: historyModel
    }

    // Quickshell notification server instance
    Notifs.NotificationServer {
        id: notifServer
        actionsSupported: false
        bodySupported: true
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true;

            // Handle duplicate update (e.g. repeated volume adjustments)
            let found = false;
            for (let i = 0; i < historyModel.count; ++i) {
                if (historyModel.get(i).notifId === notification.id && notification.id !== 0) {
                    historyModel.setProperty(i, "summary", notification.summary);
                    historyModel.setProperty(i, "body", notification.body);
                    historyModel.setProperty(i, "imagePath", notification.image || "");
                    historyModel.setProperty(i, "timestamp", new Date().toLocaleTimeString(Qt.locale(), "hh:mm"));
                    found = true;
                    break;
                }
            }

            if (!found) {
                // Add to history (newest on top)
                historyModel.insert(0, {
                    notifId: notification.id,
                    appName: notification.appName || "System",
                    summary: notification.summary || "Notification",
                    body: notification.body || "",
                    appIcon: notification.appIcon || "",
                    imagePath: notification.image || "",
                    urgency: notification.urgency,
                    timestamp: new Date().toLocaleTimeString(Qt.locale(), "hh:mm")
                });
            }

            // Only trigger a visible popup if Do Not Disturb is off
            if (!centerRoot.dndMode) {
                popupModel.append({
                    notifId: notification.id,
                    appName: notification.appName || "System",
                    summary: notification.summary || "Notification",
                    body: notification.body || "",
                    appIcon: notification.appIcon || "",
                    imagePath: notification.image || "",
                    urgency: notification.urgency
                });
                wiggleAnimation.stop();
                wiggleAnimation.start();
            }
        }
    }

    // Toggle logic for the history side drawer
    function toggle() {
        sidePanelWindow.isOpen = !sidePanelWindow.isOpen;
    }

    // Register a global hyprland shortcut (SUPER+N) for easy access
    GlobalShortcut {
        name: "notifications"
        onPressed: {
            centerRoot.toggle();
        }
    }

    // Overlay window for stacked active notifications
    PanelWindow {
        id: popupWindow
        surfaceFormat.opaque: false
        color: "#00000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }
        margins {
            top: centerRoot.topPanelHeightWithMargins + 8
            right: 40
        }
        width: 350
        height: 600

        visible: popupModel.count > 0

        ListView {
            id: popupListView
            anchors.fill: parent
            model: popupModel
            spacing: 10
            interactive: false

            delegate: Item {
                id: popupDelegate
                width: 350
                height: card.height

                Rectangle {
                    id: card
                    width: 340
                    anchors.right: parent.right
                    implicitHeight: popupContentLayout.height + 24
                    radius: 12
                    color: centerRoot.palette.surface_container
                    border.width: 1.5
                    border.color: model.urgency === 2 ? centerRoot.palette.secondary : centerRoot.palette.primary

                    opacity: 1.0

                    // Entry slide/fade transitions
                    Component.onCompleted: {
                        card.anchors.rightMargin = -350;
                        card.opacity = 0;
                        entryAnimation.start();
                    }

                    ParallelAnimation {
                        id: entryAnimation
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: card
                            property: "anchors.rightMargin"
                            from: -350
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    RowLayout {
                        id: popupContentLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 12

                        // Icon box
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: centerRoot.palette.surface_container_low

                            Image {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                fillMode: Image.PreserveAspectFit
                                source: centerRoot.getIconSource(model.appIcon, model.appName, model.imagePath)
                            }
                        }

                        // Message Layout
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: model.appName
                                    color: centerRoot.palette.outline
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                // Interactive dismiss
                                MouseArea {
                                    width: 16
                                    height: 16
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: closeAnimation.start()

                                    Image {
                                        anchors.fill: parent
                                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.outline) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='18' y1='6' x2='6' y2='18'></line><line x1='6' y1='6' x2='18' y2='18'></line></svg>"
                                    }
                                }
                            }

                            Text {
                                text: model.summary
                                color: centerRoot.palette.on_surface
                                font.pixelSize: 13
                                font.bold: true
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.body
                                color: centerRoot.palette.outline
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                visible: model.body !== ""
                            }
                        }
                    }

                    // Countdown progress indicator
                    Rectangle {
                        height: 3
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 12
                            rightMargin: 12
                            bottomMargin: 4
                        }
                        color: centerRoot.palette.surface_container_low
                        radius: 1.5

                        Rectangle {
                            id: progressFill
                            height: parent.height
                            width: parent.width
                            color: model.urgency === 2 ? centerRoot.palette.secondary : centerRoot.palette.primary
                            radius: 1.5

                            PropertyAnimation {
                                target: progressFill
                                property: "width"
                                from: parent.width
                                to: 0
                                duration: 5000
                                running: true
                            }
                        }
                    }

                    // Auto-dismiss countdown timer
                    Timer {
                        interval: 5000
                        running: true
                        onTriggered: closeAnimation.start()
                    }

                    // Exit Animation
                    SequentialAnimation {
                        id: closeAnimation

                        ParallelAnimation {
                            NumberAnimation {
                                target: card
                                property: "opacity"
                                to: 0.0
                                duration: 250
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: card
                                property: "anchors.rightMargin"
                                to: -350
                                duration: 250
                                easing.type: Easing.OutQuad
                            }
                        }

                        ScriptAction {
                            script: {
                                popupModel.remove(index);
                            }
                        }
                    }
                }
            }
        }
    }

    // Scrollable sidebar notification history
    PanelWindow {
        id: sidePanelWindow
        surfaceFormat.opaque: false
        color: "#00000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            right: true
        }
        margins {
            top: topPanelHeightWithMargins
        }
        width: 360

        property real slideProgress: isOpen ? 1.0 : 0.0
        visible: isOpen || slideAnimation.running

        property bool isOpen: false

        Behavior on slideProgress {
            NumberAnimation {
                id: slideAnimation
                duration: 350
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: panelContainer
            width: 340
            anchors {
                top: parent.top
                bottom: parent.bottom
                topMargin: 8
                bottomMargin: 10
            }
            // Drives smooth slide-in/out transitions based on mathematical offset bounds
            x: (sidePanelWindow.width - width - 10) + (1.0 - sidePanelWindow.slideProgress) * (width + 20)

            color: centerRoot.palette.surface_container_lowest
            border.color: centerRoot.palette.primary
            border.width: 1.5
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header section
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Notifications"
                        color: centerRoot.palette.on_surface
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: centerRoot.palette.primary_container
                        visible: historyModel.count > 0

                        Text {
                            anchors.centerIn: parent
                            text: historyModel.count
                            color: centerRoot.palette.on_surface
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    } // Spacer

                    // Do Not Disturb Control
                    Rectangle {
                        id: dndBtn
                        width: 30
                        height: 30
                        radius: 15
                        color: dndMouse.containsMouse ? centerRoot.palette.surface_container_high : centerRoot.palette.surface_container
                        border.color: centerRoot.dndMode ? centerRoot.palette.secondary : centerRoot.palette.surface_container_highest
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: {
                                let strokeColor = centerRoot.dndMode ? encodeURIComponent(centerRoot.palette.secondary) : encodeURIComponent(centerRoot.palette.on_surface);
                                if (centerRoot.dndMode) {
                                    return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M13.73 21a2 2 0 0 1-3.46 0M18.63 13A17.89 17.89 0 0 1 18 8M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h18M18 8a6 6 0 0 0-9.33-5M1 1l22 22'/></svg>";
                                } else {
                                    return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0'/></svg>";
                                }
                            }
                        }

                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: centerRoot.dndMode = !centerRoot.dndMode
                        }
                    }

                    // Global Clear All Control
                    Rectangle {
                        id: clearBtn
                        width: 30
                        height: 30
                        radius: 15
                        color: clearMouse.containsMouse ? centerRoot.palette.surface_container_high : centerRoot.palette.surface_container
                        border.color: centerRoot.palette.surface_container_highest
                        border.width: 1
                        visible: historyModel.count > 0

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.secondary) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><polyline points='3 6 5 6 21 6'></polyline><path d='M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'></path></svg>"
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historyModel.clear()
                        }
                    }

                    // Side panel collapse button
                    Rectangle {
                        id: closeBtn
                        width: 30
                        height: 30
                        radius: 15
                        color: closeMouse.containsMouse ? centerRoot.palette.surface_container_high : centerRoot.palette.surface_container
                        border.color: centerRoot.palette.surface_container_highest
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.on_surface) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='18' y1='6' x2='6' y2='18'></line><line x1='6' y1='6' x2='18' y2='18'></line></svg>"
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidePanelWindow.isOpen = false
                        }
                    }
                }

                // Divider Line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: centerRoot.palette.surface_container_high
                }

                // History listing
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Scrollable list
                    ListView {
                        id: listView
                        anchors.fill: parent
                        model: historyModel
                        spacing: 8
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            width: 6
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: centerRoot.palette.primary
                                opacity: 0.4
                            }
                        }

                        delegate: Item {
                            id: historyDelegate
                            width: listView.width - 8
                            height: cardContainer.height + 4

                            Rectangle {
                                id: cardContainer
                                width: parent.width
                                implicitHeight: cardLayout.height + 24
                                radius: 12
                                color: historyCardMouse.containsMouse ? centerRoot.palette.surface_container_high : centerRoot.palette.surface_container
                                border.color: model.urgency === 2 ? centerRoot.palette.secondary : (historyCardMouse.containsMouse ? centerRoot.palette.primary : centerRoot.palette.surface_container_highest)
                                border.width: 1

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

                                RowLayout {
                                    id: cardLayout
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: 12
                                    }
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: centerRoot.palette.surface_container_low

                                        Image {
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            fillMode: Image.PreserveAspectFit
                                            source: centerRoot.getIconSource(model.appIcon, model.appName, model.imagePath)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: model.appName
                                                color: centerRoot.palette.outline
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: model.timestamp
                                                color: centerRoot.palette.outline
                                                font.pixelSize: 10
                                            }

                                            // Delete notification from history
                                            MouseArea {
                                                width: 14
                                                height: 14
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    historyModel.remove(index);
                                                }

                                                Image {
                                                    anchors.fill: parent
                                                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.outline) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='18' y1='6' x2='6' y2='18'></line><line x1='6' y1='6' x2='18' y2='18'></line></svg>"
                                                }
                                            }
                                        }

                                        Text {
                                            text: model.summary
                                            color: centerRoot.palette.on_surface
                                            font.pixelSize: 13
                                            font.bold: true
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: model.body
                                            color: centerRoot.palette.outline
                                            font.pixelSize: 11
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                            visible: model.body !== ""
                                        }
                                    }
                                }

                                MouseArea {
                                    id: historyCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }

                    // Empty history state placeholder
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: historyModel.count === 0

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            width: 48
                            height: 48
                            sourceSize.width: 48
                            sourceSize.height: 48
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(centerRoot.palette.outline) + "' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'><path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0M21 21L3 3'/></svg>"
                        }

                        Text {
                            text: centerRoot.dndMode ? "Notifications Muted" : "All Caught Up!"
                            color: centerRoot.palette.on_surface
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: centerRoot.dndMode ? "Disable DND to show popups." : "No notifications in history."
                            color: centerRoot.palette.outline
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Floating interactive toggle bell in the right margin of the top panel.
    // Kept on WlrLayer.Overlay and rendered at the bottom of the QML hierarchy so it always stacks above the slide-out panels.
    PanelWindow {
        id: notificationButtonWindow
        surfaceFormat.opaque: false
        color: "#00000000"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            right: true
        }
        margins {
            top: 5 - topPanelHeightWithMargins
            right: 10
        }
        width: 32
        height: 40

        Rectangle {
            id: bellButton
            width: 32
            height: 32
            radius: 16
            anchors.verticalCenter: parent.verticalCenter
            color: bellMouseArea.containsMouse ? centerRoot.palette.surface_container_low : centerRoot.palette.surface_container
            border.color: sidePanelWindow.isOpen ? centerRoot.palette.primary : (bellMouseArea.containsMouse ? centerRoot.palette.on_surface : centerRoot.palette.secondary)
            border.width: sidePanelWindow.isOpen ? 1.5 : 1.0

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

            // Dynamic SVG Bell Icon
            Image {
                id: bellIcon
                width: 16
                height: 16
                sourceSize.width: 16
                sourceSize.height: 16
                smooth: true
                anchors.centerIn: parent
                transformOrigin: Item.Center

                source: {
                    let strokeColor = centerRoot.dndMode ? encodeURIComponent(centerRoot.palette.error) : (sidePanelWindow.isOpen ? encodeURIComponent(centerRoot.palette.primary) : (bellMouseArea.containsMouse ? encodeURIComponent(centerRoot.palette.on_surface) : encodeURIComponent(centerRoot.palette.secondary)));
                    if (centerRoot.dndMode) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M13.73 21a2 2 0 0 1-3.46 0M18.63 13A17.89 17.89 0 0 1 18 8M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h18M18 8a6 6 0 0 0-9.33-5M1 1l22 22'/></svg>";
                    } else {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + strokeColor + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0'/></svg>";
                    }
                }
            }

            // Unread Count Badge
            Rectangle {
                id: unreadBadge
                width: 14
                height: 14
                radius: 7
                color: centerRoot.palette.secondary
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: -2
                    rightMargin: 1
                }
                visible: historyModel.count > 0

                Text {
                    anchors.centerIn: parent
                    text: historyModel.count
                    color: centerRoot.palette.on_secondary
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            // Hover / Click handler
            MouseArea {
                id: bellMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    centerRoot.toggle();
                }
            }

            // Bell wiggle feedback animation when a notification lands
            SequentialAnimation {
                id: wiggleAnimation
                running: false
                loops: 1

                NumberAnimation {
                    target: bellIcon
                    property: "rotation"
                    from: 0
                    to: 15
                    duration: 50
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: bellIcon
                    property: "rotation"
                    from: 15
                    to: -15
                    duration: 100
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: bellIcon
                    property: "rotation"
                    from: -15
                    to: 15
                    duration: 100
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: bellIcon
                    property: "rotation"
                    from: 15
                    to: -15
                    duration: 100
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: bellIcon
                    property: "rotation"
                    from: -15
                    to: 0
                    duration: 50
                    easing.type: Easing.Linear
                }
            }
        }
    }
}
