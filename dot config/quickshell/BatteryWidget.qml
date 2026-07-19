import QtQuick
import Quickshell.Io

Row {
    id: batteryWidget
    spacing: 8

    property var palette
    property int capacity: 100
    property bool isCharging: false

    function getBatteryColor(pct) {
        if (pct <= 20) return "#e74c3c";
        if (pct <= 50) return "#f1c40f";
        return "#2ecc71";
    }

    function queryInitialState() {
        initialReader.running = true;
    }

    Component.onCompleted: queryInitialState()

    // 1. Snapshot process on system startup
    Process {
        id: initialReader
        command: ["sh", "-c", "for bat in /sys/class/power_supply/BAT*; do if [ -f \"$bat/capacity\" ]; then cat \"$bat/capacity\"; cat \"$bat/status\"; break; fi; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: parseBatteryOutput(text)
        }
    }

    // 2. Persistent event-driven daemon thread (No standard pollers used!)
    Process {
        id: batteryMonitor
        command: ["upower", "--monitor-detail"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                // Whenever upower stream updates, run a delta read check
                initialReader.running = true;
            }
        }
    }

    function parseBatteryOutput(outputStr) {
        let output = outputStr.trim();
        if (output) {
            let lines = output.split("\n");
            if (lines.length >= 1) {
                let parsedCapacity = parseInt(lines[0].trim());
                if (!isNaN(parsedCapacity)) {
                    batteryWidget.capacity = parsedCapacity;
                }
            }
            if (lines.length >= 2) {
                let status = lines[1].trim();
                batteryWidget.isCharging = (status === "Charging" || status === "Full");
            }
        }
    }

    Item {
        width: 32; height: 18
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: batteryOuter
            width: 28; height: 16; color: "transparent"
            border.color: batteryWidget.palette.on_surface; border.width: 1.5; radius: 3
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: batteryInnerLevel
                anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, (batteryOuter.width - 5) * (batteryWidget.capacity / 100))
                height: batteryOuter.height - 5
                color: batteryWidget.getBatteryColor(batteryWidget.capacity)
                radius: 1

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }

        Rectangle {
            width: 2; height: 6; color: batteryWidget.palette.on_surface; radius: 1
            anchors.left: batteryOuter.right; anchors.leftMargin: 1; anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: chargingOverlay
            visible: batteryWidget.isCharging
            text: "⚡"
            font.pixelSize: 12; color: "#f1c40f"; style: Text.Outline
            styleColor: batteryWidget.palette.surface_container
            anchors.centerIn: batteryOuter
        }
    }

    Text {
        text: batteryWidget.capacity + "%"
        font.pixelSize: 13; font.bold: true; color: batteryWidget.palette.on_surface
        anchors.verticalCenter: parent.verticalCenter
    }
}