import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dorneles.ambience"

  // Settings
  readonly property string defaultPreset: setting("defaultPreset", "rain")
  readonly property int defaultVolume: setting("defaultVolume", 60)
  readonly property bool showLabelSetting: setting("showLabel", true)

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
    { id: "rain", name: "Rain", icon: "\udb81\udd97", desc: "Gentle rain shower" },
    { id: "waves", name: "Waves", icon: "\udb82\udd3d", desc: "Ocean surf & tides" },
    { id: "campfire", name: "Campfire", icon: "\udb80\ude38", desc: "Cozy wood crackle" },
    { id: "brown", name: "Brown Noise", icon: "\udb81\udf5a", desc: "Deep rumble for focus" },
    { id: "pink", name: "Pink Noise", icon: "\udb81\udf5a", desc: "Balanced soothing noise" },
    { id: "white", name: "White Noise", icon: "\udb81\udf5a", desc: "Crisp frequency mask" },
    { id: "binaural", name: "Binaural", icon: "\udb80\udecb", desc: "10Hz Alpha brainwaves" },
    { id: "cafe", name: "Café", icon: "\udb80\udd56", desc: "Warm coffee shop" }
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

  function toggleStudioPopup() {
    studioPopup.open = !studioPopup.open
    if (studioPopup.open) {
      root.reloadPresets()
    }
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
    function openStudio(): void { root.toggleStudioPopup() }
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

  implicitWidth: root.vertical ? button.implicitWidth : button.implicitWidth
  implicitHeight: root.vertical ? button.implicitHeight : root.barSize

  WidgetButton {
    id: button
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
      + "\n(Left-click: Play/Pause | Wheel: Volume | Middle-click: Next sound | Right-click: Studio)"
    onPressed: function(btn) {
      if (btn === Qt.RightButton) root.toggleStudioPopup()
      else if (btn === Qt.MiddleButton) root.cyclePreset()
      else root.togglePlay()
    }
    onWheelMoved: function(delta) {
      if (delta > 0) root.adjustVolume(5)
      else if (delta < 0) root.adjustVolume(-5)
    }
  }

  // Ambience Studio Popup Card
  PopupCard {
    id: studioPopup
    anchorItem: root
    bar: root.bar
    contentWidth: Style.space(350)
    contentHeight: fittedContentHeight(studioContent.implicitHeight)
    open: false
    triggerMode: "click"

    Column {
      id: studioContent
      width: parent.width
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
          width: parent.width - Style.space(80)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: "Ambience Studio"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: root.isPlaying
              ? ("Playing: " + root.activeName + (root.timerRemainingSec > 0 ? " (" + root.formatTimer(root.timerRemainingSec) + " left)" : ""))
              : "Offline Soundscapes & Noise"
            color: root.isPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Qt.darker(Color.foreground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Button {
          iconText: "\udb80\udd56"
          tooltipText: "Close"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: studioPopup.close()
        }
      }

      PanelSeparator { foreground: Color.foreground }

      // Section 1: Soundscapes Grid
      PanelSectionHeader {
        text: "SOUNDSCAPES"
        foreground: Color.foreground
      }

      Grid {
        width: parent.width
        columns: 2
        spacing: Style.spacing.sm

        Repeater {
          model: root.presetList

          delegate: BorderSurface {
            required property var modelData
            required property int index

            width: (parent.width - Style.spacing.sm) / 2
            implicitHeight: Style.space(48)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6

            readonly property bool isSelected: root.currentPreset === modelData.id
            readonly property bool isCurrentPlaying: isSelected && root.isPlaying

            color: isCurrentPlaying
              ? (root.bar ? Qt.rgba(root.bar.urgent.r, root.bar.urgent.g, root.bar.urgent.b, 0.22) : Qt.rgba(1, 0.35, 0.35, 0.22))
              : (isSelected ? Style.selectedFillFor(Color.foreground, Color.accent) : Style.controlFill(false, mouseItem.containsMouse, Color.foreground, Color.accent))
            borderSpec: Border.controlSpec(isCurrentPlaying ? "selected" : (isSelected ? "selected" : (mouseItem.containsMouse ? "hover-cursor" : "normal")), Color.foreground, Color.accent)

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.sm
              anchors.rightMargin: Style.spacing.sm
              spacing: Style.spacing.sm

              Text {
                text: modelData.icon
                color: isCurrentPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(34)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  text: modelData.name
                  color: isCurrentPlaying ? (root.bar ? root.bar.urgent : Color.urgent) : Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: isSelected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: modelData.desc
                  color: Qt.darker(Color.foreground, 1.5)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.tiny || 9
                  elide: Text.ElideRight
                  width: parent.width
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

      // Section 2: Volume Control
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

        Text {
          text: "Volume (" + root.currentVolume + "%)"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(90)
        }

        PanelSlider {
          id: volumeSlider
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 5
          value: root.currentVolume
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(125)
          onMoved: function(val) { root.setVolume(Math.round(val)) }
          onReleased: function(val) { root.setVolume(Math.round(val)) }
        }
      }

      PanelSeparator { foreground: Color.foreground }

      // Section 3: Sleep Timer
      PanelSectionHeader {
        text: "SLEEP TIMER" + (root.timerRemainingSec > 0 ? (" (ACTIVE: " + root.formatTimer(root.timerRemainingSec) + ")") : "")
        foreground: Color.foreground
      }

      ButtonGroup {
        width: parent.width
        options: [
          { value: "0", label: "Off" },
          { value: "15", label: "15m" },
          { value: "30", label: "30m" },
          { value: "45", label: "45m" },
          { value: "60", label: "60m" }
        ]
        value: String(root.sleepTimerMin)
        onChanged: function(val) { root.setTimer(parseInt(val) || 0) }
      }

      PanelSeparator { foreground: Color.foreground }

      // Section 4: Main Play / Pause Action Button
      Button {
        width: parent.width
        bordered: true
        active: root.isPlaying
        text: root.isPlaying ? ("Pause " + root.activeName) : ("Play " + root.activeName)
        iconText: root.isPlaying ? "\udb80\udfe4" : "\udb80\udfe3"
        onClicked: root.togglePlay()
      }

      PanelSeparator { foreground: Color.foreground }

      // Section 5: Add Custom Sounds & Open Source Instructions
      PanelSectionHeader {
        text: "ADD CUSTOM SOUNDS (OPEN SOURCE)"
        foreground: Color.foreground
      }

      BorderSurface {
        width: parent.width
        implicitHeight: customGuideCol.implicitHeight + Style.spacing.md * 2
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Style.controlFill(false, false, Color.foreground, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

        Column {
          id: customGuideCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.spacing.md
          spacing: Style.spacing.sm

          Text {
            width: parent.width
            text: "Drop any .ogg, .mp3, .wav, or .flac loop files into your sounds folder. They will automatically appear in this menu!"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            text: "Folder: ~/.config/omarchy/plugins/dorneles.ambience/sounds/"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.tiny || 9
            font.italic: true
            elide: Text.ElideMiddle
          }

          Text {
            width: parent.width
            text: "Free & Open Source sound repositories (CC0 / Public Domain):"
            color: Qt.darker(Color.foreground, 1.3)
            font.family: Style.font.family
            font.pixelSize: Style.font.tiny || 9
            font.bold: true
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            Button {
              width: (parent.width - Style.spacing.sm) / 2
              text: "Open Folder"
              iconText: "\udb80\ude4b"
              tooltipText: "Open sounds directory in file manager"
              onClicked: root.openSoundsFolder()
            }

            Button {
              width: (parent.width - Style.spacing.sm) / 2
              text: "Freesound.org"
              iconText: "\udb80\udf35"
              tooltipText: "Search free CC0 ambient sounds on Freesound"
              onClicked: root.openUrl("https://freesound.org/search/?q=ambient+loop&f=license%3A%22Creative+Commons+0%22")
            }
          }
        }
      }
    }
  }
}
