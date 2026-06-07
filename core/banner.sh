#!/usr/bin/env bash
SHUK_ROOT="${SHUK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SHUK_ROOT/core/colors.sh"
shuk_banner() {
  local width
  width="${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}"
  if [[ "$width" -lt 90 ]]; then
    printf "%b%s%b\n%b%s%b\n" "$C_INFO" '$HUKHOOD' "$C_RESET" "$C_DIM" "your personal AI home" "$C_RESET"
    return
  fi
  while IFS= read -r line; do
    printf "%b%s%b\n" "$C_INFO" "$line" "$C_RESET"
  done < "$SHUK_ROOT/assets/banner.txt"
  printf "\n%b%s%b\n%b%s%b\n" "$C_OK" '$HUKHOOD — your personal AI home' "$C_RESET" "$C_DIM" 'official agents, personal configs' "$C_RESET"
}
