import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// One dynamic island overlay per screen that has the DynamicIsland bar widget
// configured. Horizontal top bars only for now.
Scope {
  Variants {
    model: Quickshell.screens

    delegate: Loader {
      id: loader

      required property ShellScreen modelData

      readonly property string screenName: modelData ? modelData.name : ""

      active: {
        // Re-evaluate when the bar widget layout changes
        BarService.widgetsRevision;
        DynamicIslandService.revision;

        if (!screenName)
          return false;
        if (Settings.getBarPositionForScreen(screenName) !== "top")
          return false;

        var monitors = Settings.data.bar.monitors || [];
        if (monitors.length > 0 && !monitors.includes(screenName))
          return false;

        return DynamicIslandService.hasIslandWidget(screenName);
      }

      sourceComponent: DynamicIslandOverlay {
        screen: loader.modelData
      }

      onLoaded: {
        Logger.d("DynamicIsland", "Overlay created for", screenName);
      }
    }
  }

  // qs -c noctalia-shell ipc call island toggle|expand|collapse
  IpcHandler {
    target: "island"

    function toggle(): void {
      DynamicIslandService.forEachOverlay(overlay => overlay.toggleExpanded());
    }

    function expand(): void {
      DynamicIslandService.forEachOverlay(overlay => overlay.expandPlayer());
    }

    function collapse(): void {
      DynamicIslandService.forEachOverlay(overlay => overlay.collapse());
    }

    function swipeLeft(): void {
      DynamicIslandService.forEachOverlay(overlay => overlay.swipeTo(overlay.pageIndex - 1));
    }

    function swipeRight(): void {
      DynamicIslandService.forEachOverlay(overlay => overlay.swipeTo(overlay.pageIndex + 1));
    }
  }
}
