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
        wallpaperModule.palette.on_primary = getColor("on_primary", wallpaperModule.palette.on_primary);
        wallpaperModule.palette.primary_container = getColor("primary_container", wallpaperModule.palette.primary_container);
        wallpaperModule.palette.on_primary_container = getColor("on_primary_container", wallpaperModule.palette.on_primary_container);
        wallpaperModule.palette.inverse_primary = getColor("inverse_primary", wallpaperModule.palette.inverse_primary);
        wallpaperModule.palette.primary_fixed = getColor("primary_fixed", wallpaperModule.palette.primary_fixed);
        wallpaperModule.palette.primary_fixed_dim = getColor("primary_fixed_dim", wallpaperModule.palette.primary_fixed_dim);
        wallpaperModule.palette.on_primary_fixed = getColor("on_primary_fixed", wallpaperModule.palette.on_primary_fixed);
        wallpaperModule.palette.on_primary_fixed_variant = getColor("on_primary_fixed_variant", wallpaperModule.palette.on_primary_fixed_variant);
        wallpaperModule.palette.secondary = getColor("secondary", wallpaperModule.palette.secondary);
        wallpaperModule.palette.on_secondary = getColor("on_secondary", wallpaperModule.palette.on_secondary);
        wallpaperModule.palette.secondary_container = getColor("secondary_container", wallpaperModule.palette.secondary_container);
        wallpaperModule.palette.on_secondary_container = getColor("on_secondary_container", wallpaperModule.palette.on_secondary_container);
        wallpaperModule.palette.secondary_fixed = getColor("secondary_fixed", wallpaperModule.palette.secondary_fixed);
        wallpaperModule.palette.secondary_fixed_dim = getColor("secondary_fixed_dim", wallpaperModule.palette.secondary_fixed_dim);
        wallpaperModule.palette.on_secondary_fixed = getColor("on_secondary_fixed", wallpaperModule.palette.on_secondary_fixed);
        wallpaperModule.palette.on_secondary_fixed_variant = getColor("on_secondary_fixed_variant", wallpaperModule.palette.on_secondary_fixed_variant);
        wallpaperModule.palette.tertiary = getColor("tertiary", wallpaperModule.palette.tertiary);
        wallpaperModule.palette.on_tertiary = getColor("on_tertiary", wallpaperModule.palette.on_tertiary);
        wallpaperModule.palette.tertiary_container = getColor("tertiary_container", wallpaperModule.palette.tertiary_container);
        wallpaperModule.palette.on_tertiary_container = getColor("on_tertiary_container", wallpaperModule.palette.on_tertiary_container);
        wallpaperModule.palette.tertiary_fixed = getColor("tertiary_fixed", wallpaperModule.palette.tertiary_fixed);
        wallpaperModule.palette.tertiary_fixed_dim = getColor("tertiary_fixed_dim", wallpaperModule.palette.tertiary_fixed_dim);
        wallpaperModule.palette.on_tertiary_fixed = getColor("on_tertiary_fixed", wallpaperModule.palette.on_tertiary_fixed);
        wallpaperModule.palette.on_tertiary_fixed_variant = getColor("on_tertiary_fixed_variant", wallpaperModule.palette.on_tertiary_fixed_variant);
        wallpaperModule.palette.error = getColor("error", wallpaperModule.palette.error);
        wallpaperModule.palette.on_error = getColor("on_error", wallpaperModule.palette.on_error);
        wallpaperModule.palette.error_container = getColor("error_container", wallpaperModule.palette.error_container);
        wallpaperModule.palette.on_error_container = getColor("on_error_container", wallpaperModule.palette.on_error_container);
        wallpaperModule.palette.surface_dim = getColor("surface_dim", wallpaperModule.palette.surface_dim);
        wallpaperModule.palette.surface = getColor("surface", wallpaperModule.palette.surface);
        wallpaperModule.palette.surface_tint = getColor("surface_tint", wallpaperModule.palette.surface_tint);
        wallpaperModule.palette.surface_bright = getColor("surface_bright", wallpaperModule.palette.surface_bright);
        wallpaperModule.palette.surface_container_lowest = getColor("surface_container_lowest", wallpaperModule.palette.surface_container_lowest);
        wallpaperModule.palette.surface_container_low = getColor("surface_container_low", wallpaperModule.palette.surface_container_low);
        wallpaperModule.palette.surface_container = getColor("surface_container", wallpaperModule.palette.surface_container);
        wallpaperModule.palette.surface_container_high = getColor("surface_container_high", wallpaperModule.palette.surface_container_high);
        wallpaperModule.palette.surface_container_highest = getColor("surface_container_highest", wallpaperModule.palette.surface_container_highest);
        wallpaperModule.palette.on_surface = getColor("on_surface", wallpaperModule.palette.on_surface);
        wallpaperModule.palette.on_surface_variant = getColor("on_surface_variant", wallpaperModule.palette.on_surface_variant);
        wallpaperModule.palette.outline = getColor("outline", wallpaperModule.palette.outline);
        wallpaperModule.palette.outline_variant = getColor("outline_variant", wallpaperModule.palette.outline_variant);
        wallpaperModule.palette.inverse_surface = getColor("inverse_surface", wallpaperModule.palette.inverse_surface);
        wallpaperModule.palette.inverse_on_surface = getColor("inverse_on_surface", wallpaperModule.palette.inverse_on_surface);
        wallpaperModule.palette.surface_variant = getColor("surface_variant", wallpaperModule.palette.surface_variant);
        wallpaperModule.palette.background = getColor("background", wallpaperModule.palette.background);
        wallpaperModule.palette.on_background = getColor("on_background", wallpaperModule.palette.on_background);
        wallpaperModule.palette.shadow = getColor("shadow", wallpaperModule.palette.shadow);
        wallpaperModule.palette.scrim = getColor("scrim", wallpaperModule.palette.scrim);
        wallpaperModule.palette.base00 = getColor("base00", wallpaperModule.palette.base00);
        wallpaperModule.palette.base05 = getColor("base05", wallpaperModule.palette.base05);
        wallpaperModule.palette.base01 = getColor("base01", wallpaperModule.palette.base01);
        wallpaperModule.palette.base02 = getColor("base02", wallpaperModule.palette.base02);
        wallpaperModule.palette.base03 = getColor("base03", wallpaperModule.palette.base03);
        wallpaperModule.palette.base04 = getColor("base04", wallpaperModule.palette.base04);
        wallpaperModule.palette.base06 = getColor("base06", wallpaperModule.palette.base06);
        wallpaperModule.palette.base07 = getColor("base07", wallpaperModule.palette.base07);
        wallpaperModule.palette.base08 = getColor("base08", wallpaperModule.palette.base08);
        wallpaperModule.palette.base09 = getColor("base09", wallpaperModule.palette.base09);
        wallpaperModule.palette.base0a = getColor("base0a", wallpaperModule.palette.base0a);
        wallpaperModule.palette.base0b = getColor("base0b", wallpaperModule.palette.base0b);
        wallpaperModule.palette.base0c = getColor("base0c", wallpaperModule.palette.base0c);
        wallpaperModule.palette.base0d = getColor("base0d", wallpaperModule.palette.base0d);
        wallpaperModule.palette.base0e = getColor("base0e", wallpaperModule.palette.base0e);
        wallpaperModule.palette.base0f = getColor("base0f", wallpaperModule.palette.base0f);
        wallpaperModule.palette.source_color = getColor("source_color", wallpaperModule.palette.source_color);
    }

    // Call Matugen non-blockingly using --dry-run so it outputs only JSON stdout
    function updateColorsFromWallpaper(source) {
        let cleanPath = getCleanPath(source);
        if (cleanPath === "")
            return;

        matugenProcess.running = false;
        matugenProcess.command = ["matugen", "image", cleanPath, "--dry-run", "--json", "hex", "--prefer", "value", "--type", "scheme-content"];
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
