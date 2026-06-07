#!/usr/bin/env bash
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/colors.sh"
info(){ printf "%b[i]%b %s\n" "$C_INFO" "$C_RESET" "$*"; }
ok(){ printf "%b[✓]%b %s\n" "$C_OK" "$C_RESET" "$*"; }
warn(){ printf "%b[!]%b %s\n" "$C_WARN" "$C_RESET" "$*"; }
err(){ printf "%b[x]%b %s\n" "$C_ERR" "$C_RESET" "$*" >&2; }
skip(){ printf "%b[-]%b %s\n" "$C_DIM" "$C_RESET" "$*"; }
