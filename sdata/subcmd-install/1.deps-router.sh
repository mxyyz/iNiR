# Dependency installation router for iNiR
# This script is meant to be sourced.

# shellcheck shell=bash

printf "${STY_CYAN}[$0]: 1. Install dependencies${STY_RST}\n"

if [[ "${OS_GROUP_ID:-}" != "arch" ]]; then
  printf "${STY_RED}Unsupported distribution: only Arch Linux and derivatives are supported.${STY_RST}\n" >&2
  return 1
fi

printf "${STY_GREEN}Using Arch Linux installer${STY_RST}\n"
source ./sdata/dist-arch/install-deps.sh
