# Codex App Linux (Unofficial)

<p align="left">
  <img src="https://img.shields.io/badge/platform-linux-2ea44f" alt="Linux" />
  <img src="https://img.shields.io/badge/status-active-1f6feb" alt="Status" />
  <img src="https://img.shields.io/badge/installer-one--script-orange" alt="One script installer" />
  <img src="https://img.shields.io/badge/Codex%20Mobile-pairing%20enabled-7c3aed" alt="Codex Mobile pairing enabled" />
  <img src="https://img.shields.io/badge/runtime-electron-black" alt="Electron" />
  <img src="https://img.shields.io/badge/version-2026.05.16--mobile--pairing-blue" alt="Installer version 2026.05.16-mobile-pairing" />
  <img src="https://img.shields.io/badge/project-unofficial-red" alt="Unofficial" />
</p>

OpenAI does not currently ship a native Codex desktop app for Linux. That matters more now because Codex Mobile expects a desktop Codex app to approve phone pairing. This project fills that gap by converting the official macOS Codex `.dmg` into a Linux-compatible Electron bundle and patching the Linux build so Codex Mobile pairing is available.

Download the script, execute it, and it builds a runnable `codex-linux` app directory for you.

## Why this exists

Codex desktop is distributed for macOS, while Linux users are left without a first-party desktop app. The core app is Electron-based, so with extraction, dependency filtering, native module rebuilds, and a few Linux compatibility patches, it can run on Linux.

The latest Codex mobile workflow also depends on desktop-side authentication and device approval. Without this port, Linux users can get stuck at the mobile app's **Waiting for desktop** step because there is no official Linux desktop client to approve the connection.

## What this gives Linux users

- A runnable Codex desktop app on Linux from the official Codex DMG.
- A one-script install flow: run `install-codex-linux.sh`, then launch `codex-linux/codex-linux.sh`.
- Codex Mobile pairing support through the desktop **Settings → Connections → Control other devices** flow.
- `codex://` URL handler registration so auth callbacks can return to the desktop app.
- Linux rebuilds/stubs for native and macOS-only Electron dependencies.

## Features

- **Unofficial Linux desktop port**: converts the official Codex macOS DMG into a runnable Linux Electron app.
- **Codex Mobile pairing**: exposes the desktop approval flow Linux users need when the phone app says **Waiting for desktop**.
- **One-script installer**: downloads or reuses a DMG, extracts the app, installs dependencies, rebuilds native modules, and creates a launcher.
- **Desktop integration**: adds a Linux app menu entry and registers `codex://` callback handling.
- **Latest-DMG compatibility patches**: filters macOS/workspace-only dependencies and applies Linux-specific runtime fixes.

## Quick start

### Option A: one command

```bash
curl -fsSL https://raw.githubusercontent.com/areu01or00/Codex-App-Linux/main/install-codex-linux.sh | bash
```

### Option B: clone and run

```bash
git clone https://github.com/areu01or00/Codex-App-Linux.git
cd Codex-App-Linux
chmod +x install-codex-linux.sh
./install-codex-linux.sh
```

Then launch:

```bash
cd codex-linux
./codex-linux.sh
```

The installer also creates a desktop entry, so after the first install you can usually launch **Codex (Linux Port)** from your app menu.

## Installer flags

```bash
./install-codex-linux.sh --dmg /path/to/Codex.dmg
./install-codex-linux.sh --output /path/to/codex-linux
./install-codex-linux.sh --skip-cli-install
```

## What the installer does

Installer version: `2026.05.16-mobile-pairing`

1. Uses a local DMG if available, otherwise downloads latest from OpenAI CDN.
2. Extracts `app.asar` from the app bundle.
3. Builds Linux runtime metadata from extracted app version/dependencies.
4. Installs Electron + dependencies and rebuilds native modules for Linux.
5. Stubs macOS-only modules (`sparkle`, `electron-liquid-glass`).
6. Patches Linux-specific Codex Mobile pairing feature gates.
7. Generates launcher script and desktop entry.
8. Registers `codex://` as a Linux URL handler for desktop auth callbacks.

## Codex Mobile pairing

This Linux port supports the newer Codex phone pairing flow used by the Codex mobile app. The official Codex desktop app is not distributed for Linux, so the mobile app can otherwise wait for a desktop approval step Linux users cannot complete. This installer patches the desktop web UI so the mobile pairing controls are visible on Linux and registers the `codex://` URL scheme used by auth callbacks.

After installing:

1. Launch Codex from `codex-linux/codex-linux.sh` or the desktop app entry.
2. Open **Settings**.
3. Go to **Connections**.
4. Use the Codex Mobile / **Control other devices** setup flow.
5. Allow this device to be discovered and controlled.
6. Open the Codex mobile app and tap **Connect**.

If you only see fields such as **Display Name**, **Hostname**, and **SSH port**, that is the SSH remote-host setup form, not the phone pairing flow. Re-run the latest installer so the mobile pairing UI patch is applied.

## Version diagnostics

After install, the script writes:

`codex-linux/build-info.json`

This includes:
- installer version
- Codex app version/build from the DMG
- Electron runtime version
- selected main entrypoint
- DMG path + SHA256
- Codex CLI path + version

Attach this file in issues. It makes compatibility debugging much faster.

## Requirements

- Linux (tested on Ubuntu 22.04+)
- Node.js + npm
- `curl`
- ~500MB free disk

## Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot find module ...` on startup | Re-run installer so dependencies are regenerated for that DMG build |
| `codex-app-server-version-unsupported` | Update CLI: `npm i -g @openai/codex@latest`; launcher should use `which codex` |
| CLI not found | Install CLI globally or let launcher use built-in `npx` fallback |
| Blank/failed window | Ensure `.vite` and `webview` exist under install output directory |
| Phone/browser auth does not return to Codex | Re-run installer, then verify `xdg-mime query default x-scheme-handler/codex` returns `codex-linux.desktop` |

## Authentication callbacks

Recent Codex desktop builds register a `codex://` URL scheme. The Linux port mirrors that by creating a desktop entry with:

```desktop
MimeType=x-scheme-handler/codex;
Exec=/path/to/codex-linux/codex-linux.sh %u
```

The `%u` is important: it passes the callback URL, such as `codex://connector/oauth_callback`, into Electron so the app can complete the desktop authentication flow.

## What is not committed

The repository intentionally does not commit downloaded or generated app files:

- `Codex-latest.dmg` / `*.dmg`: official app binaries downloaded from OpenAI
- `codex-linux/`: generated Linux app output
- `node_modules/`, logs, and temporary build folders

That is the correct setup: this repo distributes the installer and docs only, not OpenAI application binaries or generated dependency trees.

## Repo files

- `install-codex-linux.sh`: one-click installer
- `.gitignore`: excludes downloaded DMGs and generated install output
- `Reverse-engineering-guide.md`: technical breakdown of the original approach
- `README.md`: usage and troubleshooting

## Legal

This project distributes tooling/instructions only. It does not distribute OpenAI app binaries.

You must obtain `Codex.dmg` from official OpenAI sources.

Not affiliated with OpenAI.
