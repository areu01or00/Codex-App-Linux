#!/bin/bash
#
# Codex Linux Installer (Unofficial)
# Builds a Linux runnable Codex desktop app from the official macOS DMG.
#
# Usage:
#   chmod +x install-codex-linux.sh
#   ./install-codex-linux.sh
#   ./install-codex-linux.sh --dmg /path/to/Codex.dmg
#   ./install-codex-linux.sh --output /path/to/codex-linux
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEFAULT_DMG_URL="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
DEFAULT_OUTPUT_DIR="$SCRIPT_DIR/codex-linux"
WORK_DIR="$(mktemp -d /tmp/codex-linux-install-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

DMG_PATH=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
SKIP_CLI_INSTALL="0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

usage() {
  cat <<USAGE
Codex Linux Installer (Unofficial)

Options:
  --dmg <path>       Use an existing Codex DMG
  --output <path>    Install output directory (default: $DEFAULT_OUTPUT_DIR)
  --skip-cli-install Do not attempt global Codex CLI install/update
  -h, --help         Show this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dmg)
      DMG_PATH="${2:-}"
      [ -n "$DMG_PATH" ] || error "--dmg requires a path"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      [ -n "$OUTPUT_DIR" ] || error "--output requires a path"
      shift 2
      ;;
    --skip-cli-install)
      SKIP_CLI_INSTALL="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Codex Linux Installer (Unofficial)          ║${NC}"
echo -e "${CYAN}║    Frictionless DMG -> Linux app conversion       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------------------------
# Prereqs
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

command -v node >/dev/null 2>&1 || error "Node.js is required (v18+ recommended)."
command -v npm >/dev/null 2>&1 || error "npm is required."
command -v curl >/dev/null 2>&1 || error "curl is required."

success "Node.js: $(node --version)"
success "npm: $(npm --version)"

