#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
case "${1:-all}" in
  all|hermes) "$SHUK_ROOT/apps/hermes/backup.sh" "${@:2}" ;;
  *) err "Unknown backup target: $1"; exit 2 ;;
esac
