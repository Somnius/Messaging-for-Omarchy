import QtQuick
import Quickshell
import "." as Messaging

ShellRoot {
  id: testRoot

  property int loadAttempts: 0
  property int writeAttempts: 0

  function fail(code, message) {
    console.error("messaging service test failed:", message)
    Qt.exit(code)
  }

  Messaging.Service {
    id: service
  }

  Timer {
    id: startTimer
    interval: 20
    repeat: true
    running: true
    onTriggered: {
      if (!service.loaded) {
        testRoot.loadAttempts++
        if (testRoot.loadAttempts >= 100) testRoot.fail(20, "initial config did not settle")
        return
      }
      stop()

      var valid = JSON.stringify({
        apps: {
          slack: { enabled: true, url: "http://localhost:3000/chat" }
        }
      })
      if (!service.applyConfig(valid)) testRoot.fail(21, "valid config was rejected")
      var lastGood = JSON.stringify(service.apps)

      if (service.applyConfig("{")) testRoot.fail(22, "parse failure was accepted")
      if (JSON.stringify(service.apps) !== lastGood)
        testRoot.fail(23, "parse failure replaced last-good state")

      var unsafeType = JSON.stringify({ apps: { slack: [] } })
      if (service.applyConfig(unsafeType)) testRoot.fail(24, "unsafe app type was accepted")
      if (JSON.stringify(service.apps) !== lastGood)
        testRoot.fail(25, "unsafe app type replaced last-good state")

      var unsafeUrl = JSON.stringify({
        apps: { slack: { enabled: true, url: "javascript:alert(1)" } }
      })
      if (service.applyConfig(unsafeUrl)) testRoot.fail(26, "unsafe URL was accepted")
      if (JSON.stringify(service.apps) !== lastGood)
        testRoot.fail(27, "unsafe URL replaced last-good state")

      var poisoned = JSON.parse(lastGood)
      poisoned.slack.url = "javascript:alert(1)"
      service.apps = poisoned
      if (service.openApp("slack")) testRoot.fail(28, "unsafe URL reached launcher")

      service.apps = JSON.parse(lastGood)
      service.detectedBrowser = service.home + "/record-launch"
      if (!service.openApp("slack") || !service.openApp("discord"))
        testRoot.fail(32, "independent app launches were rejected")
      service.setEnabled("discord", true)
      if (!service.isEnabled("discord")) testRoot.fail(29, "toggle did not update state")
      service.setEnabled("whatsapp", true)
      if (!service.isEnabled("whatsapp")) testRoot.fail(30, "queued toggle did not update state")
      finishTimer.start()
    }
  }

  Timer {
    id: finishTimer
    interval: 20
    repeat: true
    onTriggered: {
      if (!service.writingConfig) {
        stop()
        Qt.exit(0)
        return
      }
      testRoot.writeAttempts++
      if (testRoot.writeAttempts >= 100) testRoot.fail(31, "config write did not settle")
    }
  }
}
