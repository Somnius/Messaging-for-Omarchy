import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigPolicy.js" as ConfigPolicy

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/messaging"
  readonly property string configPath: configDir + "/config.json"
  readonly property string boundedReadScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("BoundedRead.pl")).replace(/^file:\/\//, ""))
  readonly property string atomicWriteScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("AtomicWrite.pl")).replace(/^file:\/\//, ""))
  readonly property int configMaxBytes: 65536
  readonly property string repoUrl: "https://github.com/Somnius/Messaging-for-Omarchy"

  // ponytail: no unread counts — that needs per-app APIs or an embedded
  // webview session; add when the simple launcher proves itself.
  readonly property var defaults: ConfigPolicy.defaults()

  property var apps: ConfigPolicy.defaults()
  property bool loaded: false
  property string lastError: ""
  property string detectedBrowser: ""
  property bool configReadPending: false
  property string pendingConfigWrite: ""
  readonly property bool writingConfig: configWriteProc.running
    || pendingConfigWrite !== ""

  // One isolated chromium profile per app: persistent login per web client,
  // cookies kept out of the daily browser.
  function profileDir(name) {
    return home + "/.local/share/omarchy/messaging/" + name + "-profile"
  }

  function appNames() {
    return ConfigPolicy.appNames()
  }

  function isEnabled(name) {
    return !!(root.apps[name] && root.apps[name].enabled)
  }

  function urlFor(name) {
    return (root.apps[name] && root.apps[name].url) || ""
  }

  function enabledCount() {
    var n = 0
    root.appNames().forEach(function (k) { if (root.isEnabled(k)) n++ })
    return n
  }

  function statusText() {
    return root.enabledCount() + " of " + root.appNames().length + " apps on"
  }

  function currentConfig() {
    return { apps: root.apps }
  }

  function saveConfig(patch) {
    var config = root.currentConfig()
    for (var key in patch) config[key] = patch[key]
    var issue = ConfigPolicy.configError(config)
    if (issue !== "") {
      root.lastError = "Invalid config.json: " + issue
      return false
    }
    config = ConfigPolicy.normalize(config)
    root.queueConfigWrite(JSON.stringify(config, null, 2) + "\n")
    root.apps = config.apps
    root.loaded = true
    root.clearConfigReadError()
    return true
  }

  function applyConfig(text) {
    var result = ConfigPolicy.parseConfig(text)
    if (!result.ok) {
      root.lastError = result.error
      return false
    }
    root.apps = result.config.apps
    root.loaded = true
    return true
  }

  function clearConfigReadError() {
    if (root.lastError.indexOf("Invalid config.json:") === 0
        || root.lastError.indexOf("Could not read config.json:") === 0)
      root.lastError = ""
  }

  function requestConfigRead() {
    if (configWriteProc.running || root.pendingConfigWrite !== "") {
      root.configReadPending = true
      return
    }
    if (configReadProc.running) {
      root.configReadPending = true
      return
    }
    root.configReadPending = false
    configReadProc.running = true
  }

  function queueConfigWrite(payload) {
    root.pendingConfigWrite = payload
    if (configReadProc.running) root.configReadPending = true
    configFile.path = ""
    if (!configWriteProc.running) Qt.callLater(root.startPendingConfigWrite)
  }

  function startPendingConfigWrite() {
    if (configWriteProc.running || root.pendingConfigWrite === "") return
    var payload = root.pendingConfigWrite
    root.pendingConfigWrite = ""
    configWriteProc.command = ["/usr/bin/perl", root.atomicWriteScriptPath,
      root.configPath, String(root.configMaxBytes), payload]
    configWriteProc.running = true
  }

  function onConfigWriteExited(exitCode) {
    if (exitCode !== 0) {
      root.lastError = "Could not write config.json: "
        + root.processFailure(configWriteError.text, "atomic write failed")
    } else if (root.lastError.indexOf("Could not write config.json:") === 0) {
      root.lastError = ""
    }

    if (root.pendingConfigWrite !== "") {
      Qt.callLater(root.startPendingConfigWrite)
      return
    }

    Qt.callLater(function () {
      if (configWriteProc.running || root.pendingConfigWrite !== "") return
      configFile.path = ""
      configFile.path = root.configPath
      root.requestConfigRead()
    })
  }

  function processFailure(stderrText, fallback) {
    var detail = String(stderrText || "").trim()
    return detail || fallback
  }

  function onConfigReadExited(exitCode) {
    var stale = root.configReadPending
    root.configReadPending = false
    if (stale) {
      Qt.callLater(root.requestConfigRead)
      return
    }

    var hadConfig = root.loaded
    if (exitCode === 0) {
      if (root.applyConfig(configReadOutput.text)) {
        root.clearConfigReadError()
      } else if (!root.loaded) {
        var parseError = root.lastError
        root.applyConfig("{}")
        root.lastError = parseError
      }
    } else {
      if (!root.loaded) root.applyConfig("{}")
      if (exitCode !== 2 || hadConfig) {
        root.lastError = "Could not read config.json: "
          + root.processFailure(configReadError.text, "bounded read failed")
      }
    }
  }

  function setEnabled(name, value) {
    if (!root.defaults[name]) return false
    var next = JSON.parse(JSON.stringify(root.apps))
    if (!next[name]) next[name] = {}
    next[name].enabled = value === true
    return saveConfig({ apps: next })
  }

  function openApp(name) {
    if (!root.defaults[name]) return false
    var url = root.urlFor(name)
    var issue = ConfigPolicy.urlError(url)
    if (issue !== "") {
      root.lastError = "Invalid URL for " + name + ": " + issue
      return false
    }
    var b = root.detectedBrowser
    var command = b !== ""
      ? [b, "--app=" + url, "--user-data-dir=" + root.profileDir(name)]
      : ["xdg-open", url]
    // Browser app windows are long-lived. Detached launches keep each request
    // independent instead of serializing every app behind one tracked Process.
    Quickshell.execDetached(command)
    return true
  }

  FileView {
    id: configFile
    // Watch-only: content reaches QML solely through the bounded producer.
    path: ""
    preload: false
    blockAllReads: true
    watchChanges: true
    printErrors: false
    onFileChanged: root.requestConfigRead()
  }

  Process {
    id: detectProc
    command: ["bash", "-c", "command -v chromium || command -v brave || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.detectedBrowser = String(text || "").trim()
    }
  }

  Process {
    id: configDirProc
    command: ["mkdir", "-p", root.configDir]
    onExited: {
      configFile.path = ""
      configFile.path = root.configPath
      root.requestConfigRead()
    }
  }

  Process {
    id: configReadProc
    command: ["/usr/bin/perl", root.boundedReadScriptPath,
      root.configPath, String(root.configMaxBytes)]
    stdout: StdioCollector {
      id: configReadOutput
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: configReadError
      waitForEnd: true
    }
    onExited: function(exitCode) { root.onConfigReadExited(exitCode) }
  }

  Process {
    id: configWriteProc
    stderr: StdioCollector {
      id: configWriteError
      waitForEnd: true
    }
    onExited: function(exitCode) { root.onConfigWriteExited(exitCode) }
  }

  Component.onCompleted: {
    configDirProc.running = true
    if (!detectProc.running) detectProc.running = true
  }
}
