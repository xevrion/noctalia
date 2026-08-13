import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Compositor
import qs.Services.Media

// Compact resting layer: the familiar workspace pills, rendered inside the
// island capsule. Simplified from Modules/Bar/Widgets/Workspace.qml (no
// grouped/app-icon mode).
Item {
  id: root

  property ShellScreen screen
  property real capsuleHeight: 24

  readonly property string screenName: screen ? screen.name : ""

  // Fixed visual configuration (mirrors the Workspace widget defaults)
  readonly property string labelMode: "index"
  readonly property int fontWeight: Style.fontWeightBold
  readonly property int characterCount: 2
  readonly property real textRatio: 0.5
  readonly property bool showLabelsOnlyWhenOccupied: true
  readonly property string focusedColor: "primary"
  readonly property string occupiedColor: "secondary"
  readonly property string emptyColor: "secondary"
  readonly property real baseDimensionRatio: 0.66
  readonly property int spacingBetweenPills: Style.marginXS

  property ListModel localWorkspaces: ListModel {}
  property bool isDestroying: false
  property int refreshRevision: 0

  // Mini visualizer chip shown beside the pills while music plays
  readonly property bool chipVisible: MediaService.isPlaying
  readonly property int chipWidth: Math.round(20 * Style.uiScaleRatio)

  implicitWidth: {
    refreshRevision;
    let total = 0;
    for (var i = 0; i < localWorkspaces.count; i++) {
      total += getWorkspaceWidth(localWorkspaces.get(i));
    }
    if (localWorkspaces.count > 1)
      total += (localWorkspaces.count - 1) * spacingBetweenPills;
    if (chipVisible)
      total += chipWidth + spacingBetweenPills;
    return total;
  }

  function getWorkspaceWidth(ws, activeOverride) {
    const d = Math.round(capsuleHeight * baseDimensionRatio);
    const isActive = activeOverride !== undefined ? activeOverride : ws.isActive;
    const factor = isActive ? 2.2 : 1;

    if (labelMode === "none")
      return Style.toOdd(d * factor);

    var displayText = ws.idx.toString();
    if (ws.name && ws.name.length > 0 && labelMode === "name")
      displayText = ws.name.substring(0, characterCount);

    const textWidth = displayText.length * (d * 0.4);
    const padding = d * 0.6;
    return Style.toOdd(Math.max(d * factor, textWidth + padding));
  }

  function getWorkspaceHeight(ws, activeOverride) {
    const d = Math.round(capsuleHeight * baseDimensionRatio);
    const isActive = activeOverride !== undefined ? activeOverride : ws.isActive;
    const factor = isActive ? 2.2 : 1;
    return Style.toOdd(d * factor);
  }

  function switchByOffset(offset) {
    var focusedIndex = -1;
    for (var i = 0; i < localWorkspaces.count; i++) {
      if (localWorkspaces.get(i).isFocused) {
        focusedIndex = i;
        break;
      }
    }
    if (focusedIndex === -1)
      return;
    const target = focusedIndex + offset;
    if (target < 0 || target >= localWorkspaces.count)
      return;
    CompositorService.switchToWorkspace(localWorkspaces.get(target));
  }

  // Deferred via Qt.callLater to avoid synchronous ListModel mutations during
  // signal cascades (same pattern as the Workspace bar widget)
  function scheduleRefresh() {
    if (!isDestroying)
      Qt.callLater(root.refreshWorkspaces);
  }

  Component.onCompleted: scheduleRefresh()
  Component.onDestruction: isDestroying = true
  onScreenNameChanged: scheduleRefresh()

  Connections {
    target: CompositorService
    function onWorkspacesChanged() {
      root.scheduleRefresh();
    }
    function onWindowListChanged() {
      root.scheduleRefresh();
    }
  }

  function refreshWorkspaces() {
    var targetList = [];
    if (screen !== null) {
      const name = screen.name.toLowerCase();
      for (var i = 0; i < CompositorService.workspaces.count; i++) {
        const ws = CompositorService.workspaces.get(i);
        const matchesScreen = CompositorService.globalWorkspaces || ws.output.toLowerCase() === name;
        if (!matchesScreen)
          continue;

        var workspaceData = {
          id: ws.id,
          idx: ws.idx,
          name: ws.name,
          output: ws.output,
          isFocused: ws.isFocused,
          isActive: ws.isActive,
          isUrgent: ws.isUrgent,
          isOccupied: ws.isOccupied
        };
        if (ws.handle !== null && ws.handle !== undefined)
          workspaceData.handle = ws.handle;

        targetList.push(workspaceData);
      }
    }

    // In-place update to preserve delegates for animations
    var i = 0;
    while (i < localWorkspaces.count || i < targetList.length) {
      if (i < localWorkspaces.count && i < targetList.length) {
        var existing = localWorkspaces.get(i);
        if (existing.id === targetList[i].id) {
          localWorkspaces.set(i, targetList[i]);
          i++;
        } else {
          localWorkspaces.remove(i);
        }
      } else if (i < localWorkspaces.count) {
        localWorkspaces.remove(i);
      } else {
        localWorkspaces.append(targetList[i]);
        i++;
      }
    }

    refreshRevision++;
  }

  Row {
    id: pillRow
    anchors.centerIn: parent
    spacing: root.spacingBetweenPills

    Repeater {
      model: root.localWorkspaces
      delegate: WorkspacePill {
        required property var model

        workspace: model
        isVertical: false
        baseDimensionRatio: root.baseDimensionRatio
        capsuleHeight: root.capsuleHeight
        barHeight: root.height
        labelMode: root.labelMode
        fontWeight: root.fontWeight
        characterCount: root.characterCount
        textRatio: root.textRatio
        showLabelsOnlyWhenOccupied: root.showLabelsOnlyWhenOccupied
        focusedColor: root.focusedColor
        occupiedColor: root.occupiedColor
        emptyColor: root.emptyColor
        masterProgress: 0
        effectsActive: false
        effectColor: Color.mPrimary
        getWorkspaceWidth: root.getWorkspaceWidth
        getWorkspaceHeight: root.getWorkspaceHeight
      }
    }

    // Mini visualizer chip: three bars fed by the shared spectrum service
    Item {
      id: chip
      visible: root.chipVisible
      width: root.chipWidth
      height: root.capsuleHeight
      anchors.verticalCenter: parent.verticalCenter

      readonly property string spectrumComponentId: "island:chip:" + root.screenName
      readonly property bool needsSpectrum: root.chipVisible && root.visible

      onNeedsSpectrumChanged: {
        if (needsSpectrum) {
          SpectrumService.registerComponent(spectrumComponentId);
        } else {
          SpectrumService.unregisterComponent(spectrumComponentId);
        }
      }

      Component.onDestruction: SpectrumService.unregisterComponent(spectrumComponentId)

      Row {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
          model: 3
          delegate: Rectangle {
            required property int index

            readonly property real level: {
              const values = SpectrumService.values;
              if (!values || values.length === 0)
                return 0;
              const pick = Math.min(values.length - 1, Math.floor(values.length * (0.2 + index * 0.3)));
              return Math.max(0, Math.min(1, values[pick]));
            }

            width: 3
            height: Math.round(4 + (root.capsuleHeight * 0.55 - 4) * level)
            radius: width / 2
            color: Color.mPrimary
            anchors.verticalCenter: parent.verticalCenter

            Behavior on height {
              NumberAnimation {
                duration: 90
                easing.type: Easing.InOutQuad
              }
            }
          }
        }
      }
    }
  }
}
