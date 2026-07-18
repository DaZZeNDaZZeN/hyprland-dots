import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: wallpaperModule
    property int topPanelHeightWithMargins: 0

    property string wallpaperSource: Qt.resolvedUrl("wallpapers/default.png")

    property var palette

    // Re-run Matugen when the wallpaper changes
    onWallpaperSourceChanged: {
        updateColorsFromWallpaper(wallpaperSource);
    }

    // Run Matugen immediately on initialization to set starting colors
    Component.onCompleted: {
        updateColorsFromWallpaper(wallpaperSource);
    }

    // Helper to strip file:// prefix so standard CLI tools can locate the file path
    function getCleanPath(urlStr) {
        if (urlStr.startsWith("file://")) {
            return urlStr.substring(7);
        }
        return urlStr;
    }

    // Robust color extractor designed exactly for Matugen's JSON output
    function extractColor(json, colorName) {
        if (!json || !json.colors)
            return null;

        let colorObj = json.colors[colorName];
        if (!colorObj)
            return null;

        let hexVal = null;
        // Extract matching hex color values according to your schema:
        // Attempt default first, fallback to dark, then light
        if (colorObj.default && colorObj.default.color) {
            hexVal = colorObj.default.color;
        } else if (colorObj.dark && colorObj.dark.color) {
            hexVal = colorObj.dark.color;
        } else if (colorObj.light && colorObj.light.color) {
            hexVal = colorObj.light.color;
        } else if (typeof colorObj === 'string') {
            hexVal = colorObj;
        }
        if (hexVal && typeof hexVal === 'string') {
            if (!hexVal.startsWith("#")) {
                hexVal = "#" + hexVal;
            }
            return hexVal;
        }
        return null;
    }

    // Live update your properties on root.palette
    function applyMatugenColors(json) {
        if (!wallpaperModule.palette)
            return;

        function getColor(name, fallback) {
            let col = extractColor(json, name);
            return col ? col : fallback;
        }

        wallpaperModule.palette.primary = getColor("primary", wallpaperModule.palette.primary);
        wallpaperModule.palette.primary_container = getColor("primary_container", wallpaperModule.palette.primary_container);
        wallpaperModule.palette.secondary = getColor("secondary", wallpaperModule.palette.secondary);
        wallpaperModule.palette.tertiary = getColor("tertiary", wallpaperModule.palette.tertiary);

        // Map UI text elements appropriately
        wallpaperModule.palette.text = getColor("on_surface", wallpaperModule.palette.text);
        wallpaperModule.palette.darkerText = getColor("on_surface_variant", wallpaperModule.palette.darkerText);
        wallpaperModule.palette.darkestText = getColor("background", wallpaperModule.palette.darkestText);

        // Map container hierarchies
        wallpaperModule.palette.surface = getColor("surface", wallpaperModule.palette.surface);
        wallpaperModule.palette.surface_container_lowest = getColor("surface_container_lowest", wallpaperModule.palette.surface_container_lowest);
        wallpaperModule.palette.surface_container_low = getColor("surface_container_low", wallpaperModule.palette.surface_container_low);
        wallpaperModule.palette.surface_container = getColor("surface_container", wallpaperModule.palette.surface_container);
        wallpaperModule.palette.surface_container_high = getColor("surface_container_high", wallpaperModule.palette.surface_container_high);
        wallpaperModule.palette.surface_container_highest = getColor("surface_container_highest", wallpaperModule.palette.surface_container_highest);
    }

    // Call Matugen non-blockingly using --dry-run so it outputs only JSON stdout
    function updateColorsFromWallpaper(source) {
        let cleanPath = getCleanPath(source);
        if (cleanPath === "")
            return;

        matugenProcess.running = false;
        matugenProcess.command = ["matugen", "image", cleanPath, "--dry-run", "--json", "hex", "--prefer", "value"];
        matugenProcess.running = true;
    }

    Process {
        id: matugenProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "")
                    return;
                try {
                    let parsed = JSON.parse(text);
                    applyMatugenColors(parsed);
                } catch (e) {
                    console.warn("Failed to parse matugen json output:", e);
                }
            }
        }
    }

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

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins {
                top: -topPanelHeightWithMargins
            }

            focusable: false
            color: wallpaperModule.palette.surface

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
