import QtQuick
import QtTest
import "../ConfigPolicy.js" as ConfigPolicy

TestCase {
  name: "ConfigPolicy"

  function test_documentedDefaults() {
    var result = ConfigPolicy.parseConfig("{}")
    verify(result.ok)
    compare(result.config.apps.slack.url, "https://app.slack.com/client")
    compare(result.config.apps.discord.url, "https://discord.com/channels/@me")
    compare(result.config.apps.telegram.url, "https://web.telegram.org/a/")
    compare(result.config.apps.whatsapp.url, "https://web.whatsapp.com/")
    compare(result.config.apps.slack.enabled, false)
  }

  function test_supportedCustomUrls_data() {
    var prefix = "https://example.com/"
    return [
      { tag: "localhost", url: "http://localhost:3000/chat" },
      { tag: "private IPv4", url: "https://192.168.1.20:8443/" },
      { tag: "IPv6", url: "https://[::1]:8443/chat" },
      { tag: "internal host", url: "https://chat.internal.example/base?team=one#inbox" },
      { tag: "IDN", url: "https://münich.example/chat" },
      { tag: "uppercase scheme", url: "HTTPS://example.com/chat" },
      { tag: "at sign outside authority", url: "https://example.com/user@example.com" },
      { tag: "maximum length", url: prefix
          + "a".repeat(ConfigPolicy.maxUrlLength - prefix.length) }
    ]
  }

  function test_supportedCustomUrls(data) {
    compare(ConfigPolicy.urlError(data.url), "")
    var input = { apps: { slack: { enabled: true, url: data.url } } }
    var result = ConfigPolicy.parseConfig(JSON.stringify(input))
    verify(result.ok)
    compare(result.config.apps.slack.url, data.url)
  }

  function test_rejectedUrls_data() {
    var tooLong = "https://example.com/" + "a".repeat(ConfigPolicy.maxUrlLength)
    return [
      { tag: "empty", url: "" },
      { tag: "relative", url: "/chat" },
      { tag: "scheme relative", url: "//example.com/chat" },
      { tag: "missing slashes", url: "https:example.com/chat" },
      { tag: "unsupported scheme", url: "file:///tmp/chat" },
      { tag: "javascript scheme", url: "javascript:alert(1)" },
      { tag: "missing host", url: "https:///chat" },
      { tag: "bad port", url: "https://example.com:99999/chat" },
      { tag: "username", url: "https://user@example.com/chat" },
      { tag: "password", url: "https://user:secret@example.com/chat" },
      { tag: "empty userinfo", url: "https://@example.com/chat" },
      { tag: "control", url: "https://example.com/\u0000chat" },
      { tag: "newline", url: "https://example.com/\nchat" },
      { tag: "delete control", url: "https://example.com/\u007fchat" },
      { tag: "space", url: "https://example.com/has space" },
      { tag: "backslash", url: "https://example.com\\@evil.example/chat" },
      { tag: "too long", url: tooLong }
    ]
  }

  function test_rejectedUrls(data) {
    verify(ConfigPolicy.urlError(data.url) !== "")
    var input = { apps: { slack: { enabled: true, url: data.url } } }
    verify(!ConfigPolicy.parseConfig(JSON.stringify(input)).ok)
  }

  function test_rejectedConfigShapes_data() {
    return [
      { tag: "parse failure", text: "{" },
      { tag: "null root", text: "null" },
      { tag: "array root", text: "[]" },
      { tag: "boolean root", text: "true" },
      { tag: "array apps", text: "{\"apps\":[]}" },
      { tag: "null app", text: "{\"apps\":{\"slack\":null}}" },
      { tag: "array app", text: "{\"apps\":{\"slack\":[]}}" },
      { tag: "string enabled", text: "{\"apps\":{\"slack\":{\"enabled\":\"true\"}}}" },
      { tag: "null URL", text: "{\"apps\":{\"slack\":{\"url\":null}}}" }
    ]
  }

  function test_rejectedConfigShapes(data) {
    var lastGood = ConfigPolicy.parseConfig(
      "{\"apps\":{\"slack\":{\"enabled\":true}}}")
    verify(lastGood.ok)
    var before = JSON.stringify(lastGood.config)
    var rejected = ConfigPolicy.parseConfig(data.text)
    verify(!rejected.ok)
    compare(JSON.stringify(lastGood.config), before)
    verify(rejected.config === undefined)
  }
}
