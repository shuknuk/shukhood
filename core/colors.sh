#!/usr/bin/env bash
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
  C_RESET=""; C_INFO=""; C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_BLUE=""; C_PURPLE=""
else
  C_RESET=$'\033[0m'
  C_INFO=$'\033[38;5;110m'   # nord8-ish
  C_OK=$'\033[38;5;108m'     # nord14-ish
  C_WARN=$'\033[38;5;222m'   # nord13-ish
  C_ERR=$'\033[38;5;167m'    # nord11-ish
  C_DIM=$'\033[38;5;240m'    # nord3-ish
  C_BLUE=$'\033[38;5;67m'    # nord10-ish
  C_PURPLE=$'\033[38;5;139m' # nord15-ish
fi
