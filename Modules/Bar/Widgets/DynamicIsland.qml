import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI

// Transparent spacer that reserves room in the bar layout for the dynamic
// island. The island itself renders in a dedicated overlay window
// (Modules/DynamicIsland) so it can morph beyond the bar's bounds.
Item {
  id: root

  property ShellScreen screen

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)

  implicitWidth: isVertical ? barHeight : (DynamicIslandService.compactWidths[screenName] || Math.round(140 * Style.uiScaleRatio))
  implicitHeight: barHeight
}
