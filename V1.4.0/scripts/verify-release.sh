#!/bin/bash
set -euo pipefail

APP_PATH="${1:-DerivedData/Build/Products/Release/右键派.app}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

if [[ ! -d "$APP_PATH" ]]; then
  echo "错误：找不到 App：$APP_PATH" >&2
  exit 1
fi

check_bundle() {
  local bundle="$1"
  local label
  local entitlements
  local signature
  local flags

  label="$(basename "$bundle")"
  entitlements="$TEMP_DIR/${label}.entitlements.plist"

  codesign --verify --strict --verbose=2 "$bundle"
  codesign -d --entitlements :- "$bundle" >"$entitlements" 2>/dev/null

  if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements" >/dev/null 2>&1; then
    echo "错误：${label} 仍包含 com.apple.security.get-task-allow。" >&2
    exit 1
  fi

  signature="$(codesign -dv --verbose=4 "$bundle" 2>&1)"
  flags="$(printf '%s\n' "$signature" | awk '/^CodeDirectory .* flags=/{for (i = 1; i <= NF; i++) if ($i ~ /^flags=/) {print $i; exit}}')"
  case "$flags" in
    *"(runtime)"*|*"runtime,"*|*",runtime)"*) ;;
    *)
      echo "错误：${label} 未启用 Hardened Runtime。" >&2
      exit 1
      ;;
  esac

  echo "通过：${label}（无 get-task-allow，Hardened Runtime 已启用）"
}

check_bundle "$APP_PATH"

for extension in "$APP_PATH"/Contents/PlugIns/*.appex; do
  [[ -e "$extension" ]] || continue
  check_bundle "$extension"
done

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "发行检查通过：$APP_PATH"
