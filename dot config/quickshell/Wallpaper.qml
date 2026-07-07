import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: wallpaperModule
    property int topPanelHeightWithMargins: 0 // should be assigned on creation

    // Shared state for the currently active wallpaper path
    property string wallpaperSource: Qt.resolvedUrl("file:///home/ren/Wallpaper/1363707.png") // Fallback image path

    // --- IPC Controller ---
    // This exposes an interface to change the wallpaper dynamically via terminal/keybinds
    IpcHandler {
        target: "wallpaper"

        // Call via: quickshell ipc call wallpaper setWallpaper "/absolute/path/to/image.png"
        function setWallpaper(path: string): void {
            if (path.length > 0) {
                // Ensure it's correctly formatted as a URL or absolute path string
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

    // --- Multi-Monitor Setup ---
    // Variants loops over all connected screens and applies a PanelWindow to each
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgWindow
            property var modelData
            screen: modelData

            // Force window to occupy the entire monitor space
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins {
                top: -topPanelHeightWithMargins
            }
            // Important: Do not reserve space/gaps or accept keyboard focus
            exclusionMode: ExclusionMode.None
            focusable: false
            color: "#111111"

            // Set the Wayland protocol layer to sit completely behind everything else
            Component.onCompleted: {
                if (this.WlrLayershell != null) {
                    this.WlrLayershell.layer = WlrLayer.Background;
                    this.WlrLayershell.namespace = "wallpaper";
                }
            }

            // Crossfade container logic for smooth wallpaper transitions
            Item {
                anchors.fill: parent

                // Layer 1: The old image fading out / serving as base
                Image {
                    id: baseImage
                    anchors.fill: parent
                    source: wallpaperModule.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // Layer 2: The incoming image fading in smoothly
                Image {
                    id: overlayImage
                    anchors.fill: parent
                    source: wallpaperModule.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 500 // 500ms fade transition duration
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}
