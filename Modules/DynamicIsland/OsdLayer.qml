import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Transient OSD layer: icon + progress track + percentage, shown while the
// island is in the "split" state.
Item {
  id: root

  property string icon: "volume-high"
  property real value: 0
  property real maxValue: 1.0
  property bool muted: false

  readonly property real ratio: maxValue > 0 ? Math.min(1, value / maxValue) : 0
  readonly property color accent: muted ? Color.mError : Color.mPrimary

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginL
    anchors.rightMargin: Style.marginL
    spacing: Style.marginM

    NIcon {
      icon: root.icon
      pointSize: Style.fontSizeL
      color: root.accent
      Layout.alignment: Qt.AlignVCenter
    }

    Rectangle {
      id: track
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      height: Math.max(4, Math.round(4 * Style.uiScaleRatio))
      radius: height / 2
      color: Qt.alpha(Color.mOnSurface, 0.25)

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root.smoothRatio
        height: parent.height
        radius: parent.radius
        color: root.accent
      }
    }

    NText {
      text: Math.round(root.value * 100) + "%"
      pointSize: Style.fontSizeS
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: Math.round(34 * Style.uiScaleRatio)
      horizontalAlignment: Text.AlignRight
    }
  }

  property real smoothRatio: ratio
  Behavior on smoothRatio {
    NumberAnimation {
      duration: 180
      easing.type: Easing.InOutQuad
    }
  }
}
