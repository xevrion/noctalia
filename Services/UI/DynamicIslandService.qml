pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  // Bumped when the bar widget layout may have changed, so bindings that call
  // hasIslandWidget() can re-evaluate (reference this property in the binding).
  property int revision: 0

  // Compact capsule width per screen, published by each island overlay window.
  // The DynamicIsland bar widget reads this to reserve space in the bar layout.
  property var compactWidths: ({})

  // Live overlay window instances, keyed by screen name (for IPC control)
  property var overlays: ({})

  function registerOverlay(screenName, overlay) {
    if (screenName)
      overlays[screenName] = overlay;
  }

  function unregisterOverlay(screenName) {
    if (screenName)
      delete overlays[screenName];
  }

  function forEachOverlay(callback) {
    for (var name in overlays) {
      if (overlays[name])
        callback(overlays[name]);
    }
  }

  function setCompactWidth(screenName, width) {
    if (!screenName || compactWidths[screenName] === width)
      return;
    var map = Object.assign({}, compactWidths);
    map[screenName] = width;
    compactWidths = map;
  }

  // True if the DynamicIsland widget is configured in any bar section on this screen
  function hasIslandWidget(screenName) {
    if (!screenName)
      return false;
    var widgets = Settings.getBarWidgetsForScreen(screenName);
    if (!widgets)
      return false;
    const sections = ["left", "center", "right"];
    for (var s = 0; s < sections.length; s++) {
      var list = widgets[sections[s]] || [];
      for (var i = 0; i < list.length; i++) {
        if (list[i].id === "DynamicIsland")
          return true;
      }
    }
    return false;
  }

  Connections {
    target: Settings
    function onSettingsLoaded() {
      root.revision++;
    }
    function onSettingsReloaded() {
      root.revision++;
    }
  }

  function init() {
    Logger.i("DynamicIslandService", "Service started");
  }
}
