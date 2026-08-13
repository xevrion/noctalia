import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Media
import qs.Widgets
import qs.Widgets.AudioSpectrum

// Expanded media player card: album art, track info, seek bar, controls and a
// soft spectrum backdrop while music plays.
Item {
  id: root

  property string screenName: ""
  // True while the island is in the "expanded" state (gates cava registration)
  property bool active: false

  readonly property bool hasPlayer: MediaService.currentPlayer !== null
  readonly property int artSize: Math.round(84 * Style.uiScaleRatio)

  readonly property string spectrumComponentId: "island:player:" + screenName

  onActiveChanged: {
    if (active) {
      SpectrumService.registerComponent(spectrumComponentId);
    } else {
      SpectrumService.unregisterComponent(spectrumComponentId);
    }
  }

  Component.onDestruction: SpectrumService.unregisterComponent(spectrumComponentId)

  // Soft visualizer backdrop
  NLinearSpectrum {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Style.marginXL
    anchors.rightMargin: Style.marginXL
    height: Math.round(26 * Style.uiScaleRatio)
    values: SpectrumService.values
    fillColor: Color.mPrimary
    opacity: MediaService.isPlaying ? 0.25 : 0
    barPosition: "top"

    Behavior on opacity {
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.InOutQuad
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginS

    // Art + track info
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginM

      NImageRounded {
        Layout.preferredWidth: root.artSize
        Layout.preferredHeight: root.artSize
        Layout.alignment: Qt.AlignVCenter
        imagePath: MediaService.trackArtUrl
        radius: Math.round(root.artSize * 0.22)
        borderWidth: 0
        imageFillMode: Image.PreserveAspectCrop
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.marginXXS

        NText {
          Layout.fillWidth: true
          text: root.hasPlayer ? MediaService.trackTitle : I18n.tr("bar.media-mini.no-active-player")
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        NText {
          Layout.fillWidth: true
          visible: MediaService.trackArtist !== ""
          text: MediaService.trackArtist
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        NText {
          Layout.fillWidth: true
          visible: MediaService.playerIdentity !== ""
          text: MediaService.playerIdentity
          pointSize: Style.fontSizeXS
          color: Qt.alpha(Color.mOnSurfaceVariant, 0.7)
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }

    // Seek bar
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        text: MediaService.positionString
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
      }

      Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        height: Math.max(12, Math.round(12 * Style.uiScaleRatio))

        Rectangle {
          id: seekTrack
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Math.max(4, Math.round(4 * Style.uiScaleRatio))
          radius: height / 2
          color: Qt.alpha(Color.mOnSurface, 0.25)

          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * (MediaService.trackLength > 0 ? Math.min(1, MediaService.currentPosition / MediaService.trackLength) : 0)
            height: parent.height
            radius: parent.radius
            color: Color.mPrimary

            Behavior on width {
              NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.hasPlayer && MediaService.canSeek
          cursorShape: Qt.PointingHandCursor
          onClicked: mouse => MediaService.seekByRatio(mouse.x / width)
        }
      }

      NText {
        text: MediaService.lengthString
        pointSize: Style.fontSizeXS
        color: Color.mOnSurfaceVariant
      }
    }

    // Controls
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.marginXL

      IslandMediaButton {
        icon: "media-prev"
        enabled: MediaService.canGoPrevious
        onTriggered: MediaService.previous()
      }

      IslandMediaButton {
        icon: MediaService.isPlaying ? "media-pause" : "media-play"
        enabled: MediaService.canPlay || MediaService.canPause
        highlighted: true
        onTriggered: MediaService.playPause()
      }

      IslandMediaButton {
        icon: "media-next"
        enabled: MediaService.canGoNext
        onTriggered: MediaService.next()
      }
    }
  }

  component IslandMediaButton: Rectangle {
    id: button

    property string icon: ""
    property bool highlighted: false

    signal triggered

    readonly property int buttonSize: Math.round((highlighted ? 34 : 28) * Style.uiScaleRatio)

    width: buttonSize
    height: buttonSize
    radius: buttonSize / 2
    color: highlighted ? Color.mPrimary : (buttonArea.containsMouse ? Color.mHover : "transparent")
    opacity: enabled ? 1.0 : 0.4
    scale: buttonArea.pressed ? 0.85 : 1.0

    Behavior on scale {
      NumberAnimation {
        duration: 100
      }
    }
    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }

    NIcon {
      anchors.centerIn: parent
      icon: button.icon
      pointSize: button.highlighted ? Style.fontSizeL : Style.fontSizeM
      color: button.highlighted ? Color.mOnPrimary : Color.mOnSurface
    }

    MouseArea {
      id: buttonArea
      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      enabled: button.enabled
      onClicked: button.triggered()
    }
  }
}
