#!/usr/bin/env bash
set -euo pipefail
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$SHUK_ROOT/core/logging.sh"
sub="${1:-}"
case "$sub" in
  setup) shift; exec "$SHUK_ROOT/apps/hermes/setup.sh" "$@" ;;
  backup) shift; exec "$SHUK_ROOT/apps/hermes/backup.sh" "$@" ;;
  doctor) shift; exec "$SHUK_ROOT/apps/hermes/doctor.sh" "$@" ;;
  update) shift; exec hermes update "$@" ;;
  raw) shift; exec hermes "$@" ;;
  "") exec hermes --profile shukhood --skills shukhood-router ;;
  -q|--query) exec hermes --profile shukhood --skills shukhood-router chat "$@" ;;
  *) exec hermes --profile shukhood --skills shukhood-router "$@" ;;
esac
