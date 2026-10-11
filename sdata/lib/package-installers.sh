# Package installation functions for iNiR
# This is NOT a script for execution, but for loading functions

# shellcheck shell=bash

#####################################################################################
# Privilege escalation helper with environment detection
#####################################################################################

# Detect if we're in a graphical environment
_is_graphical_env() {
  [[ -n "${DISPLAY}" ]] || [[ -n "${WAYLAND_DISPLAY}" ]] || [[ -n "${XDG_SESSION_TYPE}" && "${XDG_SESSION_TYPE}" == "wayland" || "${XDG_SESSION_TYPE}" == "x11" ]]
}

# Detect available privilege escalation methods
_detect_privilege_method() {
  local method=""
  
  # Check for graphical methods first (polkit-based)
  if command -v pkexec &>/dev/null && [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    # Test if polkit can authenticate
    if pkexec --version &>/dev/null; then
      method="pkexec"
    fi
  fi
  
  # Check for elevate (available in some graphical environments)
  if [[ -z "$method" ]] && command -v elevate &>/dev/null; then
    method="elevate"
  fi
  
  # Check for sudo
  if [[ -z "$method" ]] && command -v sudo &>/dev/null; then
    # Test if user has sudo permissions (non-interactive)
    if sudo -n true 2>/dev/null; then
      method="sudo"
    fi
  fi
  
  # Check for su (requires root password, not sudo password)
  if [[ -z "$method" ]] && command -v su &>/dev/null && [[ -r /etc/shadow || $(id -u) -eq 0 ]]; then
    method="su"
  fi
  
  echo "$method"
}

# Show environment-specific instructions
_show_privilege_instructions() {
  local reason="$1"
  
  echo -e "${STY_RED}Error: $reason${STY_RST}" >&2
  echo "" >&2
  
  if _is_graphical_env; then
    # Graphical environment detected
    echo -e "${STY_YELLOW}Detected: Graphical environment (Wayland/X11)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Run it from a terminal, so sudo can ask for your password," >&2
    echo "     or with the iNiR shell running, which answers password prompts" >&2
    echo "" >&2
    echo "  2. Configure sudo with passwordless NOPASSWD (quick fix):" >&2
    echo "     sudo visudo" >&2
    echo "     # Add line: $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
    echo "" >&2
  else
    # TTY/Console environment
    echo -e "${STY_YELLOW}Detected: Console/TTY (no graphical session)${STY_RST}" >&2
    echo "" >&2
    echo -e "${STY_CYAN}Recommended solutions:${STY_RST}" >&2
    echo "  1. Switch to a virtual terminal (Ctrl+Alt+F2-F6) and login as root" >&2
    echo "" >&2
    echo "  2. Use 'su' with root password:" >&2
    echo "     su -c 'pacman -S sudo'" >&2
    echo "     # Then configure visudo as below" >&2
    echo "" >&2
    echo "  3. Boot from Arch ISO and chroot:" >&2
    echo "     mount /dev/sdX1 /mnt" >&2
    echo "     arch-chroot /mnt" >&2
    echo "     pacman -S sudo" >&2
    echo "" >&2
  fi
  
  # Common configuration instructions
  echo -e "${STY_CYAN}After installing sudo, configure it:${STY_RST}" >&2
  echo "  sudo visudo" >&2
  echo "  # Option A: Allow wheel group (recommended)" >&2
  echo "  %wheel ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option B: Allow specific user" >&2
  echo "  $(whoami) ALL=(ALL) ALL" >&2
  echo "" >&2
  echo "  # Option C: Passwordless (not recommended for daily use)" >&2
  echo "  $(whoami) ALL=(ALL) NOPASSWD: ALL" >&2
}

# Use elevate() when USE_ELEVATE is set (graphical mode), otherwise use sudo
pkg_sudo() {
  # Priority 1: USE_ELEVATE environment variable (for custom elevation)
  if [[ "${USE_ELEVATE:-false}" == "true" ]] && type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # Priority 2: Try sudo first (standard method)
  if command -v sudo &>/dev/null; then
    # Try non-interactive first (already has cached credentials)
    if sudo -n true 2>/dev/null; then
      sudo "$@"
      return $?
    fi
    # Try interactive sudo - it will prompt for password if needed
    sudo "$@"
    return $?
  fi
  
  # Priority 3: Fallback to pkexec (polkit) - works in graphical environments
  # without requiring sudo configuration
  if command -v pkexec &>/dev/null; then
    # In graphical environments, polkit usually works
    # Don't test with -n as it may not work - just try it
    if pkexec --version &>/dev/null; then
      # Check if we have D-Bus session (needed for polkit in most cases)
      # OR if we're in a graphical environment
      if [[ -n "${DBUS_SESSION_BUS_ADDRESS}" ]] || _is_graphical_env; then
        pkexec "$@"
        return $?
      fi
    fi
  fi
  
  # Priority 4: Fallback to su (for TTY/console environments)
  # su requires the root password configured by the installed distribution.
  if command -v su &>/dev/null; then
    # Only use su in non-graphical environments (no D-Bus, no XDG)
    if ! _is_graphical_env && [[ -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
      # Try su with root password - this will prompt
      # The "-" makes it a login shell (loads profile)
      su - -c "$*"
      return $?
    fi
  fi
  
  # Priority 5: Fallback to elevate if not already tried
  if type elevate &>/dev/null; then
    elevate "$@"
    return $?
  fi
  
  # No privilege escalation method available
  _show_privilege_instructions "No privilege escalation method available (tried: sudo, pkexec, elevate)"
  return 1
}

#####################################################################################
# AUR Helpers
#####################################################################################

install-yay(){
  tui_info "Installing yay (AUR helper)..."

  # Clean up previous attempts
  rm -rf /tmp/buildyay

  # Sync databases and install base-devel
  if ! x pkg_sudo pacman -Sy --needed --noconfirm base-devel git; then
      log_error "Failed to install base-devel/git. Check your pacman mirrors."
      return 1
  fi

  # Clone yay-bin (faster than compiling yay)
  x git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay || return 1

  # Build and install
  x cd /tmp/buildyay
  if ! x makepkg -si --noconfirm; then
      log_error "Failed to build/install yay."
      x cd "${REPO_ROOT}"
      return 1
  fi

  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildyay
}

install-paru(){
  tui_info "Installing paru (AUR helper)..."
  x pkg_sudo pacman -S --needed --noconfirm base-devel git
  x git clone https://aur.archlinux.org/paru-bin.git /tmp/buildparu
  x cd /tmp/buildparu
  x makepkg -si --noconfirm
  x cd "${REPO_ROOT}"
  rm -rf /tmp/buildparu
}

ensure_aur_helper(){
  if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    return 0
  elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    return 0
  fi

  log_warning "No AUR helper found — installing yay..."
  install-yay
  AUR_HELPER="yay"
}

# NOTE: install-local-pkgbuild() removed — was dead code with --asdeps flag
# that would mark deps as orphan-eligible. Dependency installation now goes
# through install_pkgbuild_deps() in install-deps.sh (no --asdeps).

#####################################################################################
# Python Environment
#####################################################################################

install-python-packages(){
  tui_info "Setting up Python virtual environment..."

  local venv_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"

  if ! command -v uv &>/dev/null; then
    log_warning "uv not installed, skipping Python venv setup"
    return 0
  fi

  # Check for broken venv (e.g. after python update)
  if [[ -d "$venv_dir/bin" ]]; then
    if ! "$venv_dir/bin/python" --version &>/dev/null; then
      log_warning "Broken Python venv detected, recreating..."
      rm -rf "$venv_dir"
    fi
  fi

  if [[ ! -d "$venv_dir/bin" ]]; then
    x mkdir -p "$(dirname "$venv_dir")"
    x uv venv --prompt ii-venv "$venv_dir" -p 3.12 || uv venv --prompt ii-venv "$venv_dir" || {
      log_warning "Could not create Python venv"
      return 0
    }
  fi

  # Install required packages from requirements.txt
  # Try repo location first (during install), then target location (during doctor)
  local requirements_file="${REPO_ROOT}/sdata/uv/requirements.txt"
  if [[ ! -f "$requirements_file" ]]; then
    if declare -F get_runtime_shell_dir >/dev/null; then
      requirements_file="$(get_runtime_shell_dir)/sdata/uv/requirements.txt"
    else
      requirements_file="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir/sdata/uv/requirements.txt"
    fi
  fi

  if [[ -f "$requirements_file" ]]; then
    source "$venv_dir/bin/activate"
    x uv pip install -r "$requirements_file"
    deactivate
  else
    log_warning "requirements.txt not found"
  fi

  log_success "Python venv ready at $venv_dir"
}
