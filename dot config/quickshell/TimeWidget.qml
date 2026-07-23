/* STREAMING_CHUNK:Importing required QtQuick and Quickshell modules... */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

/* STREAMING_CHUNK:Defining TimeWidget component properties and state... */
Item {
    id: widgetRoot

    // Palette object passed from root window (Colors.qml)
    required property var palette
    property int topPanelHeightWithMargins: 45

    // Dynamic dimensions based on time text length
    implicitWidth: buttonRow.implicitWidth + 24
    implicitHeight: 32

    // Internal system clock for live date/time formatting
    SystemClock {
        id: widgetClock
        precision: SystemClock.Seconds
    }

    // Active calendar navigation state
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    /* STREAMING_CHUNK:Configuring top bar date/time button UI... */
    Rectangle {
        id: buttonBg
        anchors.fill: parent
        radius: 16
        color: mouseArea.containsMouse ? widgetRoot.palette.surface_container_high : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                font.pixelSize: 18
                font.weight: Font.Medium
                color: widgetRoot.palette.on_surface
                text: Qt.formatDateTime(widgetClock.date, "hh:mm:ss | dd.MM.yyyy")
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                calendarPopup.visible = !calendarPopup.visible;
                if (calendarPopup.visible) {
                    widgetRoot.goToToday();
                }
            }
        }
    }

    /* STREAMING_CHUNK:Creating calendar popup window surface... */
    PanelWindow {
        id: calendarPopup
        visible: false
        color: "#00000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        margins {
            top: widgetRoot.topPanelHeightWithMargins
        }

        implicitWidth: 360
        implicitHeight: 420

        /* STREAMING_CHUNK:Handling backdrop click outside to dismiss popup... */
        MouseArea {
            anchors.fill: parent
            onClicked: calendarPopup.visible = false
        }

        /* STREAMING_CHUNK:Designing popup background and mouse wheel scroll handler... */
        Rectangle {
            width: 360
            height: 420
            color: widgetRoot.palette.surface_container
            border.color: widgetRoot.palette.primary
            border.width: 2
            radius: 16
            clip: true

            anchors {
                top: parent.top
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }

            // Handle wheel scrolling over calendar surface to switch months
            MouseArea {
                anchors.fill: parent
                onWheel: wheel => {
                    if (wheel.angleDelta.y < 0) {
                        widgetRoot.nextMonth();
                    } else if (wheel.angleDelta.y > 0) {
                        widgetRoot.prevMonth();
                    }
                    wheel.accepted = true;
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    /* STREAMING_CHUNK:Designing calendar header with navigation buttons... */
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Previous Year Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: prevYearMouse.containsMouse ? widgetRoot.palette.surface_container_highest : widgetRoot.palette.surface_container_low
                            Text {
                                anchors.centerIn: parent
                                text: "<<"
                                font.pixelSize: 11
                                font.bold: true
                                color: widgetRoot.palette.on_surface
                            }
                            MouseArea {
                                id: prevYearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetRoot.prevYear()
                            }
                        }

                        // Previous Month Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: prevMonthMouse.containsMouse ? widgetRoot.palette.surface_container_highest : widgetRoot.palette.surface_container_low
                            Text {
                                anchors.centerIn: parent
                                text: "<"
                                font.pixelSize: 13
                                font.bold: true
                                color: widgetRoot.palette.on_surface
                            }
                            MouseArea {
                                id: prevMonthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetRoot.prevMonth()
                            }
                        }

                        // Current Month & Year Display (Click resets to today)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 16
                            color: todayHeaderMouse.containsMouse ? widgetRoot.palette.primary_container : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: widgetRoot.monthNames[widgetRoot.viewMonth] + " " + widgetRoot.viewYear
                                font.pixelSize: 15
                                font.bold: true
                                color: todayHeaderMouse.containsMouse ? widgetRoot.palette.primary : widgetRoot.palette.on_surface
                            }

                            MouseArea {
                                id: todayHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetRoot.goToToday()
                            }
                        }

                        // Next Month Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: nextMonthMouse.containsMouse ? widgetRoot.palette.surface_container_highest : widgetRoot.palette.surface_container_low
                            Text {
                                anchors.centerIn: parent
                                text: ">"
                                font.pixelSize: 13
                                font.bold: true
                                color: widgetRoot.palette.on_surface
                            }
                            MouseArea {
                                id: nextMonthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetRoot.nextMonth()
                            }
                        }

                        // Next Year Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: nextYearMouse.containsMouse ? widgetRoot.palette.surface_container_highest : widgetRoot.palette.surface_container_low
                            Text {
                                anchors.centerIn: parent
                                text: ">>"
                                font.pixelSize: 11
                                font.bold: true
                                color: widgetRoot.palette.on_surface
                            }
                            MouseArea {
                                id: nextYearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetRoot.nextYear()
                            }
                        }
                    }

                    /* STREAMING_CHUNK:Rendering weekday column headers... */
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: widgetRoot.weekDays
                            Item {
                                Layout.fillWidth: true
                                height: 22
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: index >= 5 ? widgetRoot.palette.tertiary : widgetRoot.palette.primary
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: widgetRoot.palette.outline_variant
                    }

                    /* STREAMING_CHUNK:Building interactive calendar grid... */
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 4
                        columnSpacing: 4

                        Repeater {
                            model: 42 // 6 weeks grid layout

                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property var dayInfo: widgetRoot.getDayDetails(index)

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) - 2
                                    height: width
                                    radius: width / 2

                                    color: dayInfo.isToday ? widgetRoot.palette.primary : (dayTileMouse.containsMouse && dayInfo.isCurrentMonth ? widgetRoot.palette.surface_container_highest : "transparent")

                                    border.color: dayInfo.isToday ? widgetRoot.palette.primary : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayInfo.dayNumber
                                        font.pixelSize: 13
                                        font.bold: dayInfo.isToday

                                        color: dayInfo.isToday ? widgetRoot.palette.on_primary : (dayInfo.isCurrentMonth ? widgetRoot.palette.on_surface : widgetRoot.palette.outline)
                                    }

                                    MouseArea {
                                        id: dayTileMouse
                                        anchors.fill: parent
                                        hoverEnabled: dayInfo.isCurrentMonth
                                    }
                                }
                            }
                        }
                    }

                    /* STREAMING_CHUNK:Adding quick action footer bar... */
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        radius: 10
                        color: widgetRoot.palette.surface_container_high

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: Qt.formatDateTime(widgetClock.date, "dddd, MMMM d, yyyy")
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: widgetRoot.palette.on_surface_variant
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 64
                                height: 26
                                radius: 13
                                color: todayBtnMouse.containsMouse ? widgetRoot.palette.primary : widgetRoot.palette.primary_container

                                Text {
                                    anchors.centerIn: parent
                                    text: "Today"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: todayBtnMouse.containsMouse ? widgetRoot.palette.on_primary : widgetRoot.palette.on_primary_container
                                }

                                MouseArea {
                                    id: todayBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: widgetRoot.goToToday()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /* STREAMING_CHUNK:Implementing calendar navigation logic and date calculator... */
    function getDayDetails(index) {
        var today = new Date();
        var firstDay = new Date(viewYear, viewMonth, 1);
        var startOffset = (firstDay.getDay() + 6) % 7;
        var daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(viewYear, viewMonth, 0).getDate();

        var dayNum = index - startOffset + 1;
        var isCurrentMonth = true;
        var displayNum = dayNum;

        if (dayNum < 1) {
            isCurrentMonth = false;
            displayNum = daysInPrevMonth + dayNum;
        } else if (dayNum > daysInMonth) {
            isCurrentMonth = false;
            displayNum = dayNum - daysInMonth;
        }

        var isToday = isCurrentMonth && (viewYear === today.getFullYear()) && (viewMonth === today.getMonth()) && (displayNum === today.getDate());

        return {
            dayNumber: displayNum,
            isCurrentMonth: isCurrentMonth,
            isToday: isToday
        };
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear++;
        } else {
            viewMonth++;
        }
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear--;
        } else {
            viewMonth--;
        }
    }

    function nextYear() {
        viewYear++;
    }

    function prevYear() {
        viewYear--;
    }

    function goToToday() {
        var today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }
}
