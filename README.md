# Messaging for Omarchy

An [Omarchy](https://omarchy.org/) shell plugin that keeps web messaging one click away — Slack, Discord, Telegram and WhatsApp Web, each in its own dedicated app window. No Electron apps, no second IM client, no tab hunting.

A speech-bubble icon sits in the bar (default: right side):

- **Left-click** — panel: toggle each app on/off and launch the enabled ones.
- **Badge** — shows how many apps are currently enabled.
- **Hover** — tooltip with "2 of 4 apps on".

<img width="428" height="659" alt="image" src="https://github.com/user-attachments/assets/e6f2ef42-d412-4b02-9acb-809e732c84ad" />

## Features

- Four web clients built in: **Slack**, **Discord**, **Telegram**, **WhatsApp** — each off until you enable it.
- **Dedicated app window per app**: launches Chromium in `--app` mode (chromeless standalone window) with an isolated profile per app under `~/.local/share/omarchy/messaging/<app>-profile`. Sign in once; sessions persist across opens and stay quarantined from your daily browser.
- Falls back to `xdg-open` when no Chromium-family browser is found.
- **Zero credential handling**: the plugin stores only enable flags and URLs.

## Install

```sh
omarchy plugin add https://github.com/Somnius/Messaging-for-Omarchy.git --enable
```

Then place the widget in the bar:

```sh
omarchy bar plugin add lef.messaging --section right
```

### From a local checkout (development)

If you already have a copy of this repository on disk, link it into the plugins folder:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/lef.messaging
omarchy-shell shell rescanPlugins
```

> **Dev loop caveat:** Quickshell's file watcher does not follow symlinks; after edits run `omarchy restart shell`.

Validate at any time with:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/lef.messaging
```

## Configuration

`~/.config/omarchy/messaging/config.json` — hot-reloads:

```json
{
  "apps": {
    "slack":    { "enabled": true,  "url": "https://app.slack.com/client" },
    "discord":  { "enabled": false, "url": "https://discord.com/channels/@me" },
    "telegram": { "enabled": true,  "url": "https://web.telegram.org/a/" },
    "whatsapp": { "enabled": false, "url": "https://web.whatsapp.com/" }
  }
}
```

Self-hosting alternatives or gateways? Point `url` anywhere; the Open button follows it.

## IPC & keybindings

```sh
omarchy-shell lef.messaging status              # JSON state of every app
omarchy-shell lef.messaging enable slack true   # same path as the panel toggle
omarchy-shell lef.messaging launch telegram     # open its app window
omarchy-shell lef.messaging toggle              # open/close the panel
```

Hyprland binding example (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER + ALT + M", "Messaging panel", "omarchy-shell lef.messaging toggle")
```

## External dependencies

- A Chromium-family browser for app windows: `chromium` or `brave` (auto-detected), otherwise any browser via `xdg-open`.

## Uninstall

```sh
omarchy plugin remove lef.messaging
```

(If installed via symlink, remove the symlink instead. App profiles remain under `~/.local/share/omarchy/messaging/`; delete that folder to wipe all chat sessions.)

## Privacy

The plugin never sees a password, token, cookie or message. It writes one config file containing booleans and URLs you typed. Chat sessions live only in the per-app browser profiles.

## License

[MIT](LICENSE)
