import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Media
import qs.Widgets

// Transient track-change capsule: album art + scrolling "title — artist".
Item {
  id: root

  readonly property string title: {
    const track = MediaService.trackTitle;
    const artist = MediaService.trackArtist;
    return artist ? `${track} · ${artist}` : track;
  }

  readonly property int artSize: Math.round(18 * Style.uiScaleRatio)
  readonly property real maxTextWidth: Math.round(220 * Style.uiScaleRatio)

  TextMetrics {
    id: titleMetrics
    text: root.title
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Style.fontSizeM * Style.uiScaleRatio
    font.weight: Style.fontWeightMedium
  }

  readonly property real preferredWidth: {
    const chrome = Style.marginL * 2 + artSize + Style.marginS;
    const text = Math.min(maxTextWidth, titleMetrics.width + Style.marginS);
    return Math.round(Math.max(Math.round(180 * Style.uiScaleRatio), chrome + text));
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.marginL
    anchors.rightMargin: Style.marginL
    spacing: Style.marginS

    Item {
      Layout.preferredWidth: root.artSize
      Layout.preferredHeight: root.artSize
      Layout.alignment: Qt.AlignVCenter

      NImageRounded {
        anchors.fill: parent
        visible: MediaService.trackArtUrl !== ""
        imagePath: MediaService.trackArtUrl
        radius: width / 2
        borderWidth: 0
        imageFillMode: Image.PreserveAspectCrop
      }

      Rectangle {
        anchors.fill: parent
        visible: MediaService.trackArtUrl === ""
        radius: width / 2
        color: Color.mPrimary

        NIcon {
          anchors.centerIn: parent
          icon: "disc"
          pointSize: Style.fontSizeXS
          color: Color.mOnPrimary
        }
      }
    }

    NScrollText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: parent.height
      text: root.title
      scrollMode: NScrollText.ScrollMode.Always
      maxWidth: root.maxTextWidth
      fadeExtent: 0.12

      NText {
        color: Color.mOnSurface
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        elide: Text.ElideNone
      }
    }
  }
}
