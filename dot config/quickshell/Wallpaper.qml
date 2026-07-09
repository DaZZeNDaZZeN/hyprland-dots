import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: wallpaperModule
    property int topPanelHeightWithMargins: 0 

    property string wallpaperSource: Qt.resolvedUrl("file:///home/ren/Wallpaper/1363707.png") 

    IpcHandler {
        target: "wallpaper"

        function setWallpaper(path: string): void {
            if (path.length > 0) {
                if (!path.startsWith("file://") && !path.startsWith("qrc:/") && !path.startsWith("http")) {
                    wallpaperModule.wallpaperSource = "file://" + path;
                } else {
                    wallpaperModule.wallpaperSource = path;
                }
            }
        }

        function getWallpaper(): string {
            return wallpaperModule.wallpaperSource;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgWindow
            property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            margins { top: -topPanelHeightWithMargins }
            exclusionMode: ExclusionMode.None
            focusable: false
            color: "#1a1a1a" // Matched to background color

            Component.onCompleted: {
                if (this.WlrLayershell != null) {
                    this.WlrLayershell.layer = WlrLayer.Background;
                    this.WlrLayershell.namespace = "wallpaper";
                }
            }

            Item {
                anchors.fill: parent

                Image {
                    id: baseImage
                    anchors.fill: parent
                    source: wallpaperModule.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Image {
                    id: overlayImage
                    anchors.fill: parent
                    source: wallpaperModule.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500 
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}