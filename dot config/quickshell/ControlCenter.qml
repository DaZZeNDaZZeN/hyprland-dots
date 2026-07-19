import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: controlRoot

    required property var palette
    required property int topPanelHeightWithMargins

    // --- SYSTEM BACKENDS (Using Hyprland Dispatcher) ---
    function runCommand(cmd) {
        Hyprland.dispatch('hl.dsp.exec_cmd("' + cmd + '")');
    }

    // --- NETWORKING BACKEND ---
    property bool wifiConnected: false
    property bool netExpanded: false
    property var wifiNetworks: []
    property var ethernetConnections: []

    function triggerWifiToggle() {
        toggleWifi.running = false;
        toggleWifi.command = ["nmcli", "radio", "wifi", controlRoot.wifiConnected ? "off" : "on"];
        toggleWifi.running = true;
    }

    // --- UPDATED WIFI CONNECTION ENGINE ---
    function connectToNetwork(ssid) {
        Hyprland.dispatch('hl.dsp.exec_cmd("nmcli device wifi connect ' + "'" + ssid + "'" + ' password $(kdialog --password ' + "'" + 'Enter Wi-Fi Password:' + "'" + ')")');
    }

    Process {
        id: connectWifi
    }

    Process {
        id: toggleWifi
        onExited: checkWifi.running = true
    }

    Process {
        id: checkWifi
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            id: wifiCollector
            onStreamFinished: {
                let res = wifiCollector.text.trim();
                controlRoot.wifiConnected = (res === "enabled");
                if (controlRoot.wifiConnected && controlRoot.netExpanded) {
                    scanWifi.running = true;
                }
            }
        }
        running: true
    }

    // Polling Timer: Continuously updates available Wi-Fi networks every 6 seconds while open
    Timer {
        id: wifiScanTimer
        interval: 6000
        repeat: true
        running: controlRoot.netExpanded && controlRoot.wifiConnected
        onTriggered: {
            scanWifi.running = false;
            scanWifi.running = true;
        }
    }

    Process {
        id: nmMonitor
        command: ["nmcli", "monitor"]

        // Use SplitParser to process output immediately on every newline (\n)
        stdout: SplitParser {
            onRead: data => {
                // Whenever NetworkManager pushes an event line, instantly refresh the wifi scan
                scanWifi.running = false;
                scanWifi.running = true;
            }
        }

        // Automatically restart the monitor if it exits or crashes
        onRunningChanged: {
            if (!running) {
                running = true;
            }
        }

        running: true
    }

    Process {
        id: scanWifi
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "device", "wifi", "list"]
        stdout: StdioCollector {
            id: scanCollector
            onStreamFinished: {
                let lines = scanCollector.text.trim().split("\n");
                let networks = [];
                let seenSsids = new Set();

                for (let line of lines) {
                    if (!line)
                        continue;
                    let parts = line.split(":");
                    if (parts.length >= 3) {
                        let active = parts[0] === "yes";
                        let ssid = parts[1];
                        let signal = parseInt(parts[2]) || 0;

                        if (ssid && !seenSsids.has(ssid)) {
                            seenSsids.add(ssid);
                            networks.push({
                                active: active,
                                ssid: ssid,
                                signal: signal
                            });
                        }
                    }
                }
                controlRoot.wifiNetworks = networks;
            }
        }
    }

    Process {
        id: checkEthernet
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        stdout: StdioCollector {
            id: ethCollector
            onStreamFinished: {
                let lines = ethCollector.text.trim().split("\n");
                let eths = [];
                for (let line of lines) {
                    let parts = line.split(":");
                    if (parts.length >= 3 && parts[1] === "ethernet" && parts[2] === "connected") {
                        eths.push(parts[0]);
                    }
                }
                controlRoot.ethernetConnections = eths;
            }
        }
    }

    onNetExpandedChanged: {
        if (netExpanded) {
            checkEthernet.running = false;
            checkEthernet.running = true;
            if (wifiConnected) {
                scanWifi.running = false;
                scanWifi.running = true;
            }
        }
    }

    // --- BLUETOOTH BACKEND ---
    property bool bluetoothActive: false
    function triggerBluetoothToggle() {
        toggleBluetooth.running = false;
        toggleBluetooth.command = ["bluetoothctl", "power", controlRoot.bluetoothActive ? "off" : "on"];
        toggleBluetooth.running = true;
    }

    Process {
        id: toggleBluetooth
        onExited: checkBluetooth.running = true
    }

    Process {
        id: checkBluetooth
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            id: btCollector
            onStreamFinished: {
                let res = btCollector.text;
                controlRoot.bluetoothActive = res.includes("Powered: yes");
            }
        }
        running: true
    }

    function toggle() {
        sidePanelWindow.isOpen = !sidePanelWindow.isOpen;
    }

    GlobalShortcut {
        name: "widgets"
        onPressed: controlRoot.toggle()
    }

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
            left: true
        }
        margins {
            top: topPanelHeightWithMargins
        }

        width: 350
        property bool isOpen: false
        property real slideProgress: isOpen ? 1.0 : 0.0
        visible: isOpen || slideAnimation.running

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
                topMargin: 10
                bottomMargin: 10
            }
            x: -width * (1.0 - sidePanelWindow.slideProgress) + 10

            color: controlRoot.palette.surface_container_lowest
            border.color: controlRoot.palette.primary
            border.width: 1.5
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Control Center"
                        color: controlRoot.palette.on_surface
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: closeMouse.containsMouse ? controlRoot.palette.surface_container_high : controlRoot.palette.surface_container
                        border.color: controlRoot.palette.surface_container_highest
                        border.width: 1
                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(controlRoot.palette.on_surface) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='18' y1='6' x2='6' y2='18'></line><line x1='6' y1='6' x2='18' y2='18'></line></svg>"
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

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: controlRoot.palette.surface_container_high
                }

                // Scroll Container
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: 308
                        spacing: 16

                        // --- Network & Bluetooth Layout ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Network Status Widget Container
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: controlRoot.netExpanded ? networkMainColumn.implicitHeight + 20 : 60
                                radius: 12
                                color: controlRoot.palette.surface_container
                                border.color: controlRoot.wifiConnected ? controlRoot.palette.primary : controlRoot.palette.surface_container_highest
                                border.width: 1

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                                ColumnLayout {
                                    id: networkMainColumn
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    // Top Header Row
                                    RowLayout {
                                        id: networkHeaderLayout
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: controlRoot.wifiConnected ? controlRoot.palette.primary_container : controlRoot.palette.surface_container_low
                                            Image {
                                                anchors.centerIn: parent
                                                width: 18
                                                height: 18
                                                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(controlRoot.wifiConnected ? controlRoot.palette.on_surface : controlRoot.palette.outline) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M5 12.55a11 11 0 0 1 14.08 0M1.42 9a16 16 0 0 1 21.16 0M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01'/></svg>"
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text {
                                                text: "Network"
                                                color: controlRoot.palette.on_surface
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                            Text {
                                                text: controlRoot.wifiConnected ? "Connected" : "Disabled"
                                                color: controlRoot.palette.outline
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            text: controlRoot.netExpanded ? "▲" : "▼"
                                            color: controlRoot.palette.outline
                                            font.pixelSize: 10
                                            Layout.margins: 6
                                        }
                                    }

                                    // Expandable Submenu Layout
                                    ColumnLayout {
                                        id: expandedContentLayout
                                        Layout.fillWidth: true
                                        visible: controlRoot.netExpanded
                                        spacing: 12

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: controlRoot.palette.surface_container_high
                                        }

                                        // Wi-Fi Hardware State Toggle Switch
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Wi-Fi Toggle"
                                                color: controlRoot.palette.on_surface
                                                font.pixelSize: 12
                                                Layout.fillWidth: true
                                            }
                                            Switch {
                                                checked: controlRoot.wifiConnected
                                                onClicked: controlRoot.triggerWifiToggle()
                                            }
                                        }

                                        // Ethernet connections section
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            visible: controlRoot.ethernetConnections.length > 0
                                            Text {
                                                text: "Ethernet Devices"
                                                color: controlRoot.palette.outline
                                                font.bold: true
                                                font.pixelSize: 11
                                            }
                                            Repeater {
                                                model: controlRoot.ethernetConnections
                                                delegate: RowLayout {
                                                    Layout.fillWidth: true
                                                    Text {
                                                        text: "󰈀  " + modelData
                                                        color: controlRoot.palette.on_surface
                                                        font.pixelSize: 12
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: "Connected"
                                                        color: "#47d46c"
                                                        font.pixelSize: 11
                                                    }
                                                }
                                            }
                                        }

                                        // Discovered Wi-Fi connections section
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: "Available Wi-Fi"
                                                color: controlRoot.palette.outline
                                                font.bold: true
                                                font.pixelSize: 11
                                            }

                                            Text {
                                                text: "No networks found or Wi-Fi off."
                                                color: controlRoot.palette.outline
                                                font.pixelSize: 11
                                                visible: controlRoot.wifiNetworks.length === 0
                                            }

                                            Repeater {
                                                model: controlRoot.wifiNetworks
                                                delegate: Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 32
                                                    color: controlRoot.palette.surface_container_low
                                                    radius: 6

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 6
                                                        Text {
                                                            text: (modelData.active ? "󰖩  " : "󰖪  ") + modelData.ssid
                                                            color: modelData.active ? controlRoot.palette.primary : controlRoot.palette.on_surface
                                                            font.bold: modelData.active
                                                            font.pixelSize: 12
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                        Text {
                                                            text: modelData.signal + "%"
                                                            color: controlRoot.palette.outline
                                                            font.pixelSize: 10
                                                        }

                                                        Button {
                                                            text: modelData.active ? "Connected" : "Connect"
                                                            enabled: !modelData.active
                                                            onClicked: controlRoot.connectToNetwork(modelData.ssid)
                                                            contentItem: Text {
                                                                text: parent.text
                                                                color: parent.enabled ? controlRoot.palette.on_surface : controlRoot.palette.outline
                                                                font.pixelSize: 10
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            background: Rectangle {
                                                                implicitWidth: 65
                                                                implicitHeight: 22
                                                                radius: 4
                                                                color: parent.enabled ? controlRoot.palette.surface_container_highest : "transparent"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: networkExpandMouse
                                    height: 60
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlRoot.netExpanded = !controlRoot.netExpanded
                                }
                            }

                            // Bluetooth Status Widget
                            Rectangle {
                                Layout.fillWidth: true
                                height: 60
                                radius: 12
                                color: btMouse.containsMouse ? controlRoot.palette.surface_container_high : controlRoot.palette.surface_container
                                border.color: controlRoot.bluetoothActive ? controlRoot.palette.primary : controlRoot.palette.surface_container_highest
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: controlRoot.bluetoothActive ? controlRoot.palette.primary_container : controlRoot.palette.surface_container_low
                                        Image {
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(controlRoot.bluetoothActive ? controlRoot.palette.on_surface : controlRoot.palette.outline) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='m7 7 10 10-5 5V2l5 5L7 17'/></svg>"
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Bluetooth"
                                            color: controlRoot.palette.on_surface
                                            font.bold: true
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: controlRoot.bluetoothActive ? "Active" : "Disabled"
                                            color: controlRoot.palette.outline
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                                MouseArea {
                                    id: btMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlRoot.triggerBluetoothToggle()
                                }
                            }
                        }

                        // --- Powermenu Section ---
                        Rectangle {
                            Layout.fillWidth: true
                            height: 80
                            radius: 12
                            color: controlRoot.palette.surface_container_low

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Repeater {
                                    model: [
                                        {
                                            name: "Sleep",
                                            icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2'><path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/></svg>",
                                            action: "systemctl suspend"
                                        },
                                        {
                                            name: "Logout",
                                            icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2'><path d='M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9'/></svg>",
                                            action: 'command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch ' + "'" + 'hl.dsp.exit()' + "'"
                                        },
                                        {
                                            name: "Reboot",
                                            icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ffffff' stroke-width='2'><polyline points='23 4 23 10 17 10'></polyline><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/></svg>",
                                            action: "systemctl reboot"
                                        },
                                        {
                                            name: "Poweroff",
                                            icon: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23ff5555' stroke-width='2'><path d='M18.36 6.64a9 9 0 1 1-12.73 0M12 2v10'/></svg>",
                                            action: "systemctl poweroff"
                                        }
                                    ]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 8
                                        color: pwrMouse.containsMouse ? controlRoot.palette.surface_container_highest : controlRoot.palette.surface_container
                                        border.color: modelData.name === "Poweroff" ? "#ff5555" : "transparent"
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Image {
                                                Layout.alignment: Qt.AlignHCenter
                                                width: 20
                                                height: 20
                                                source: modelData.icon
                                            }
                                            Text {
                                                text: modelData.name
                                                color: controlRoot.palette.on_surface
                                                font.pixelSize: 11
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                        MouseArea {
                                            id: pwrMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: controlRoot.runCommand(modelData.action)
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

    // Left Panel Floating Toggle Switch
    PanelWindow {
        id: widgetButtonWindow
        surfaceFormat.opaque: false
        color: "#00000000"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            left: true
        }
        margins {
            top: 5 - topPanelHeightWithMargins
            left: 10
        }
        width: 32
        height: 40

        Rectangle {
            id: toggleButton
            width: 32
            height: 32
            radius: 16
            anchors.verticalCenter: parent.verticalCenter
            color: widgetMouseArea.containsMouse ? controlRoot.palette.surface_container_high : controlRoot.palette.surface_container
            border.color: sidePanelWindow.isOpen ? controlRoot.palette.primary : (widgetMouseArea.containsMouse ? controlRoot.palette.on_surface : controlRoot.palette.secondary)
            border.width: sidePanelWindow.isOpen ? 1.5 : 1.0

            Image {
                width: 16
                height: 16
                anchors.centerIn: parent
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + encodeURIComponent(sidePanelWindow.isOpen ? controlRoot.palette.primary : (widgetMouseArea.containsMouse ? controlRoot.palette.on_surface : controlRoot.palette.secondary)) + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='3' width='7' height='9'></rect><rect x='14' y='3' width='7' height='5'></rect><rect x='14' y='12' width='7' height='9'></rect><rect x='3' y='16' width='7' height='5'></rect></svg>"
            }

            MouseArea {
                id: widgetMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controlRoot.toggle()
            }
        }
    }
}