# -----------------------------------------------------------------------------
# Resolve DMG
# -----------------------------------------------------------------------------
resolve_dmg_path() {
  if [ -n "$DMG_PATH" ]; then
    [ -f "$DMG_PATH" ] || error "DMG not found: $DMG_PATH"
    echo "$DMG_PATH"
    return
  fi

  local candidates=(
    "$SCRIPT_DIR/Codex-latest.dmg"
    "$SCRIPT_DIR/Codex.dmg"
    "$SCRIPT_DIR"/*.dmg
  )

  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      echo "$c"
      return
    fi
  done

  local downloaded="$SCRIPT_DIR/Codex-latest.dmg"
  log "No local DMG found. Downloading latest Codex DMG..."
  curl -fL --retry 3 --connect-timeout 20 -o "$downloaded" "$DEFAULT_DMG_URL" || error "Failed to download DMG from $DEFAULT_DMG_URL"
  echo "$downloaded"
}

DMG_PATH="$(resolve_dmg_path)"
success "Using DMG: $DMG_PATH"
DMG_SHA256="unknown"
if command -v sha256sum >/dev/null 2>&1; then
  DMG_SHA256="$(sha256sum "$DMG_PATH" | awk '{print $1}')"
fi

# -----------------------------------------------------------------------------
# 7zip
# -----------------------------------------------------------------------------
find_7zip() {
  if command -v 7z >/dev/null 2>&1; then
    echo "7z"
    return
  fi
  if command -v 7zz >/dev/null 2>&1; then
    echo "7zz"
    return
  fi
  if [ -x /tmp/7zz ]; then
    echo "/tmp/7zz"
    return
  fi

  log "7z not found. Downloading portable 7zip..."
  curl -fsSL https://www.7-zip.org/a/7z2408-linux-x64.tar.xz -o /tmp/7z.tar.xz || error "Failed to download 7zip"
  tar -xf /tmp/7z.tar.xz -C /tmp/ || error "Failed to extract 7zip"
  [ -x /tmp/7zz ] || error "7zip binary not found after extraction"
  echo "/tmp/7zz"
}

SEVEN_ZIP="$(find_7zip)"
success "7zip ready: $SEVEN_ZIP"

# -----------------------------------------------------------------------------
# Extract DMG + ASAR
# -----------------------------------------------------------------------------
log "Extracting DMG..."
"$SEVEN_ZIP" x "$DMG_PATH" -o"$WORK_DIR/extracted" -y >"$WORK_DIR/7z.log" 2>&1 || true

ASAR_PATH="$(find "$WORK_DIR/extracted" -name app.asar -type f 2>/dev/null | head -1)"
APP_PLIST="$(find "$WORK_DIR/extracted" -path '*/Codex.app/Contents/Info.plist' -type f 2>/dev/null | head -1)"

[ -n "$ASAR_PATH" ] || error "app.asar not found in DMG extraction"
[ -n "$APP_PLIST" ] || error "Codex app Info.plist not found in DMG extraction"

success "Found app payload"

run_asar_extract() {
  local src="$1"
  local dst="$2"

  if command -v asar >/dev/null 2>&1; then
    asar extract "$src" "$dst"
    return
  fi

  # No global asar: use npm exec to avoid permanent global state
  npm exec --yes @electron/asar -- extract "$src" "$dst"
}

log "Extracting app.asar..."
run_asar_extract "$ASAR_PATH" "$WORK_DIR/app_src" || error "Failed to extract app.asar"

[ -d "$WORK_DIR/app_src/.vite" ] || error "Extracted app is missing .vite"
[ -d "$WORK_DIR/app_src/webview" ] || error "Extracted app is missing webview"
[ -f "$WORK_DIR/app_src/package.json" ] || error "Extracted app is missing package.json"

# -----------------------------------------------------------------------------
# Build metadata + package.json synthesis
# -----------------------------------------------------------------------------
log "Synthesizing Linux package metadata..."

APP_VERSION="$(awk '/CFBundleShortVersionString/{getline; gsub(/.*<string>|<\/string>.*/,""); print; exit}' "$APP_PLIST")"
APP_BUILD="$(awk '/CFBundleVersion/{getline; gsub(/.*<string>|<\/string>.*/,""); print; exit}' "$APP_PLIST")"
[ -n "$APP_VERSION" ] || APP_VERSION="unknown"
[ -n "$APP_BUILD" ] || APP_BUILD="unknown"

node - "$WORK_DIR/app_src/package.json" "$WORK_DIR/package.generated.json" "$APP_VERSION" <<'NODE'
const fs = require("fs");
const srcPkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const outPath = process.argv[3];
const appVersion = process.argv[4];

const sourceDeps = srcPkg.dependencies || {};
const excludedWorkspaceDeps = new Set([
  "app-server-types",
  "browser-common",
  "protocol",
  "shared-node",
]);
const excludedPlatformDeps = new Set([
  "electron-liquid-glass",
]);

const deps = {};
for (const [name, version] of Object.entries(sourceDeps)) {
  if (excludedWorkspaceDeps.has(name)) continue;
  if (excludedPlatformDeps.has(name)) continue;
  deps[name] = version;
}

const electronVersion =
  (srcPkg.devDependencies && srcPkg.devDependencies.electron) ||
  (srcPkg.dependencies && srcPkg.dependencies.electron) ||
  "40.0.0";

const output = {
  name: "codex-linux",
  productName: "Codex",
  version: `${appVersion}-linux`,
  description: "Codex for Linux (unofficial port)",
  main: srcPkg.main || ".vite/build/bootstrap.js",
  scripts: {
    start: "electron .",
    "start:debug": "electron . --enable-logging"
  },
  dependencies: deps,
  devDependencies: {
    electron: electronVersion,
    "@electron/rebuild": "^4.0.3"
  }
};

fs.writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`);
NODE

# -----------------------------------------------------------------------------
# Install tree
# -----------------------------------------------------------------------------
log "Preparing output directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cp -r "$WORK_DIR/app_src/.vite" "$OUTPUT_DIR/"
cp -r "$WORK_DIR/app_src/webview" "$OUTPUT_DIR/"
if [ -d "$WORK_DIR/app_src/native" ]; then
  cp -r "$WORK_DIR/app_src/native" "$OUTPUT_DIR/"
else
  mkdir -p "$OUTPUT_DIR/native"
fi
cp "$WORK_DIR/package.generated.json" "$OUTPUT_DIR/package.json"

# Ensure main points to an existing file for newer hashed bundles.
node - "$OUTPUT_DIR/package.json" <<'NODE'
const fs = require("fs");
const path = require("path");
const pkgPath = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
const root = path.dirname(pkgPath);
const buildDir = path.join(root, ".vite", "build");

const candidates = [
  pkg.main,
  ".vite/build/bootstrap.js",
  ".vite/build/main.js",
];

let chosen = null;
for (const c of candidates) {
  if (!c) continue;
  if (fs.existsSync(path.join(root, c))) {
    chosen = c;
    break;
  }
}

if (!chosen && fs.existsSync(buildDir)) {
  const hashedMain = fs.readdirSync(buildDir).find((n) => /^main-.*\.js$/.test(n));
  if (hashedMain) chosen = `.vite/build/${hashedMain}`;
}

if (!chosen) chosen = ".vite/build/bootstrap.js";
pkg.main = chosen;
fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`);
NODE

APP_MAIN_ENTRY="$(node -e "const p=require('$OUTPUT_DIR/package.json'); console.log(p.main||'unknown')")"
ELECTRON_RUNTIME_VERSION="$(node -e "const p=require('$OUTPUT_DIR/package.json'); console.log((p.devDependencies&&p.devDependencies.electron)||'unknown')")"

# -----------------------------------------------------------------------------
# npm install + rebuild
# -----------------------------------------------------------------------------
log "Installing npm dependencies (this can take a few minutes)..."
(
  cd "$OUTPUT_DIR"
  npm install
)
success "Dependencies installed"

log "Rebuilding native modules for Electron..."
(
  cd "$OUTPUT_DIR"
  npx @electron/rebuild
)
success "Native modules rebuilt"

# -----------------------------------------------------------------------------
# Linux stubs / launcher
# -----------------------------------------------------------------------------
log "Applying Linux compatibility patches..."

rm -f "$OUTPUT_DIR/native/sparkle.node" 2>/dev/null || true

mkdir -p "$OUTPUT_DIR/node_modules/electron-liquid-glass"
cat > "$OUTPUT_DIR/node_modules/electron-liquid-glass/index.js" <<'STUBJS'
const stub = {
  isGlassSupported: () => false,
  enable: () => {},
  disable: () => {},
  setOptions: () => {}
};
module.exports = stub;
module.exports.default = stub;
STUBJS

cat > "$OUTPUT_DIR/node_modules/electron-liquid-glass/package.json" <<'STUBPKG'
{"name":"electron-liquid-glass","version":"1.0.0","main":"index.js"}
STUBPKG

mkdir -p "$OUTPUT_DIR/bin"
cat > "$OUTPUT_DIR/bin/codex-fallback" <<'CLIWRAP'
#!/bin/bash
set -euo pipefail
exec npx --yes @openai/codex@latest "$@"
CLIWRAP
chmod +x "$OUTPUT_DIR/bin/codex-fallback"

cat > "$OUTPUT_DIR/codex-linux.sh" <<'LAUNCHER'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export ELECTRON_RENDERER_URL="file://${SCRIPT_DIR}/webview/index.html"

if [ -z "${CODEX_CLI_PATH:-}" ]; then
  if command -v codex >/dev/null 2>&1; then
    export CODEX_CLI_PATH="$(command -v codex)"
  else
    export CODEX_CLI_PATH="${SCRIPT_DIR}/bin/codex-fallback"
  fi
fi

exec ./node_modules/.bin/electron . --no-sandbox "$@"
LAUNCHER
chmod +x "$OUTPUT_DIR/codex-linux.sh"

success "Launcher created"

# -----------------------------------------------------------------------------
# Optional CLI install/update
# -----------------------------------------------------------------------------
if [ "$SKIP_CLI_INSTALL" = "1" ]; then
  warn "Skipping Codex CLI install/update by request (--skip-cli-install)."
else
  log "Ensuring Codex CLI is available..."
  if command -v codex >/dev/null 2>&1; then
    success "Codex CLI found: $(command -v codex) ($(codex --version 2>/dev/null || echo unknown))"
  else
    warn "Codex CLI not found in PATH. Attempting global install..."
    if npm install -g @openai/codex@latest >/dev/null 2>&1; then
      success "Installed Codex CLI globally: $(command -v codex)"
    else
      warn "Global install failed (likely permissions). Launcher will use local npx fallback."
    fi
  fi
fi

CLI_PATH_USED="$OUTPUT_DIR/bin/codex-fallback"
CLI_VERSION_USED="npx @openai/codex@latest (fallback)"
if command -v codex >/dev/null 2>&1; then
  CLI_PATH_USED="$(command -v codex)"
  CLI_VERSION_USED="$(codex --version 2>/dev/null || echo unknown)"
fi

node - "$OUTPUT_DIR/build-info.json" \
  "$APP_VERSION" "$APP_BUILD" "$ELECTRON_RUNTIME_VERSION" "$APP_MAIN_ENTRY" \
  "$DMG_PATH" "$DMG_SHA256" "$CLI_PATH_USED" "$CLI_VERSION_USED" <<'NODE'
const fs = require("fs");
const outPath = process.argv[2];
const payload = {
  generatedAt: new Date().toISOString(),
  codexAppVersion: process.argv[3],
  codexAppBuild: process.argv[4],
  electronRuntime: process.argv[5],
  mainEntry: process.argv[6],
  dmgPath: process.argv[7],
  dmgSha256: process.argv[8],
  cliPath: process.argv[9],
  cliVersion: process.argv[10],
};
fs.writeFileSync(outPath, JSON.stringify(payload, null, 2) + "\n");
NODE

# -----------------------------------------------------------------------------
# Desktop shortcut (best effort)
# -----------------------------------------------------------------------------
DESKTOP_FILE="$HOME/.local/share/applications/codex-linux.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Name=Codex (Linux Port)
Comment=Run Codex desktop app on Linux (unofficial)
Exec=$OUTPUT_DIR/codex-linux.sh
Terminal=false
Type=Application
Categories=Development;
DESKTOP

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Installation Complete!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installed app: $OUTPUT_DIR"
echo "App version:   $APP_VERSION (build $APP_BUILD)"
echo "Electron:      $ELECTRON_RUNTIME_VERSION"
echo "Main entry:    $APP_MAIN_ENTRY"
echo "DMG source:    $DMG_PATH"
echo "DMG sha256:    $DMG_SHA256"
echo "Codex CLI:     $CLI_PATH_USED ($CLI_VERSION_USED)"
echo "Build info:    $OUTPUT_DIR/build-info.json"
echo ""
echo "Launch:"
echo "  cd \"$OUTPUT_DIR\""
echo "  ./codex-linux.sh"
echo ""
echo "Desktop entry: $DESKTOP_FILE"
echo ""
