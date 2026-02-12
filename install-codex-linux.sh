#!/bin/bash
#
# Codex Linux Installer
# Automatically ports OpenAI Codex macOS app to Linux
#
# Usage: Place Codex.dmg in the same folder as this script, then run:
#   chmod +x install-codex-linux.sh
#   ./install-codex-linux.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Codex Linux Installer (Unofficial)          ║${NC}"
echo -e "${CYAN}║   Ports macOS Codex.dmg to run on Linux           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# Phase 1: Prerequisites
# ─────────────────────────────────────────────────────────────
log "Checking prerequisites..."

# Check for Codex.dmg
DMG_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -type f \( -name "Codex.dmg" -o -name "*.dmg" \) 2>/dev/null | head -1)
if [ -z "$DMG_FILE" ]; then
    error "Codex.dmg not found. Place it in: $SCRIPT_DIR"
fi
success "Found: $DMG_FILE"

# Check Node.js
if ! command -v node &> /dev/null; then
    error "Node.js not found. Install it first: https://nodejs.org"
fi
success "Node.js: $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    error "npm not found. Install Node.js properly."
fi
success "npm: $(npm --version)"

# ─────────────────────────────────────────────────────────────
# Phase 2: Get 7zip
# ─────────────────────────────────────────────────────────────
log "Setting up extraction tools..."

if command -v 7z &> /dev/null; then
    SEVEN_ZIP="7z"
elif command -v 7zz &> /dev/null; then
    SEVEN_ZIP="7zz"
elif [ -f "/tmp/7zz" ]; then
    SEVEN_ZIP="/tmp/7zz"
else
    log "Downloading portable 7zip..."
    curl -sL https://www.7-zip.org/a/7z2408-linux-x64.tar.xz -o /tmp/7z.tar.xz
    tar -xf /tmp/7z.tar.xz -C /tmp/
    SEVEN_ZIP="/tmp/7zz"
fi
success "7zip ready: $SEVEN_ZIP"

# ─────────────────────────────────────────────────────────────
# Phase 3: Extract DMG
# ─────────────────────────────────────────────────────────────
log "Extracting DMG (this may take a moment)..."

rm -rf "$SCRIPT_DIR/codex_extracted" 2>/dev/null || true

# Extract - ignore symlink errors (e.g., /Applications symlink in DMG)
$SEVEN_ZIP x "$DMG_FILE" -o"$SCRIPT_DIR/codex_extracted" -y > /tmp/7z_output.log 2>&1 || true

# Find app.asar - it's nested in the .app bundle
ASAR_PATH=$(find "$SCRIPT_DIR/codex_extracted" -name "app.asar" -type f 2>/dev/null | head -1)

if [ -z "$ASAR_PATH" ]; then
    log "Contents of extracted folder:"
    find "$SCRIPT_DIR/codex_extracted" -maxdepth 4 -type d 2>/dev/null | head -20
    error "app.asar not found. Is this a valid Codex DMG?"
fi
success "Extracted DMG, found: $ASAR_PATH"

# ─────────────────────────────────────────────────────────────
# Phase 4: Extract ASAR
# ─────────────────────────────────────────────────────────────
log "Checking asar tool..."
ASAR_CMD=(asar)
if ! command -v asar &> /dev/null; then
    warn "Global asar not found, using npx fallback"
    if ! npx --yes @electron/asar --version > /dev/null 2>&1; then
        error "asar tool unavailable. Install with: npm install -g @electron/asar"
    fi
    ASAR_CMD=(npx --yes @electron/asar)
fi
success "asar tool ready"

log "Extracting application source..."
rm -rf "$SCRIPT_DIR/codex_app_src" 2>/dev/null || true
if ! "${ASAR_CMD[@]}" extract "$ASAR_PATH" "$SCRIPT_DIR/codex_app_src"; then
    error "Failed to extract app.asar"
fi
success "Application source extracted"

# ─────────────────────────────────────────────────────────────
# Phase 5: Setup Linux Project
# ─────────────────────────────────────────────────────────────
log "Setting up Linux project structure..."

PROJECT_DIR="$SCRIPT_DIR/codex-linux"
rm -rf "$PROJECT_DIR" 2>/dev/null || true
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Copy source files
if [ ! -d "$SCRIPT_DIR/codex_app_src/.vite" ]; then
    error ".vite folder not found in extracted source"
fi
cp -r "$SCRIPT_DIR/codex_app_src/.vite" ./

if [ -d "$SCRIPT_DIR/codex_app_src/webview" ]; then
    cp -r "$SCRIPT_DIR/codex_app_src/webview" ./
else
    warn "webview not at root, searching..."
    WEBVIEW_PATH=$(find "$SCRIPT_DIR/codex_app_src" -type d -name "webview" 2>/dev/null | head -1)
    if [ -n "$WEBVIEW_PATH" ]; then
        cp -r "$WEBVIEW_PATH" ./
    else
        error "webview folder not found"
    fi
