import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/messaging"
  readonly property string configPath: configDir + "/config.json"
  readonly property string repoUrl: "https://github.com/Somnius/Omarchy-Messaging"

  // Baked web-client URLs; a custom url in config.json wins.
  // ponytail: no unread counts — that needs per-app APIs or an embedded
  // webview session; add when the simple launcher proves itself.
  readonly property var defaults: ({
    slack:    { enabled: false, url: "https://app.slack.com/client" },
    discord:  { enabled: false, url: "https://discord.com/channels/@me" },
    telegram: { enabled: false, url: "https://web.telegram.org/a/" },
    whatsapp: { enabled: false, url: "https://web.whatsapp.com/" }
  })

  property var apps: ({})
  property bool loaded: false
  property string lastError: ""
  property string detectedBrowser: ""

  // One isolated chromium profile per app: persistent login per web client,
  // cookies kept out of the daily browser.
  function profileDir(name) {
    return home + "/.local/share/omarchy/messaging/" + name + "-profile"
  }

  function appNames() {
    return ["slack", "discord", "telegram", "whatsapp"]
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

  function normalize(c) {
    c = c || {}
    var apps = {}
    root.appNames().forEach(function (k) {
      var src = (c.apps && c.apps[k]) || {}
      apps[k] = {
        enabled: src.enabled === true,
        url: typeof src.url === "string" && src.url !== "" ? src.url : root.defaults[k].url
      }
    })
    return { apps: apps }
  }

  function currentConfig() {
    return { apps: root.apps }
  }

  function saveConfig(patch) {
    var config = root.currentConfig()
    for (var key in patch) config[key] = patch[key]
    config = root.normalize(config)
    configFile.setText(JSON.stringify(config, null, 2) + "\n")
    root.applyConfig(JSON.stringify(config))
  }

  function applyConfig(text) {
    var parsed = {}
    try { parsed = text && text.trim() ? JSON.parse(text) : {} }
    catch (error) { root.lastError = "Invalid config.json: " + error }
    var config = root.normalize(parsed)
    root.apps = config.apps
    root.loaded = true
  }

  function setEnabled(name, value) {
    if (!root.defaults[name]) return
    var next = JSON.parse(JSON.stringify(root.apps))
    if (!next[name]) next[name] = {}
    next[name].enabled = value === true
    saveConfig({ apps: next })
  }

  function openApp(name) {
    var url = root.urlFor(name)
    if (!url) return
    var b = root.detectedBrowser
    if (b !== "") {
      openProc.command = [b, "--app=" + url, "--user-data-dir=" + root.profileDir(name)]
    } else {
      openProc.command = ["xdg-open", url]
    }
    openProc.running = true
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  Process {
    id: openProc
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
  }

  Component.onCompleted: {
    configDirProc.running = true
    if (!detectProc.running) detectProc.running = true
  }
}
