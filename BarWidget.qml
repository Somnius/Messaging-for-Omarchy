import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "lef.messaging"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool ready: service !== null && service.loaded
  readonly property int count: ready ? service.enabledCount() : 0

  implicitWidth: glyph.implicitWidth + Style.space(12)
  implicitHeight: barSize

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = root
    target.hostWidget = root
    target.service = root.service
  }

  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

  Item {
    id: glyphArea
    anchors.centerIn: parent
    width: glyph.implicitWidth + (badge.visible ? badge.implicitWidth : 0)
    height: glyph.implicitHeight

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: "💬"
      textFormat: Text.PlainText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      opacity: root.ready && root.count > 0 ? 1 : 0.45
    }

    Text {
      id: badge
      anchors.left: glyph.right
      anchors.leftMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      visible: root.ready && root.count > 0
      text: String(root.count)
      textFormat: Text.PlainText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  // Keep implicitWidth honest now that the glyph is wrapped.
  onCountChanged: root.implicitWidth = Qt.binding(function () {
    return glyphArea.width + Style.space(12)
  })

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function () {
      if (!root.ready) return
      root.toggle()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root,
      root.ready ? service.statusText() : "Messaging")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function enable(app: string, on: bool): string {
      if (!root.ready) return "service not ready"
      if (!root.service.defaults[app]) return "unknown app: " + app
      if (!root.service.setEnabled(app, on))
        return root.service.lastError || "could not update " + app
      return "queued " + app + " -> " + (on ? "on" : "off")
    }
    function launch(app: string): string {
      if (!root.ready) return "service not ready"
      if (!root.service.isEnabled(app)) return app + " is disabled"
      if (!root.service.openApp(app))
        return root.service.lastError || "could not open " + app
      return "launch requested for " + app
    }
    function status(): string {
      return root.ready ? JSON.stringify({ apps: root.service.apps }) : "service not ready"
    }
  }
}
