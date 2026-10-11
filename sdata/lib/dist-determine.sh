# Determine distribution for iNiR installer
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

# Global variables set by detection
OS_GROUP_ID=""
OS_SPECIFIC_ID=""
OS_VERSION=""
OS_PRETTY_NAME=""

###############################################################################
# Arch-based detection
###############################################################################
function print_arch_info(){
  if [[ -f /etc/arch-release ]] || command -v pacman &>/dev/null; then
    OS_GROUP_ID="arch"
    
    # Detect specific distro
    if [[ -f /etc/cachyos-release ]] || grep -qiE '^ID="?cachyos"?$' /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="cachyos"
      OS_PRETTY_NAME="CachyOS"
    elif [[ -f /etc/endeavouros-release ]]; then
      OS_SPECIFIC_ID="endeavouros"
      OS_PRETTY_NAME="EndeavourOS"
    elif grep -qi "manjaro" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="manjaro"
      OS_PRETTY_NAME="Manjaro"
    elif grep -qi "garuda" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="garuda"
      OS_PRETTY_NAME="Garuda Linux"
    elif grep -qi "artix" /etc/os-release 2>/dev/null; then
      OS_SPECIFIC_ID="artix"
      OS_PRETTY_NAME="Artix Linux"
    else
      OS_SPECIFIC_ID="arch"
      OS_PRETTY_NAME="Arch Linux"
    fi
    
    if ! ${quiet:-false}; then
      echo -e "${STY_GREEN}Detected: Arch-based system${STY_RST}"
      echo -e "${STY_CYAN}  Distribution: ${OS_PRETTY_NAME}${STY_RST}"
    fi
  fi
}

###############################################################################
# Main detection function
###############################################################################
detect_distro(){
  # Reset globals
  OS_GROUP_ID=""
  OS_SPECIFIC_ID=""
  OS_VERSION=""
  OS_PRETTY_NAME=""

  print_arch_info

  if [[ -z "$OS_GROUP_ID" ]]; then
    echo -e "${STY_RED}Unsupported distribution.${STY_RST}" >&2
    echo "This fork of iNiR only supports Arch Linux and derivatives" >&2
    echo "(CachyOS, EndeavourOS, Manjaro, Garuda, Artix)." >&2
    exit 1
  fi
}

###############################################################################
# Helper functions
###############################################################################

# Check if distro uses systemd
uses_systemd() {
  [[ -d /run/systemd/system ]]
}

# Get package manager for current distro
get_package_manager() {
  echo "pacman"
}

# Check if AUR is available
has_aur() {
  [[ "$OS_GROUP_ID" == "arch" ]]
}

# Print distro info summary
print_distro_summary() {
  echo ""
  echo -e "${STY_CYAN}System Information:${STY_RST}"
  echo "  Distribution: ${OS_PRETTY_NAME}"
  echo "  Family: ${OS_GROUP_ID}"
  echo "  Package Manager: $(get_package_manager)"
  [[ -n "$OS_VERSION" ]] && echo "  Version: ${OS_VERSION}"
  uses_systemd && echo "  Init: systemd" || echo "  Init: other"
  echo ""
}
