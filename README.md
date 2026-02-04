# Codex for Linux (Unofficial)

Run OpenAI's Codex desktop app on Linux by extracting and patching the macOS version.

```
╔═══════════════════════════════════════════════════╗
║       Codex Linux Installer (Unofficial)          ║
╚═══════════════════════════════════════════════════╝
```

## Quick Start

1. Download `Codex.dmg` from [OpenAI](https://openai.com/codex)
2. Download `install-codex-linux.sh` from this repo
3. Put both files in the same folder
4. Run:

```bash
chmod +x install-codex-linux.sh
./install-codex-linux.sh
```

5. Launch:

```bash
cd codex-linux
./codex-linux.sh
```

## Requirements

- Linux (tested on Ubuntu 22.04+, should work on most distros)
- Node.js 18+ and npm
- ~500MB disk space

## What This Does

The installer:

1. Extracts the DMG using 7zip
2. Unpacks the Electron app's `app.asar` archive
3. Installs Linux-compatible Electron runtime (v40)
4. Rebuilds native modules (`better-sqlite3`, `node-pty`) for Linux
5. Stubs macOS-only modules (`electron-liquid-glass`, `sparkle`)
6. Creates a launcher script

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
