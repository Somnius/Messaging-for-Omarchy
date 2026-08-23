import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "lef.messaging"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function label(name) {
    return name.charAt(0).toUpperCase() + name.substring(1)
  }

  function open() {
    controller.show()
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Style.space(12)

        PanelHero {
          Layout.fillWidth: true
          title: "Messaging"
          meta: root.service ? root.service.statusText() : "Service unavailable"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "💬"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "WEB APPS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Repeater {
          model: root.service ? root.service.appNames() : []

          delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            spacing: Style.space(8)

            Toggle {
              Layout.fillWidth: true
              label: root.label(modelData)
              description: "Opens in its own chromium window; stays signed in."
              checked: root.service ? root.service.isEnabled(modelData) : false
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              enabled: root.service !== null
              onClicked: if (root.service)
                root.service.setEnabled(modelData, !root.service.isEnabled(modelData))
            }

            Button {
              text: "Open"
              iconText: "󰖟"
              bordered: true
              focusable: true
              enabled: root.service && root.service.isEnabled(modelData)
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              onClicked: if (root.service) root.service.openApp(modelData)
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        Text {
          Layout.fillWidth: true
          text: "Sessions live in your browser — this plugin stores no accounts, cookies or credentials. Custom URLs can be set per app in ~/.config/omarchy/messaging/config.json."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        Button {
          Layout.fillWidth: true
          text: "Source code · MIT license"
          bordered: true
          focusable: true
          enabled: root.service !== null
          foreground: root.foreground
          accent: Color.accent
          fontFamily: root.fontFamily
          onClicked: if (root.service) Qt.openUrlExternally(root.service.repoUrl)
        }
      }
    }
  }
}
