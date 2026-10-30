#!/usr/bin/env bash
# Build "Anarlog Homelab": the staging channel (com.hyprnote.staging,
# anarlog-staging:// links, updater off) pointed at the homelab backend.
# Mirrors the build-macos job of .github/workflows/desktop_cd.yaml, minus the
# Apple certificate, notarization, Sentry and updater signing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$ROOT/.env.homelab"
TARGET="aarch64-apple-darwin"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# bin/swift forces SwiftPM's native build system (see the comment in that file).
export PATH="$ROOT/scripts/homelab/bin:/opt/homebrew/opt/rustup/bin:/opt/homebrew/bin:$PATH"

# iCloud Drive's File Provider stamps xattrs on the .app bundle (codesign then
# fails with "resource fork, Finder information, or similar detritus") and
# uploads the ~25 GB of build output: never build from a synced folder.
if xattr -p com.apple.file-provider-domain-id "$ROOT" >/dev/null 2>&1 ||
  [[ "$ROOT" == "$HOME/Documents"* || "$ROOT" == "$HOME/Desktop"* ]]; then
  echo "Refusing to build inside iCloud Drive ($ROOT); clone to ~/Developer instead" >&2
  exit 1
fi

[[ -d "$DEVELOPER_DIR" ]] || { echo "Xcode not found at $DEVELOPER_DIR" >&2; exit 1; }
xcrun -f metal >/dev/null 2>&1 || {
  echo "Metal toolchain missing: xcodebuild -downloadComponent MetalToolchain" >&2
  exit 1
}
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE (see scripts/homelab/env.homelab.example)" >&2; exit 1; }

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a
for v in VITE_APP_URL VITE_API_URL VITE_SUPABASE_URL VITE_SUPABASE_ANON_KEY; do
  [[ -n "${!v:-}" ]] || { echo "$v is empty in $ENV_FILE" >&2; exit 1; }
done

# Same version as the upstream release this branch is cut from (CI stamps it
# with scripts/version.sh; here it is passed as an inline config overlay).
APP_VERSION="$(jq -r .version "$ROOT/release-version.json")"
export APP_VERSION VITE_APP_VERSION="$APP_VERSION"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export SDKROOT
export CI=false CARGO_PROFILE_RELEASE_DEBUG=line-tables-only

cd "$ROOT"
pnpm install --frozen-lockfile
pnpm -F ui build
TAURI_ENV_TARGET_TRIPLE="$TARGET" cargo xtask prepare-binaries

cd apps/desktop
pnpm -F desktop tauri build \
  --target "$TARGET" \
  --config ./src-tauri/tauri.conf.staging.json \
  --config ./src-tauri/tauri.conf.homelab.json \
  --config "{\"version\":\"$APP_VERSION\"}" \
  --features devtools \
  --bundles app

echo "Built: $ROOT/apps/desktop/src-tauri/target/$TARGET/release/bundle/macos/Anarlog Homelab.app"
