# Codex App Linux (Unofficial)

<p align="left">
  <img src="https://img.shields.io/badge/platform-linux-2ea44f" alt="Linux" />
  <img src="https://img.shields.io/badge/status-active-1f6feb" alt="Status" />
  <img src="https://img.shields.io/badge/installer-one--click-orange" alt="One click installer" />
  <img src="https://img.shields.io/badge/runtime-electron-black" alt="Electron" />
  <img src="https://img.shields.io/badge/project-unofficial-red" alt="Unofficial" />
</p>

Run the official Codex desktop app on Linux by converting the macOS `.dmg` into a Linux-compatible Electron bundle.

## Why this exists

OpenAI ships Codex desktop for macOS. The core app is Electron-based, so with extraction + native module rebuilds, it can run on Linux.

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

## Installer flags

```bash
./install-codex-linux.sh --dmg /path/to/Codex.dmg
./install-codex-linux.sh --output /path/to/codex-linux
./install-codex-linux.sh --skip-cli-install
```

## What the installer does

1. Uses a local DMG if available, otherwise downloads latest from OpenAI CDN.
2. Extracts `app.asar` from the app bundle.
3. Builds Linux runtime metadata from extracted app version/dependencies.
4. Installs Electron + dependencies and rebuilds native modules for Linux.
5. Stubs macOS-only modules (`sparkle`, `electron-liquid-glass`).
6. Generates launcher script and desktop entry.

## Version diagnostics

After install, the script writes:

`codex-linux/build-info.json`

This includes:
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

## Repo files

- `install-codex-linux.sh`: one-click installer
- `Reverse-engineering-guide.md`: technical breakdown of the original approach
- `README.md`: usage and troubleshooting

## Legal

This project distributes tooling/instructions only. It does not distribute OpenAI app binaries.

You must obtain `Codex.dmg` from official OpenAI sources.

Not affiliated with OpenAI.
