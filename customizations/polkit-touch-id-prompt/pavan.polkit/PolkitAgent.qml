import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PolkitModel.js" as PolkitModel

Item {
  id: root

  property string fontFamily: Style.font.menuFamily
  // Bound to the central [polkit] section in shell.toml via Commons.Color.qml.
  property color accent: Commons.Color.polkit.accent
  property color background: Commons.Color.polkit.background
  property color foreground: Commons.Color.polkit.text
  property color border: Commons.Color.polkit.border
  property color borderError: Commons.Color.polkit.borderError
  property var borderSpec: Border.surfaceSpec("polkit", errorFlash ? "border-error" : "border", errorFlash ? borderError : border, Math.max(1, Style.space(2)), "border-alpha")
  property color scrim: Commons.Color.polkit.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int fieldHeight: Math.max(Style.space(42), Style.spacing.controlHeight)

  property bool closing: false
  property bool submitted: false
  property string currentMessage: ""
  property string currentPrompt: ""
  property string currentSupplementary: ""
  property bool responseRequired: false
  property bool responseVisible: false
  property bool failed: false
  property bool errorFlash: false
  // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
  property bool fingerprintConfigured: false
  // Lid shut right now — the reader is physically unreachable, so we fall back
  // to the password even when a sensor is enrolled. Refreshed per request.
  property bool laptopClosed: false
  property int shakeOffset: 0

  readonly property bool dialogVisible: polkitAgent.isActive || closing
  // We show one method at a time. Fingerprint owns the dialog while PAM is
  // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
  // a password — including immediately when the lid is shut and the clamshell
  // gate skips pam_fprintd — we switch to the password field instead.
  readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash
  readonly property int cardHeight: panel.height > 0 ? Math.min(fieldHeight + contentMargin * 2, panel.height - Style.gapsOut * 2) : fieldHeight + contentMargin * 2
  // Password mode is a wide field; fingerprint mode collapses to a square that
  // just frames the centered sensor icon.
  readonly property int cardWidth: fingerprintMode ? cardHeight : Math.min(Style.space(312), Math.max(Style.space(260), panel.width - Style.gapsOut * 2))

  function authorizationLabel(message) {
    return PolkitModel.authorizationLabel(message)
  }

  function loadPamConfig(raw) {
    fingerprintConfigured = PolkitModel.fingerprintConfiguredFromPamConfig(raw)
  }

  function refreshLidState() {
    if (!laptopClosedProc.running) laptopClosedProc.running = true
  }

  function resetSnapshot() {
    currentMessage = ""
    currentPrompt = ""
    currentSupplementary = ""
    responseRequired = false
    responseVisible = false
    failed = false
    errorFlash = false
    submitted = false
    passwordInput.text = ""
  }

  function syncFromFlow() {
    var flow = polkitAgent.flow
    if (!flow) return

    currentMessage = String(flow.message || "Authentication is needed...")
    currentPrompt = String(flow.inputPrompt || "")
    currentSupplementary = String(flow.supplementaryMessage || "")
    responseRequired = !!flow.isResponseRequired
    responseVisible = !!flow.responseVisible
    failed = !!flow.failed

    if (responseRequired) submitted = false
  }

  function beginFlow() {
    closeTimer.stop()
    closing = false
    submitted = false
    passwordInput.text = ""
    refreshLidState()
    syncFromFlow()
    Qt.callLater(refocus)
  }

  function refocus() {
    if (!dialogVisible) return
    // In fingerprint mode there is no field to type into — park focus on the
    // key catcher so Escape still cancels; otherwise focus the password field.
    if (fingerprintMode) keyCatcher.forceActiveFocus()
    else passwordInput.forceActiveFocus()
  }

  function submitResponse() {
    var flow = polkitAgent.flow
    if (!flow || !flow.isResponseRequired) return
    submitted = true
    errorFlash = false
    flow.submit(passwordInput.text)
    passwordInput.text = ""
    keyCatcher.forceActiveFocus()
  }

  function cancelRequest() {
    var flow = polkitAgent.flow
    passwordInput.text = ""
    submitted = false
    closing = true
    closeTimer.restart()
    if (flow) flow.cancelAuthenticationRequest()
  }

  function triggerFailureFeedback() {
    submitted = false
    errorFlash = true
    passwordInput.text = ""
    errorTimer.restart()
    shakeAnimation.restart()
    Qt.callLater(refocus)
  }

  Timer {
    id: closeTimer
    interval: 300
    repeat: false
    onTriggered: {
      closing = false
      resetSnapshot()
    }
  }

  Timer {
    id: errorTimer
    interval: 1200
    repeat: false
    onTriggered: root.errorFlash = false
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 50; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
  }
  FileView {
    path: "/etc/pam.d/polkit-1"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPamConfig(text())
    onLoadFailed: root.fingerprintConfigured = false
    onFileChanged: reload()
  }

  Process {
    id: laptopClosedProc
    command: ["bash", "-c", "omarchy-hw-laptop-closed && echo closed || echo open"]
    stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
    onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
  }

  PolkitAgent {
    id: polkitAgent
    path: "/org/omarchy/PolkitAgent"

    onAuthenticationRequestStarted: root.beginFlow()
    onIsActiveChanged: {
      if (isActive) root.syncFromFlow()
      else if (!root.closing) root.resetSnapshot()
    }
    onIsRegisteredChanged: {
      if (isRegistered) console.log("omarchy polkit agent registered")
      else console.warn("omarchy polkit agent is not registered; another agent may be running")
    }
  }

  Connections {
    target: polkitAgent.flow

    function onIsResponseRequiredChanged() {
      root.syncFromFlow()
      if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) passwordInput.text = ""
      Qt.callLater(root.refocus)
    }

    function onInputPromptChanged() { root.syncFromFlow() }
    function onResponseVisibleChanged() { root.syncFromFlow() }
    function onSupplementaryMessageChanged() { root.syncFromFlow() }
    function onFailedChanged() { root.syncFromFlow() }

    function onAuthenticationFailed() {
      root.syncFromFlow()
      root.triggerFailureFeedback()
    }

    function onAuthenticationSucceeded() {
      root.closing = true
      closeTimer.restart()
    }

    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  // macOS Touch ID-style sheet: one frosted card with a lock, a bold title
  // naming the action, a one-line instruction, then either the fingerprint
  // glyph or a password field, and the buttons along the bottom.
  readonly property string uiFamily: "Adwaita Sans"
  // Touch ID's glyph is pink-red in every macOS appearance and accent.
  readonly property color touchIdColor: "#ff375f"
  readonly property color errorColor: Commons.Color.polkit.textError
  readonly property string instruction: errorFlash ? "Try again."
    : submitted ? "Checking…"
    : fingerprintMode ? "Touch the fingerprint sensor to allow this."
    : "Enter your password to allow this."

  component SheetButton: Rectangle {
    id: sheetButton
    property string label: ""
    property bool primary: false
    signal activated()

    height: Style.space(30)
    radius: Style.space(8)
    color: primary
      ? (buttonArea.pressed ? Qt.darker(root.accent, 1.15) : root.accent)
      : Util.alpha(root.foreground, buttonArea.pressed ? 0.24 : (buttonArea.containsMouse ? 0.18 : 0.12))
    border.width: 1
    border.color: primary ? Util.alpha("#ffffff", 0.18) : Util.alpha(root.foreground, 0.10)

    Text {
      anchors.centerIn: parent
      text: sheetButton.label
      color: sheetButton.primary ? "#ffffff" : root.foreground
      font.family: root.uiFamily
      font.pixelSize: Style.font.body
      font.weight: sheetButton.primary ? Font.DemiBold : Font.Medium
    }

    MouseArea {
      id: buttonArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: sheetButton.activated()
    }
  }

  PanelWindow {
    id: panel
    visible: root.dialogVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.refocus()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(280), panel.width - Style.gapsOut * 2)
      height: sheet.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: Math.max(root.cornerRadius, Style.space(14))
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.shakeOffset
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.space(20)

      Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      MouseArea { anchors.fill: parent; onClicked: root.refocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRequest()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.responseRequired) root.submitResponse()
            event.accepted = true
          }
        }
      }

      Column {
        id: sheet
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.space(10)

        // Padlock badge, like the locked-app icon atop a macOS auth sheet.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(48)
          height: width
          radius: Style.space(12)
          color: Util.alpha(root.foreground, 0.10)
          border.width: 1
          border.color: Util.alpha(root.foreground, 0.12)

          Text {
            anchors.centerIn: parent
            text: ""
            color: root.errorFlash ? root.errorColor : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.authorizationLabel(root.currentMessage)
          color: root.foreground
          font.family: root.uiFamily
          font.pixelSize: Style.font.title
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.instruction
          color: root.errorFlash ? root.errorColor : Util.alpha(root.foreground, 0.65)
          font.family: root.uiFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }

        // Fingerprint mode: the large Touch ID glyph with a soft halo.
        Item {
          visible: root.fingerprintMode
          width: parent.width
          height: visible ? Style.space(76) : 0

          Rectangle {
            anchors.centerIn: parent
            width: Style.space(66)
            height: width
            radius: width / 2
            color: Util.alpha(root.errorFlash ? root.errorColor : root.touchIdColor, 0.12)
          }

          OpticalGlyph {
            anchors.centerIn: parent
            width: Style.space(48)
            height: width
            text: "󰈷"
            fontFamily: root.fontFamily
            fontSize: Style.space(48)
            color: root.errorFlash ? root.errorColor : root.touchIdColor
          }
        }

        // Password mode: a rounded macOS text field with a blue focus ring.
        Rectangle {
          id: field
          visible: !root.fingerprintMode
          width: parent.width
          height: visible ? Style.space(32) : 0
          radius: Style.space(7)
          color: Util.alpha(root.foreground, 0.08)
          border.width: passwordInput.activeFocus ? 2 : 1
          border.color: root.errorFlash ? root.errorColor
            : passwordInput.activeFocus ? Util.alpha(root.accent, 0.9)
            : Util.alpha(root.foreground, 0.16)

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnPress: true
            clip: true
            selectionColor: Util.alpha(root.accent, 0.45)
            selectedTextColor: root.foreground
            font.family: root.uiFamily
            font.pixelSize: Style.font.title
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            color: root.errorFlash ? root.errorColor : root.foreground
            cursorVisible: activeFocus && !root.submitted && !root.errorFlash
            readOnly: root.submitted || root.errorFlash
            enabled: root.dialogVisible
            onAccepted: root.submitResponse()
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.cancelRequest()
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            verticalAlignment: Text.AlignVCenter
            text: "Password"
            color: Util.alpha(root.foreground, 0.35)
            font.family: root.uiFamily
            font.pixelSize: Style.font.title
            visible: passwordInput.text.length === 0
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: field.visible
            cursorShape: Qt.IBeamCursor
            onClicked: passwordInput.forceActiveFocus()
          }
        }

        Item { width: 1; height: Style.space(2) }

        Row {
          id: buttons
          width: parent.width
          spacing: Style.space(8)
          readonly property bool showOk: !root.fingerprintMode

          SheetButton {
            width: buttons.showOk ? (buttons.width - buttons.spacing) / 2 : buttons.width
            label: "Cancel"
            onActivated: root.cancelRequest()
          }

          SheetButton {
            visible: buttons.showOk
            width: (buttons.width - buttons.spacing) / 2
            label: "OK"
            primary: true
            onActivated: root.submitResponse()
          }
        }
      }
    }
  }
}
