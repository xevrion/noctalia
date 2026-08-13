import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.System
import qs.Services.UI

// macOS-style dynamic island replacing the workspace pill in the bar center.
// Lives in its own full-width overlay window so the capsule can morph beyond
// the bar's bounds. Geometry & motion inspired by enhaoswen/Tide-island.
PanelWindow {
  id: root

  readonly property string screenName: screen ? screen.name : ""
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real floatOffset: Settings.data.bar.barType === "floating" ? Math.ceil(Settings.data.bar.marginVertical ?? 0) : 0
  readonly property real capsuleY: floatOffset + Math.max(1, Math.round((barHeight - capsuleHeight) / 2))

  // ---------------------------------------------------------------------------
  // State machine (single string, everything else derives from it):
  //   "normal"       compact workspace pills (resting state)
  //   "nowplaying"   transient track-change capsule (art + scrolling title)
  //   "split"        transient volume / input volume / brightness OSD
  //   "notification" incoming notification popup
  //   "expanded"     media player card
  property string islandState: "normal"

  // 0 = volume, 1 = input volume, 2 = brightness (matches OSD.Type order)
  property int osdType: 0
  property real currentBrightness: 0
  property bool startupComplete: false
  property var currentNotification: null

  readonly property bool hasPlayer: MediaService.currentPlayer !== null

  // ---------------------------------------------------------------------------
  // Swipe carousel across the resting pages (Tide-island's swipeProgress model):
  //   -1 = info (clock / battery), 0 = workspaces, +1 = music
  property int pageIndex: 0
  property real swipeProgress: 0
  property bool swipeDragging: false
  readonly property real slideDistance: Math.round(56 * Style.uiScaleRatio)
  readonly property bool musicPageAvailable: hasPlayer && MediaService.trackTitle !== ""

  Behavior on swipeProgress {
    enabled: !root.swipeDragging
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(a, b, t) {
    return a + (b - a) * t;
  }

  // How visible a carousel page is at the current swipe position
  function pageOpacity(pageOffset) {
    return clamp(1 - Math.abs(swipeProgress - pageOffset), 0, 1);
  }

  function settleSwipe() {
    const delta = swipeProgress - pageIndex;
    let target = pageIndex;
    if (delta > 0.4)
      target = pageIndex + 1;
    else if (delta < -0.4)
      target = pageIndex - 1;
    target = clamp(target, -1, musicPageAvailable ? 1 : 0);
    pageIndex = target;
    swipeProgress = target;
  }

  Timer {
    id: wheelSettleTimer
    interval: 150
    onTriggered: root.settleSwipe()
  }

  // ---------------------------------------------------------------------------
  // Geometry — compact is a full pill, expanded uses the island 0.24 ratio
  readonly property real pillsWidth: workspacesLayer.implicitWidth
  readonly property real normalWidth: Math.max(Math.round(64 * Style.uiScaleRatio), Math.round(pillsWidth + Style.marginM * 2))
  readonly property real splitWidth: Math.round(250 * Style.uiScaleRatio)
  readonly property real expandedWidth: Math.min(Math.round(410 * Style.uiScaleRatio), screen ? screen.width - 48 : 410)
  readonly property real expandedHeight: Math.round(165 * Style.uiScaleRatio)

  // Compact width interpolates between adjacent page widths while swiping
  readonly property real carouselWidth: {
    const p = swipeProgress;
    if (p <= 0)
      return Math.round(lerp(infoLayer.preferredWidth, normalWidth, p + 1));
    return Math.round(lerp(normalWidth, nowPlayingLayer.preferredWidth, p));
  }

  readonly property real targetWidth: {
    switch (islandState) {
    case "nowplaying":
      return nowPlayingLayer.preferredWidth;
    case "split":
      return splitWidth;
    case "notification":
      return notificationLayer.preferredWidth;
    case "expanded":
      return expandedWidth;
    default:
      return carouselWidth;
    }
  }

  readonly property real targetHeight: {
    switch (islandState) {
    case "notification":
      return notificationLayer.preferredHeight;
    case "expanded":
      return expandedHeight;
    default:
      return capsuleHeight;
    }
  }

  readonly property real targetRadius: {
    switch (islandState) {
    case "notification":
      return Math.min(Math.round(targetHeight / 2), Math.round(28 * Style.uiScaleRatio));
    case "expanded":
      return Math.round(targetHeight * 0.24);
    default:
      return Math.round(targetHeight / 2);
    }
  }

  // ~400ms by default, honors the user's animation speed factor / disable switch
  readonly property int morphDuration: Math.round(Style.animationSlow * 0.9)

  // ---------------------------------------------------------------------------
  // Window sizing: layer-shell surface must grow before the capsule animates
  // and shrink only after the animation is done (Tide-island's retained-height
  // reconciliation pattern).
  readonly property int requestedWindowHeight: Math.ceil(capsuleY + targetHeight + 8)
  property int retainedWindowHeight: 0

  onRequestedWindowHeightChanged: reconcileWindowHeight()
  Component.onCompleted: {
    reconcileWindowHeight();
    publishCompactWidth();
    DynamicIslandService.registerOverlay(screenName, root);
  }

  function reconcileWindowHeight() {
    if (requestedWindowHeight >= retainedWindowHeight) {
      retainedWindowHeight = requestedWindowHeight;
      windowShrinkTimer.stop();
    } else {
      windowShrinkTimer.restart();
    }
  }

  Timer {
    id: windowShrinkTimer
    interval: 700
    onTriggered: root.retainedWindowHeight = root.requestedWindowHeight
  }

  onNormalWidthChanged: publishCompactWidth()
  onScreenNameChanged: publishCompactWidth()

  function publishCompactWidth() {
    DynamicIslandService.setCompactWidth(screenName, Math.round(normalWidth));
  }

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: Math.max(requestedWindowHeight, retainedWindowHeight, Math.ceil(barHeight))
  color: "transparent"

  WlrLayershell.namespace: "noctalia-dynamic-island-" + screenName
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // Only the capsule is interactive; the rest of the strip is click-through
  mask: Region {
    x: capsule.x
    y: capsule.y
    width: capsule.width
    height: capsule.height
  }

  // ---------------------------------------------------------------------------
  // State transitions
  function showOsd(type) {
    if (!startupComplete)
      return;
    // Don't fight the player card or an active notification
    if (islandState === "expanded" || islandState === "notification")
      return;
    osdType = type;
    islandState = "split";
    autoHideTimer.interval = 1250;
    autoHideTimer.restart();
  }

  function showNotification() {
    if (NotificationService.popupModel.count === 0)
      return;
    // Plain copy: the live row object becomes invalid once the popup expires
    const row = NotificationService.popupModel.get(0);
    currentNotification = {
      "id": row.id,
      "appName": row.appName,
      "summary": row.summary,
      "body": row.body,
      "urgency": row.urgency,
      "cachedImage": row.cachedImage
    };
    islandState = "notification";
    autoHideTimer.interval = 4200;
    autoHideTimer.restart();
  }

  function showNowPlaying() {
    if (!startupComplete || !MediaService.isPlaying || MediaService.trackTitle === "")
      return;
    // Only from resting states — never interrupt OSD, notifications or the card
    if (islandState !== "normal" && islandState !== "nowplaying")
      return;
    islandState = "nowplaying";
    autoHideTimer.interval = 3500;
    autoHideTimer.restart();
  }

  function expandPlayer() {
    if (!hasPlayer)
      return;
    autoHideTimer.stop();
    islandState = "expanded";
  }

  function collapse() {
    autoHideTimer.stop();
    islandState = "normal";
  }

  function toggleExpanded() {
    if (islandState === "expanded") {
      collapse();
    } else {
      expandPlayer();
    }
  }

  function swipeTo(index) {
    const target = clamp(index, -1, musicPageAvailable ? 1 : 0);
    if (islandState !== "normal")
      collapse();
    pageIndex = target;
    swipeProgress = target;
  }

  Timer {
    id: autoHideTimer
    onTriggered: {
      // Keep transient states alive while the cursor is on the capsule
      if (capsuleHover.hovered) {
        restart();
        return;
      }
      root.collapse();
    }
  }

  Timer {
    id: startupTimer
    interval: 2500
    running: true
    onTriggered: root.startupComplete = true
  }

  // Hover-intent expand (macOS style): the dwell only counts while the cursor
  // is at rest — any movement resets it, and pressing cancels it outright, so
  // hover never fights swipes or clicks.
  Timer {
    id: hoverExpandTimer
    interval: 550
    onTriggered: {
      if (capsuleHover.hovered && !root.swipeDragging && !capsuleMouseArea.pressed && (root.islandState === "normal" || root.islandState === "nowplaying") && MediaService.isPlaying)
        root.expandPlayer();
    }
  }

  Timer {
    id: hoverCollapseTimer
    interval: 250
    onTriggered: {
      if (!capsuleHover.hovered && root.islandState === "expanded")
        root.collapse();
    }
  }

  // ---------------------------------------------------------------------------
  // Event sources
  Connections {
    target: AudioService
    function onVolumeChanged() {
      root.showOsd(0);
    }
    function onMutedChanged() {
      root.showOsd(0);
    }
    function onInputVolumeChanged() {
      root.showOsd(1);
    }
    function onInputMutedChanged() {
      root.showOsd(1);
    }
  }

  Connections {
    target: MediaService
    function onTrackTitleChanged() {
      Qt.callLater(root.showNowPlaying);
    }
    function onCurrentPlayerChanged() {
      if (!MediaService.currentPlayer && (root.islandState === "expanded" || root.islandState === "nowplaying"))
        root.collapse();
      // Music page can't stay active without a player
      if (!root.musicPageAvailable && root.pageIndex === 1) {
        root.pageIndex = 0;
        root.swipeProgress = 0;
      }
    }
  }

  function onBrightnessChanged(newBrightness) {
    currentBrightness = newBrightness;
    showOsd(2);
  }

  function connectBrightnessMonitors() {
    if (!BrightnessService.monitors)
      return;
    for (var i = 0; i < BrightnessService.monitors.length; i++) {
      try {
        BrightnessService.monitors[i].brightnessUpdated.disconnect(root.onBrightnessChanged);
      } catch (e) {

        // Not connected yet
      }
      BrightnessService.monitors[i].brightnessUpdated.connect(root.onBrightnessChanged);
    }
  }

  Connections {
    target: BrightnessService
    function onMonitorsChanged() {
      root.connectBrightnessMonitors();
    }
  }

  Timer {
    interval: 2000
    running: true
    onTriggered: root.connectBrightnessMonitors()
  }

  Component.onDestruction: {
    DynamicIslandService.unregisterOverlay(screenName);
    if (!BrightnessService.monitors)
      return;
    for (var i = 0; i < BrightnessService.monitors.length; i++) {
      try {
        BrightnessService.monitors[i].brightnessUpdated.disconnect(root.onBrightnessChanged);
      } catch (e) {

        // Already disconnected
      }
    }
  }

  Connections {
    target: NotificationService.popupModel
    function onCountChanged() {
      if (NotificationService.popupModel.count > 0) {
        // Deferred: activating synchronously inside ListModel.insert() can
        // crash QML incubation (same guard as Modules/Notification)
        Qt.callLater(root.showNotification);
      } else if (root.islandState === "notification") {
        Qt.callLater(root.collapse);
      }
    }
  }

  // OSD display values (mirrors Modules/OSD logic)
  readonly property real osdMax: (osdType !== 2 && Settings.data.audio.volumeOverdrive) ? 1.5 : 1.0
  readonly property real osdValue: {
    switch (osdType) {
    case 0:
      return AudioService.muted ? 0 : AudioService.volume;
    case 1:
      return AudioService.inputMuted ? 0 : AudioService.inputVolume;
    default:
      return currentBrightness;
    }
  }

  readonly property string osdIcon: {
    const epsilon = 0.005;
    switch (osdType) {
    case 0:
      if (AudioService.muted)
        return "volume-mute";
      if (AudioService.volume < epsilon)
        return "volume-x";
      return AudioService.volume <= 0.5 ? "volume-low" : "volume-high";
    case 1:
      return AudioService.inputMuted ? "microphone-off" : "microphone";
    default:
      if (currentBrightness < epsilon)
        return "sun-off";
      return currentBrightness <= 0.5 ? "brightness-low" : "brightness-high";
    }
  }

  // ---------------------------------------------------------------------------
  // The capsule
  Rectangle {
    id: capsule

    x: Math.round((parent.width - width) / 2)
    y: root.capsuleY
    width: Math.round(root.targetWidth)
    height: Math.round(root.targetHeight)
    radius: root.targetRadius
    color: root.islandState === "normal" ? Style.capsuleColor : Qt.alpha(Color.mSurface, 0.98)
    border.color: Style.capsuleBorderColor
    border.width: Math.max(1, Style.capsuleBorderWidth)
    clip: true

    // Silky easeOutExpo-style bezier; 1:1 finger tracking while dragging
    Behavior on width {
      NumberAnimation {
        duration: root.swipeDragging ? 0 : root.morphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
      }
    }
    Behavior on height {
      NumberAnimation {
        duration: root.morphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
      }
    }
    Behavior on radius {
      NumberAnimation {
        duration: root.morphDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
      }
    }
    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: 280
        easing.type: Easing.InOutQuad
      }
    }

    HoverHandler {
      id: capsuleHover
      onHoveredChanged: {
        if (hovered) {
          hoverCollapseTimer.stop();
          hoverExpandTimer.restart();
        } else {
          hoverExpandTimer.stop();
          hoverCollapseTimer.restart();
        }
      }
    }

    // Background interactions (workspace pills keep their own mouse areas on top)
    MouseArea {
      id: capsuleMouseArea
      anchors.fill: parent
      z: 0
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

      property real pressX: 0
      property real pressProgress: 0
      property bool didDrag: false

      onPressed: mouse => {
        // A press means click-or-drag intent, never hover
        hoverExpandTimer.stop();
        pressX = mouse.x;
        pressProgress = root.swipeProgress;
        didDrag = false;
      }

      onPositionChanged: mouse => {
        if (!pressed) {
          // Hover intent: only a cursor at rest counts towards the dwell
          if (root.islandState === "normal" || root.islandState === "nowplaying")
            hoverExpandTimer.restart();
          return;
        }
        if (root.islandState !== "normal")
          return;
        const dx = mouse.x - pressX;
        if (!didDrag && Math.abs(dx) < 6)
          return;
        didDrag = true;
        root.swipeDragging = true;
        const unit = Math.round(110 * Style.uiScaleRatio);
        root.swipeProgress = root.clamp(pressProgress - dx / unit, -1, root.musicPageAvailable ? 1 : 0);
      }

      onReleased: {
        if (didDrag) {
          root.swipeDragging = false;
          root.settleSwipe();
        }
      }

      onCanceled: {
        root.swipeDragging = false;
        root.settleSwipe();
      }

      onClicked: mouse => {
        if (didDrag)
          return;
        switch (root.islandState) {
        case "normal":
        case "nowplaying":
          if (mouse.button === Qt.LeftButton)
            root.expandPlayer();
          break;
        case "notification":
          if (mouse.button === Qt.LeftButton && root.currentNotification)
            NotificationService.removePopup(root.currentNotification.id);
          root.collapse();
          break;
        case "split":
          root.collapse();
          break;
        default:
          if (mouse.button === Qt.RightButton)
            root.collapse();
          break;
        }
      }

      onWheel: wheel => {
        if (root.islandState !== "normal")
          return;
        const dx = wheel.angleDelta.x;
        const dy = wheel.angleDelta.y;
        if (Math.abs(dx) > Math.abs(dy)) {
          // Horizontal scroll drives the carousel
          root.swipeProgress = root.clamp(root.swipeProgress - dx / 480, -1, root.musicPageAvailable ? 1 : 0);
          wheelSettleTimer.restart();
          return;
        }
        const direction = (dy > 0) !== Settings.data.general.reverseScroll ? -1 : 1;
        workspacesLayer.switchByOffset(direction);
      }
    }

    // -------------------------------------------------------------------------
    // Layers — fixed sizes anchored to the capsule's top-center so the morph
    // clips/reveals them instead of re-laying them out every animation frame.
    // Cross-fade: slow in, fast out (Tide-island asymmetry). Carousel pages
    // combine a state fade (animated) with a swipe factor (finger-tracked).
    WorkspacesLayer {
      id: workspacesLayer
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: implicitWidth
      height: root.capsuleHeight
      screen: root.screen
      capsuleHeight: root.capsuleHeight

      property real stateFade: root.islandState === "normal" ? 1 : 0
      Behavior on stateFade {
        NumberAnimation {
          duration: root.islandState === "normal" ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }

      visible: opacity > 0
      opacity: stateFade * root.pageOpacity(0)
      transform: Translate {
        x: (0 - root.swipeProgress) * root.slideDistance
      }
    }

    InfoLayer {
      id: infoLayer
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: preferredWidth
      height: root.capsuleHeight

      property real stateFade: root.islandState === "normal" ? 1 : 0
      Behavior on stateFade {
        NumberAnimation {
          duration: root.islandState === "normal" ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }

      visible: opacity > 0
      opacity: stateFade * root.pageOpacity(-1)
      transform: Translate {
        x: (-1 - root.swipeProgress) * root.slideDistance
      }
    }

    NowPlayingLayer {
      id: nowPlayingLayer
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: preferredWidth
      height: root.capsuleHeight

      // Doubles as the track-change transient and the right carousel page
      property real stateFade: (root.islandState === "nowplaying" || root.islandState === "normal") ? 1 : 0
      Behavior on stateFade {
        NumberAnimation {
          duration: (root.islandState === "nowplaying" || root.islandState === "normal") ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }

      visible: opacity > 0
      opacity: stateFade * (root.islandState === "nowplaying" ? 1 : root.pageOpacity(1))
      transform: Translate {
        x: root.islandState === "normal" ? (1 - root.swipeProgress) * root.slideDistance : 0
      }
    }

    OsdLayer {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: root.splitWidth
      height: root.capsuleHeight
      icon: root.osdIcon
      value: root.osdValue
      maxValue: root.osdMax
      muted: (root.osdType === 0 && AudioService.muted) || (root.osdType === 1 && AudioService.inputMuted)
      visible: opacity > 0
      opacity: root.islandState === "split" ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: root.islandState === "split" ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }
      transform: Translate {
        y: root.islandState === "split" ? 0 : -Math.round(6 * Style.uiScaleRatio)
        Behavior on y {
          NumberAnimation {
            duration: root.islandState === "split" ? Style.animationNormal : Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    NotificationLayer {
      id: notificationLayer
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: preferredWidth
      height: preferredHeight
      notification: root.currentNotification
      visible: opacity > 0
      opacity: root.islandState === "notification" ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: root.islandState === "notification" ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }
      transform: Translate {
        y: root.islandState === "notification" ? 0 : -Math.round(10 * Style.uiScaleRatio)
        Behavior on y {
          NumberAnimation {
            duration: root.islandState === "notification" ? Style.animationNormal : Style.animationFast
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    PlayerLayer {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      width: root.expandedWidth
      height: root.expandedHeight
      screenName: root.screenName
      // Keep the spectrum registered through the fade-out
      active: root.islandState === "expanded" || opacity > 0
      visible: opacity > 0
      opacity: root.islandState === "expanded" ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: root.islandState === "expanded" ? Style.animationNormal : Style.animationFast
          easing.type: Easing.InOutQuad
        }
      }

      // Subtle pop: the card scales up from the capsule's top edge
      transformOrigin: Item.Top
      scale: root.islandState === "expanded" ? 1 : 0.96
      Behavior on scale {
        NumberAnimation {
          duration: root.islandState === "expanded" ? root.morphDuration : Style.animationFast
          easing.type: Easing.BezierSpline
          easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
        }
      }
    }
  }
}
