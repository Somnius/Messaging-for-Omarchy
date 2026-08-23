.pragma library

var maxUrlLength = 2048
var names = ["slack", "discord", "telegram", "whatsapp"]
var defaultUrls = {
  slack: "https://app.slack.com/client",
  discord: "https://discord.com/channels/@me",
  telegram: "https://web.telegram.org/a/",
  whatsapp: "https://web.whatsapp.com/"
}

function own(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key)
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function appNames() {
  return names.slice(0)
}

function defaults() {
  var apps = {}
  names.forEach(function (name) {
    apps[name] = { enabled: false, url: defaultUrls[name] }
  })
  return apps
}

function urlError(value) {
  if (typeof value !== "string") return "must be a string"
  if (value.length === 0) return "must not be empty"
  if (value.length > maxUrlLength) return "exceeds " + maxUrlLength + " characters"
  if (/[\u0000-\u001f\u007f-\u009f]/.test(value)) return "contains control characters"
  if (/\s/.test(value)) return "contains whitespace"
  if (value.indexOf("\\") >= 0) return "contains a backslash"
  if (!/^https?:\/\//i.test(value)) return "must use an absolute http or https URL"

  var schemeEnd = value.indexOf("://")
  var authorityEnd = value.length
  var separators = ["/", "?", "#"]
  separators.forEach(function (separator) {
    var index = value.indexOf(separator, schemeEnd + 3)
    if (index >= 0 && index < authorityEnd) authorityEnd = index
  })
  var authority = value.substring(schemeEnd + 3, authorityEnd)
  if (authority === "") return "must include a host"
  if (authority.indexOf("@") >= 0) return "must not include user information"

  var parsed
  try { parsed = new URL(value) }
  catch (error) { return "is malformed" }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:")
    return "must use http or https"
  if (parsed.username !== "" || parsed.password !== "")
    return "must not include user information"
  if (parsed.hostname === "") return "must include a host"
  return ""
}

function configError(config) {
  if (!isRecord(config)) return "expected a configuration object"
  if (!own(config, "apps")) return ""
  if (!isRecord(config.apps)) return "apps must be an object"

  for (var i = 0; i < names.length; i++) {
    var name = names[i]
    if (!own(config.apps, name)) continue
    var app = config.apps[name]
    if (!isRecord(app)) return "apps." + name + " must be an object"
    if (own(app, "enabled") && typeof app.enabled !== "boolean")
      return "apps." + name + ".enabled must be a boolean"
    if (own(app, "url")) {
      var issue = urlError(app.url)
      if (issue !== "") return "apps." + name + ".url " + issue
    }
  }
  return ""
}

function normalize(config) {
  var sourceApps = own(config, "apps") ? config.apps : {}
  var apps = {}
  names.forEach(function (name) {
    var source = own(sourceApps, name) ? sourceApps[name] : {}
    apps[name] = {
      enabled: own(source, "enabled") && source.enabled === true,
      url: own(source, "url") ? source.url : defaultUrls[name]
    }
  })
  return { apps: apps }
}

function parseConfig(text) {
  var parsed
  try { parsed = JSON.parse(String(text)) }
  catch (error) {
    return { ok: false, error: "Invalid config.json: " + error }
  }
  var issue = configError(parsed)
  if (issue !== "") return { ok: false, error: "Invalid config.json: " + issue }
  return { ok: true, config: normalize(parsed), error: "" }
}
