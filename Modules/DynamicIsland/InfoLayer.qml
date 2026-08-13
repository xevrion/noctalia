import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

// Left swipe page: time, date and battery at a glance.
Item {
  id: root

  readonly property string timeText: Qt.formatDateTime(Time.now, "HH:mm")
  readonly property string dateText: Qt.formatDateTime(Time.now, "ddd, MMM d")
  readonly property bool hasBattery: BatteryService.batteryReady
  readonly property int batteryPercent: Math.round(BatteryService.batteryPercentage)

  TextMetrics {
    id: timeMetrics
    text: root.timeText
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Style.fontSizeM * Style.uiScaleRatio
    font.weight: Style.fontWeightBold
  }

  TextMetrics {
    id: dateMetrics
    text: root.dateText
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Style.fontSizeS * Style.uiScaleRatio
  }

  readonly property real preferredWidth: {
    let w = Style.marginL * 2 + timeMetrics.width + Style.marginS + dateMetrics.width + Style.marginL;
    if (hasBattery)
      w += Style.marginS * 2 + Style.fontSizeM * 1.6 * Style.uiScaleRatio + Math.round(34 * Style.uiScaleRatio);
    return Math.round(Math.max(Math.round(150 * Style.uiScaleRatio), w));
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginL
    anchors.rightMargin: Style.marginL
    spacing: Style.marginS

    NText {
      text: root.timeText
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
      Layout.alignment: Qt.AlignVCenter
    }

    NText {
      text: root.dateText
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
    }

    NIcon {
      visible: root.hasBattery
      icon: BatteryService.batteryIcon
      pointSize: Style.fontSizeM
      color: BatteryService.batteryCharging ? Color.mPrimary : Color.mOnSurface
      Layout.alignment: Qt.AlignVCenter
    }

    NText {
      visible: root.hasBattery
      text: root.batteryPercent + "%"
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
