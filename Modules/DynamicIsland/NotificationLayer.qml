import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Incoming-notification layer. Reports its preferred capsule size upward so
// the island can fit the content (Tide-island's size negotiation contract).
Item {
  id: root

  // Plain object: { appName, summary, body, urgency, cachedImage }
  property var notification: null

  readonly property string summary: notification ? (notification.summary || "") : ""
  readonly property string body: notification ? (notification.body || "") : ""
  readonly property string appName: notification ? (notification.appName || "") : ""
  readonly property bool critical: notification ? notification.urgency === 2 : false
  readonly property string image: notification ? (notification.cachedImage || "") : ""
  readonly property bool hasBody: body.length > 0

  readonly property int iconSize: Math.round(34 * Style.uiScaleRatio)

  TextMetrics {
    id: summaryMetrics
    text: root.summary
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Style.fontSizeM * Style.uiScaleRatio
    font.weight: Style.fontWeightBold
  }

  TextMetrics {
    id: bodyMetrics
    text: root.body
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Style.fontSizeS * Style.uiScaleRatio
  }

  // Size negotiation with the capsule
  readonly property real preferredWidth: {
    const chrome = Style.marginL * 2 + iconSize + Style.marginM;
    const text = Math.max(summaryMetrics.width, bodyMetrics.width) + Style.marginL;
    const minW = Math.round(280 * Style.uiScaleRatio);
    const maxW = Math.round(440 * Style.uiScaleRatio);
    return Math.round(Math.min(maxW, Math.max(minW, chrome + text)));
  }
  readonly property real preferredHeight: Math.round((hasBody ? 62 : 48) * Style.uiScaleRatio)

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginL
    anchors.rightMargin: Style.marginL
    spacing: Style.marginM

    // App image or fallback bell badge
    Item {
      Layout.preferredWidth: root.iconSize
      Layout.preferredHeight: root.iconSize
      Layout.alignment: Qt.AlignVCenter

      NImageRounded {
        anchors.fill: parent
        visible: root.image !== ""
        imagePath: root.image
        radius: width / 2
        borderWidth: 0
        imageFillMode: Image.PreserveAspectCrop
      }

      Rectangle {
        anchors.fill: parent
        visible: root.image === ""
        radius: width / 2
        color: root.critical ? Color.mError : Color.mPrimary

        NIcon {
          anchors.centerIn: parent
          icon: "bell"
          pointSize: Style.fontSizeM
          color: root.critical ? Color.mOnError : Color.mOnPrimary
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.marginXXS

      NText {
        Layout.fillWidth: true
        text: root.summary !== "" ? root.summary : root.appName
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      NText {
        Layout.fillWidth: true
        visible: root.hasBody
        text: root.body
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
  }
}
