#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC_KEY_FILE="$ROOT/config/sparkle-public-key.txt"
MODE="${1:-setup}"

find_generate_keys() {
  find "$ROOT/.build/artifacts" -type f -path '*/Sparkle/bin/generate_keys' -print -quit 2>/dev/null || true
}

GENERATE_KEYS="$(find_generate_keys)"
if [[ -z "$GENERATE_KEYS" ]]; then
  echo "Sparkle key tool is missing; building the release product first" >&2
  swift build -c release --product ZhiziTime
  GENERATE_KEYS="$(find_generate_keys)"
fi
[[ -x "$GENERATE_KEYS" ]] || { echo "cannot find Sparkle generate_keys" >&2; exit 1; }

case "$MODE" in
  setup)
    public_key="$("$GENERATE_KEYS" -p 2>/dev/null || true)"
    if [[ -z "$public_key" ]]; then
      output="$("$GENERATE_KEYS")"
      public_key="$(printf '%s\n' "$output" | sed -n 's/.*<string>\([^<]*\)<\/string>.*/\1/p' | head -n 1)"
    fi
    [[ "$public_key" =~ ^[A-Za-z0-9+/]+=*$ ]] || { echo "Sparkle did not return a valid public key" >&2; exit 1; }
    mkdir -p "$(dirname "$PUBLIC_KEY_FILE")"
    printf '%s\n' "$public_key" > "$PUBLIC_KEY_FILE"
    chmod 644 "$PUBLIC_KEY_FILE"
    echo "Sparkle public key written to $PUBLIC_KEY_FILE"
    echo "The private key remains in the macOS Keychain. Export it explicitly with:"
    echo "  task sparkle:keys:export-private -- \"\$TMPDIR/sparkle-private-key.txt\""
    ;;
  check)
    keychain_key="$("$GENERATE_KEYS" -p 2>/dev/null)"
    file_key="$(tr -d '[:space:]' < "$PUBLIC_KEY_FILE" 2>/dev/null || true)"
    [[ -n "$keychain_key" && "$keychain_key" == "$file_key" ]] || {
      echo "Sparkle public key file does not match the macOS Keychain" >&2
      exit 1
    }
    echo "Sparkle public key matches the macOS Keychain"
    ;;
  export-private)
    PRIVATE_PATH="${2:?usage: configure_sparkle_keys.sh export-private <output-path>}"
    umask 077
    mkdir -p "$(dirname "$PRIVATE_PATH")"
    "$GENERATE_KEYS" -x "$PRIVATE_PATH"
    chmod 600 "$PRIVATE_PATH"
    echo "Private key exported to $PRIVATE_PATH; upload it to GitHub Secret SPARKLE_EDDSA_PRIVATE_KEY and delete the file."
    ;;
  *)
    echo "usage: $0 [setup|check|export-private <output-path>]" >&2
    exit 2
    ;;
esac
