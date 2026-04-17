# Codex for Linux (Unofficial)

Run OpenAI's Codex desktop app on Linux by extracting and patching the macOS version.

```
╔═══════════════════════════════════════════════════╗
║       Codex Linux Installer (Unofficial)          ║
╚═══════════════════════════════════════════════════╝
```

## Quick Start

1. Download `install-codex-linux.sh` from this repo
2. Run:

```bash
chmod +x install-codex-linux.sh
./install-codex-linux.sh
```

The installer will automatically download the latest official Codex DMG if no local `.dmg` is found.

3. Launch:

```bash
cd codex-linux
./codex-linux.sh
```

## Installer Options

```bash
./install-codex-linux.sh --dmg /path/to/Codex.dmg
./install-codex-linux.sh --output /path/to/codex-linux
./install-codex-linux.sh --skip-cli-install
```

## Updating to a New Codex DMG

If OpenAI ships a newer macOS build, you can refresh this Linux port in place:

```bash
cd codex-linux-port
./refresh-from-dmg.sh ../Codex.dmg
npm install
npx @electron/rebuild
./codex-linux.sh
```

`refresh-from-dmg.sh` will:
- extract the new DMG
- replace `.vite`, `webview`, and `native` with fresh app payload
- stub macOS-only modules
- update local `package.json` version/electron pin from the extracted app metadata

## Requirements

- Linux (tested on Ubuntu 22.04+, should work on most distros)
- Node.js 18+ and npm
- ~500MB disk space

## What This Does

The installer:

1. Resolves a DMG source (local file or latest official download URL)
2. Extracts app payload from `app.asar`
3. Builds `package.json` from extracted app metadata (version, electron, deps)
4. Installs/rebuilds native modules for Linux
5. Stubs macOS-only modules (`electron-liquid-glass`, `sparkle`)
6. Creates a launcher that prefers your current `codex` CLI in `PATH`
7. Adds a desktop entry (`~/.local/share/applications/codex-linux.desktop`)

## How It Works

OpenAI's Codex app is built with Electron - a cross-platform framework that bundles Chromium and Node.js. While they only ship a macOS build, the core application is JavaScript/TypeScript that can run on any platform.

The main challenges for Linux:
- **Native modules** compiled for macOS (Mach-O binaries) need rebuilding for Linux (ELF binaries)
- **macOS-specific features** like the Sparkle auto-updater and liquid glass visual effects need to be stubbed

See [PORTING-GUIDE.md](PORTING-GUIDE.md) for the full technical breakdown.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Blank window | Verify `webview/index.html` exists |
| "CLI not found" | Run `npm install -g @openai/codex` |
| Auth issues | Run `codex auth` in terminal first |
| Sandbox errors | Script already uses `--no-sandbox` |

## Files

```
├── install-codex-linux.sh   # One-click installer
├── PORTING-GUIDE.md         # Technical deep-dive
└── README.md                # You are here
```

## Legal

This project provides **instructions only** - no OpenAI code is distributed. Users must obtain `Codex.dmg` directly from OpenAI.

For personal and educational use. Not affiliated with OpenAI.

## Credits

Reverse engineered with curiosity and caffeine.