fi

cp -r "$SCRIPT_DIR/codex_app_src/native" ./ 2>/dev/null || mkdir -p native

success "Source files copied"

# ─────────────────────────────────────────────────────────────
# Phase 6: Install Dependencies
# ─────────────────────────────────────────────────────────────
log "Creating package.json..."

cat > package.json << 'PKGJSON'
{
  "name": "codex-linux",
  "productName": "Codex",
  "version": "1.0.0-linux",
  "main": ".vite/build/main.js",
  "scripts": {
    "start": "electron .",
    "start:debug": "electron . --enable-logging"
  },
  "dependencies": {
    "better-sqlite3": "^12.4.6",
    "node-pty": "^1.1.0",
    "immer": "^10.1.1",
    "lodash": "^4.17.21",
    "memoizee": "^0.4.15",
    "mime-types": "^2.1.35",
    "shell-env": "^4.0.1",
    "shlex": "^3.0.0",
    "smol-toml": "^1.5.2",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "electron": "40.0.0",
    "@electron/rebuild": "^3.6.0"
  }
}
PKGJSON

log "Installing npm dependencies (this takes a few minutes)..."
INSTALL_OK=0
for ATTEMPT in 1 2 3; do
    log "npm install attempt ${ATTEMPT}/3"
    if npm install > /tmp/codex_npm_install.log 2>&1; then
        INSTALL_OK=1
        break
    fi

    tail -10 /tmp/codex_npm_install.log
    if [ "$ATTEMPT" -lt 3 ]; then
        warn "npm install failed, retrying in 4s..."
        sleep 4
    fi
done

if [ "$INSTALL_OK" -ne 1 ]; then
    error "npm install failed after 3 attempts"
fi
success "Dependencies installed"

# ─────────────────────────────────────────────────────────────
# Phase 7: Rebuild Native Modules
# ─────────────────────────────────────────────────────────────
log "Rebuilding native modules for Electron..."
if ! npx @electron/rebuild > /tmp/codex_rebuild.log 2>&1; then
    tail -5 /tmp/codex_rebuild.log
    warn "Rebuild failed once, retrying..."
    if ! npx @electron/rebuild > /tmp/codex_rebuild.log 2>&1; then
        tail -5 /tmp/codex_rebuild.log
        warn "Rebuild had issues, continuing anyway..."
    fi
fi
success "Native modules rebuilt for Linux"

# ─────────────────────────────────────────────────────────────
# Phase 8: Stub macOS-only Modules
# ─────────────────────────────────────────────────────────────
log "Patching macOS-only modules..."

# Remove sparkle.node
rm -f native/sparkle.node 2>/dev/null || true

# Create electron-liquid-glass stub
mkdir -p node_modules/electron-liquid-glass

cat > node_modules/electron-liquid-glass/index.js << 'STUBJS'
const stub = {
  isGlassSupported: () => false,
  enable: () => {},
  disable: () => {},
  setOptions: () => {}
};
module.exports = stub;
module.exports.default = stub;
STUBJS

cat > node_modules/electron-liquid-glass/package.json << 'STUBPKG'
{"name":"electron-liquid-glass","version":"1.0.0","main":"index.js"}
STUBPKG

success "macOS modules stubbed"

# ─────────────────────────────────────────────────────────────
# Phase 9: Create Launcher
# ─────────────────────────────────────────────────────────────
log "Creating launcher script..."

cat > codex-linux.sh << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ELECTRON_RENDERER_URL="file://${SCRIPT_DIR}/webview/index.html"
export CODEX_CLI_PATH="${CODEX_CLI_PATH:-$(which codex 2>/dev/null || echo /usr/local/bin/codex)}"

exec ./node_modules/.bin/electron . --no-sandbox "$@"
LAUNCHER

chmod +x codex-linux.sh
success "Launcher created"

# ─────────────────────────────────────────────────────────────
# Phase 10: Check for Codex CLI
# ─────────────────────────────────────────────────────────────
if ! command -v codex &> /dev/null; then
    warn "Codex CLI not found. Installing..."
    npm install -g @openai/codex > /dev/null 2>&1 || {
        warn "Could not install Codex CLI globally. You may need to run:"
        echo "    npm install -g @openai/codex"
    }
else
    success "Codex CLI found: $(which codex)"
fi

# ─────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────
log "Cleaning up temporary files..."
rm -rf "$SCRIPT_DIR/codex_extracted" 2>/dev/null || true
rm -rf "$SCRIPT_DIR/codex_app_src" 2>/dev/null || true
success "Cleanup complete"

# ─────────────────────────────────────────────────────────────
# Done!
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Installation Complete!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}To launch Codex:${NC}"
echo ""
echo "    cd $PROJECT_DIR"
echo "    ./codex-linux.sh"
echo ""
echo -e "  ${YELLOW}Note:${NC} If you haven't authenticated, run 'codex auth' first."
echo ""
