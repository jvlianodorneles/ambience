import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dorneles.ambience"

  // Settings
  property string currentMode: (settings && settings.mode !== undefined) ? String(settings.mode) : setting("mode", "always")
  readonly property string defaultPreset: setting("defaultPreset", "rain")
  readonly property int defaultVolume: setting("defaultVolume", 60)
  readonly property bool showLabelSetting: setting("showLabel", true)

  onSettingsChanged: {
    currentMode = (settings && settings.mode !== undefined) ? String(settings.mode) : setting("mode", "always")
  }

  // Bar visibility: in active-only mode, only show on bar when sound is playing
  readonly property bool isWidgetVisible: currentMode === "always" || isPlaying

  // Live state
  property bool isPlaying: false
  property string currentPreset: "rain"
  property int currentVolume: 60
  property int sleepTimerMin: 0
  property int timerRemainingSec: 0

  readonly property string soundsFolderPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/dorneles.ambience/sounds"

  readonly property var presetIcons: ({
    "rain": "\udb81\udd97",
    "waves": "\udb82\udd3d",
    "campfire": "\udb80\ude38",
    "brown": "\udb81\udf5a",
    "pink": "\udb81\udf5a",
    "white": "\udb81\udf5a",
    "binaural": "\udb80\udecb",
    "cafe": "\udb80\udd56"
  })

  readonly property var presetNames: ({
    "rain": "Rain Shower",
    "waves": "Ocean Waves",
    "campfire": "Campfire",
    "brown": "Brown Noise",
    "pink": "Pink Noise",
    "white": "White Noise",
    "binaural": "Binaural Alpha",
    "cafe": "Café Ambience"
  })

  property var presetList: [
    { id: "rain", name: "Rain", icon: "\udb81\udd97", desc: "Rain shower" },
    { id: "waves", name: "Waves", icon: "\udb82\udd3d", desc: "Ocean surf" },
    { id: "campfire", name: "Campfire", icon: "\udb80\ude38", desc: "Wood crackle" },
    { id: "brown", name: "Brown Noise", icon: "\udb81\udf5a", desc: "Deep rumble" },
    { id: "pink", name: "Pink Noise", icon: "\udb81\udf5a", desc: "Natural 1/f" },
    { id: "white", name: "White Noise", icon: "\udb81\udf5a", desc: "Static mask" },
    { id: "binaural", name: "Binaural", icon: "\udb80\udecb", desc: "10Hz Alpha" },
    { id: "cafe", name: "Café", icon: "\udb80\udd56", desc: "Coffee shop" }
  ]

  readonly property string activeIcon: presetIcons[currentPreset] || "\udb81\udf5a"
  readonly property string activeName: presetNames[currentPreset] || currentPreset

  readonly property string ctlScriptPath: Qt.resolvedUrl("scripts/ambience-ctl.sh").toString().replace(/^file:\/\//, "")

  function refresh() {
    if (statusProc.running) return
    statusProc.running = true
  }

  function reloadPresets() {
    if (presetsProc.running) return
    presetsProc.running = true
  }

  function togglePlay() {
    runCommand(["toggle", currentPreset, String(currentVolume)])
  }

  function setPreset(name) {
    currentPreset = name
    runCommand(["preset", name])
  }

  function setVolume(vol) {
    currentVolume = Math.max(0, Math.min(100, vol))
    runCommand(["volume", String(currentVolume)])
  }

  function adjustVolume(delta) {
    setVolume(currentVolume + delta)
  }

  function setTimer(minutes) {
    sleepTimerMin = minutes
    runCommand(["timer", String(minutes)])
  }

  function cyclePreset() {
    var presets = ["rain", "waves", "campfire", "brown", "pink", "white", "binaural", "cafe"]
    var idx = presets.indexOf(currentPreset)
    var next = presets[(idx + 1) % presets.length]
    setPreset(next)
  }

  function runCommand(args) {
    if (cmdProc.running) return
    var full = [root.ctlScriptPath].concat(args)
    cmdProc.command = full
    cmdProc.running = true
  }

  function openStudio() {
    studioWindow.open = true
    root.reloadPresets()
  }

  function closeStudio() {
    studioWindow.open = false
  }

  function toggleStudio() {
    studioWindow.open = !studioWindow.open
    if (studioWindow.open) root.reloadPresets()
  }

  function openSoundsFolder() {
    Qt.openUrlExternally("file://" + root.soundsFolderPath)
  }

  function openUrl(url) {
    Qt.openUrlExternally(url)
  }

  function formatTimer(sec) {
    if (sec <= 0) return ""
    var m = Math.floor(sec / 60)
    var s = sec % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  Component.onCompleted: {
    refresh()
    reloadPresets()
  }

  IpcHandler {
    target: "dorneles.ambience"
    function toggle(): void { root.togglePlay() }
    function play(): void { root.runCommand(["play", root.currentPreset, String(root.currentVolume)]) }
    function stop(): void { root.runCommand(["stop"]) }
    function next(): void { root.cyclePreset() }
    function volume(vol: string): void { root.setVolume(parseInt(vol) || 60) }
    function openStudio(): void { root.openStudio() }
    function closeStudio(): void { root.closeStudio() }
    function status(): string { return JSON.stringify({ playing: root.isPlaying, preset: root.currentPreset, volume: root.currentVolume }) }
  }

  Process {
    id: statusProc
    command: [root.ctlScriptPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.isPlaying = !!data.playing
          if (data.preset) root.currentPreset = String(data.preset)
          if (data.volume !== undefined) root.currentVolume = parseInt(data.volume)
          if (data.timer !== undefined) root.sleepTimerMin = parseInt(data.timer)
          if (data.timer_remaining !== undefined) root.timerRemainingSec = parseInt(data.timer_remaining)
        } catch (e) {
        }
      }
    }
  }

  Process {
    id: presetsProc
    command: [root.ctlScriptPath, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(text || "[]")
          if (list && list.length > 0) {
            root.presetList = list.map(function(item) {
              return {
                id: item.id,
                name: item.name || item.id,
                icon: item.icon || "\udb81\udf5a",
                desc: item.type === "file" ? "Custom Audio Loop" : (root.presetNames[item.id] || "Procedural soundscape")
              }
            })
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: cmdProc
    onExited: function(exitCode) {
      statusProcTimer.restart()
    }
  }

  Timer {
    id: statusProcTimer
    interval: 80
    onTriggered: root.refresh()
  }

  // Periodic poll to keep UI in sync (every 1s when playing with active timer, 3s otherwise)
  Timer {
    interval: root.isPlaying && root.timerRemainingSec > 0 ? 1000 : 3000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  visible: isWidgetVisible
  implicitWidth: !isWidgetVisible ? 0 : (root.vertical ? button.implicitWidth : button.implicitWidth)
  implicitHeight: !isWidgetVisible ? 0 : (root.vertical ? button.implicitHeight : root.barSize)

  // Top Bar Button (Only visible on the bar when audio is actively playing)
  WidgetButton {
    id: button
    visible: root.isWidgetVisible
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || !root.showLabelSetting
      ? root.activeIcon
      : (root.activeIcon + " " + root.activeName + (root.isPlaying ? " (" + root.currentVolume + "%)" : "") + (root.timerRemainingSec > 0 ? " [" + Math.ceil(root.timerRemainingSec / 60) + "m]" : ""))
    active: root.isPlaying
    dimmed: !root.isPlaying
    useActiveColor: true
    activeColor: bar ? bar.urgent : Color.urgent
    fontSize: Style.font.body
    horizontalMargin: 6
    verticalPadding: 2
    tooltipText: "Ambience: " + root.activeName + " (" + root.currentVolume + "%)\n"
      + "Status: " + (root.isPlaying ? "Playing" : "Stopped")
      + (root.timerRemainingSec > 0 ? " | Timer: " + root.formatTimer(root.timerRemainingSec) : "")
      + "\n(Left-click: Play/Pause | Wheel: Volume | Middle-click: Next sound | Right-click: Ambience)"
    onPressed: function(btn) {
      if (btn === Qt.RightButton) root.toggleStudio()
      else if (btn === Qt.MiddleButton) root.cyclePreset()
      else root.togglePlay()
    }
    onWheelMoved: function(delta) {
      if (delta > 0) root.adjustVolume(5)
      else if (delta < 0) root.adjustVolume(-5)
    }
  }

  // Centered Studio Window with Exclusive Keyboard Focus (Modal like Omasaver)
  PanelWindow {
    id: studioWindow
    visible: open
    property bool open: false

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-ambience-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
      if (open) {
        root.reloadPresets()
        root.refresh()
        Qt.callLater(function() {
          keyCatcher.forceActiveFocus()
        })
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: function(event) {
        studioWindow.open = false
        if (event) event.accepted = true
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          studioWindow.open = false
          event.accepted = true
        }
      }

      // Scrim (darkened backdrop)
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)

        MouseArea {
          anchors.fill: parent
          onClicked: studioWindow.open = false
        }
      }

      // Centered Large Studio Card
      BorderSurface {
        id: studioCard
        anchors.centerIn: parent
        width: Style.space(760)
        implicitHeight: cardContent.implicitHeight + Style.space(36)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius + 2 : 8
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

        // Prevent clicks inside card from closing modal
        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

      Column {
        id: cardContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(20)
        spacing: Style.spacing.md

        // Header Row
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: root.activeIcon
            color: root.isPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(60)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "Ambience"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              text: root.isPlaying
                ? ("Now playing: " + root.activeName + " (" + root.currentVolume + "%)" + (root.timerRemainingSec > 0 ? " — Stopping in " + root.formatTimer(root.timerRemainingSec) : ""))
                : "Relaxing ambient soundscapes, noise generator, and offline focus"
              color: root.isPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Qt.darker(Color.foreground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Button {
            iconText: "\udb80\udd56"
            tooltipText: "Close (Esc)"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: studioWindow.open = false
          }
        }

        PanelSeparator { foreground: Color.foreground }

        // Section 1: Soundscapes Grid (4 columns x 2 rows)
        PanelSectionHeader {
          text: "SOUNDSCAPES (" + root.presetList.length + " AVAILABLE)"
          foreground: Color.foreground
        }

        Grid {
          width: parent.width
          columns: 4
          spacing: Style.spacing.xs

          Repeater {
            model: root.presetList

            delegate: BorderSurface {
              required property var modelData
              required property int index

              width: (parent.width - Style.spacing.xs * 3) / 4
              implicitHeight: Style.space(56)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6

              readonly property bool isSelected: root.currentPreset === modelData.id
              readonly property bool isCurrentPlaying: isSelected && root.isPlaying

              color: isCurrentPlaying
                ? (root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.25) : Qt.rgba(1, 0.35, 0.35, 0.25))
                : (isSelected ? Style.selectedFillFor(Color.foreground, Color.accent) : Style.controlFill(false, mouseItem.containsMouse, Color.foreground, Color.accent))
              borderSpec: Border.controlSpec(isCurrentPlaying ? "selected" : (isSelected ? "selected" : (mouseItem.containsMouse ? "hover-cursor" : "normal")), Color.foreground, Color.accent)

              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.sm
                anchors.rightMargin: Style.spacing.xs
                spacing: Style.spacing.xs

                Text {
                  text: modelData.icon
                  color: isCurrentPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : (isSelected ? Color.accent : Color.foreground)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(22)
                  horizontalAlignment: Text.AlignHCenter
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(26)
                  spacing: 1

                  Text {
                    width: parent.width
                    text: modelData.name
                    color: isCurrentPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall || Style.font.caption
                    font.bold: isSelected
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }

                  Text {
                    width: parent.width
                    text: modelData.desc
                    color: Qt.darker(Color.foreground, 1.5)
                    font.family: Style.font.family
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }
              }

              MouseArea {
                id: mouseItem
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setPreset(modelData.id)
                  if (!root.isPlaying) root.togglePlay()
                }
              }
            }
          }
        }

        PanelSeparator { foreground: Color.foreground }

        // Section 2: Volume & Sleep Timer (2 Columns Grid)
        Row {
          width: parent.width
          spacing: Style.spacing.lg

          // Left Side: Volume Controls
          Column {
            width: (parent.width - Style.spacing.lg) / 2
            spacing: Style.spacing.xs

            PanelSectionHeader {
              text: "VOLUME (" + root.currentVolume + "%)"
              foreground: Color.foreground
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              Text {
                text: root.currentVolume === 0 ? "\udb81\udf5f" : (root.currentVolume < 50 ? "\udb81\udf5e" : "\udb81\udf5c")
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              PanelSlider {
                id: volumeSlider
                bar: root.bar
                minimum: 0
                maximum: 100
                step: 5
                value: root.currentVolume
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(35)
                onMoved: function(val) { root.setVolume(Math.round(val)) }
                onReleased: function(val) { root.setVolume(Math.round(val)) }
              }
            }

            // Quick Volume Presets
            Row {
              width: parent.width
              spacing: Style.spacing.xs

              Repeater {
                model: [
                  { label: "Mute", val: 0 },
                  { label: "30%", val: 30 },
                  { label: "60%", val: 60 },
                  { label: "80%", val: 80 },
                  { label: "100%", val: 100 }
                ]

                delegate: BorderSurface {
                  required property var modelData
                  width: (parent.width - Style.spacing.xs * 4) / 5
                  implicitHeight: Style.space(26)
                  radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4

                  readonly property bool isCur: root.currentVolume === modelData.val
                  color: isCur ? Style.selectedFillFor(Color.foreground, Color.accent) : Style.controlFill(false, volMouse.containsMouse, Color.foreground, Color.accent)
                  borderSpec: Border.controlSpec(isCur ? "selected" : (volMouse.containsMouse ? "hover-cursor" : "normal"), Color.foreground, Color.accent)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: isCur ? Color.accent : Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.tiny || 9
                    font.bold: isCur
                  }

                  MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setVolume(modelData.val)
                  }
                }
              }
            }
          }

          // Right Side: Sleep Timer
          Column {
            width: (parent.width - Style.spacing.lg) / 2
            spacing: Style.spacing.xs

            PanelSectionHeader {
              text: "SLEEP TIMER" + (root.timerRemainingSec > 0 ? (" (REMAINING: " + root.formatTimer(root.timerRemainingSec) + ")") : "")
              foreground: Color.foreground
            }

            ButtonGroup {
              width: parent.width
              options: [
                { value: "0", label: "Off" },
                { value: "15", label: "15m" },
                { value: "30", label: "30m" },
                { value: "45", label: "45m" },
                { value: "60", label: "60m" },
                { value: "90", label: "90m" }
              ]
              value: String(root.sleepTimerMin)
              onChanged: function(val) { root.setTimer(parseInt(val) || 0) }
            }
          }
        }

        PanelSeparator { foreground: Color.foreground }

        // Section 3: Action Controls Bar (4 Action Buttons)
        Grid {
          width: parent.width
          columns: 4
          spacing: Style.spacing.xs

          // Button 1: Main Play / Pause
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: root.isPlaying
              ? (root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.25) : Qt.rgba(1, 0.35, 0.35, 0.25))
              : Style.controlFill(false, btn1Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(root.isPlaying ? "selected" : (btn1Mouse.containsMouse ? "hover-cursor" : "normal"), Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: root.isPlaying ? "󰏤" : "󰐊"
                color: root.isPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: root.isPlaying ? "Pause" : "Play"
                color: Color.foreground
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
            MouseArea {
              id: btn1Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlay()
            }
          }

          // Button 2: Next Sound
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn2Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn2Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 6
              Text { text: "󰒭"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Next sound"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn2Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cyclePreset()
            }
          }

          // Button 3: Open Sounds Folder
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn3Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn3Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 6
              Text { text: "\udb80\ude4b"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Sounds folder"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn3Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openSoundsFolder()
            }
          }

          // Button 4: Freesound Link
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn4Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn4Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 6
              Text { text: "\udb80\udf35"; color: Color.accent; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Freesound (CC0)"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn4Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openUrl("https://freesound.org/search/?q=ambient+loop&f=license%3A%22Creative+Commons+0%22")
            }
          }
        }
      }
    }
  }
}
}
