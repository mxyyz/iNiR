# Dependency mapping for iNiR (Arch only)
# This file maps generic dependency names to Arch package names
# Format: DEPS_<CATEGORY>_<GENERIC_NAME>="arch:pkg"
#
# Special values:
#   - "AUR:pkg" = Arch AUR package
#   - "-" = Not available/not needed
#
# shellcheck shell=bash

###############################################################################
# Package manager commands per distro
###############################################################################
declare -A PKG_INSTALL_CMD=(
    [arch]="pacman -S --needed"
)

declare -A PKG_UPDATE_CMD=(
    [arch]="pacman -Syu"
)

declare -A AUR_HELPER_CMD=(
    [arch]="yay -S --needed"
)

###############################################################################
# Critical dependencies (shell won't work without these)
###############################################################################

# Quickshell - the shell framework itself.
DEPS_CRITICAL_QUICKSHELL="arch:quickshell"

# Niri compositor
DEPS_CRITICAL_NIRI="arch:niri"

###############################################################################
# Qt6 dependencies
###############################################################################
DEPS_QT6_BASE="arch:qt6-base"
DEPS_QT6_DECLARATIVE="arch:qt6-declarative"
DEPS_QT6_SVG="arch:qt6-svg"
DEPS_QT6_WAYLAND="arch:qt6-wayland"
DEPS_QT6_5COMPAT="arch:qt6-5compat"
DEPS_QT6_MULTIMEDIA="arch:qt6-multimedia"
DEPS_QT6_IMAGEFORMATS="arch:qt6-imageformats"

###############################################################################
# Core system utilities
###############################################################################
DEPS_CORE_JQ="arch:jq"
DEPS_CORE_CURL="arch:curl"
DEPS_CORE_GIT="arch:git"
DEPS_CORE_RIPGREP="arch:ripgrep"
DEPS_CORE_RSYNC="arch:rsync"

###############################################################################
# Wayland utilities
###############################################################################
DEPS_WAYLAND_WLCLIPBOARD="arch:wl-clipboard"
DEPS_WAYLAND_CLIPHIST="arch:cliphist"
DEPS_WAYLAND_GRIM="arch:grim"
DEPS_WAYLAND_SLURP="arch:slurp"
DEPS_WAYLAND_SWAPPY="arch:swappy"
DEPS_WAYLAND_WFRECORDER="arch:wf-recorder"
DEPS_WAYLAND_WLSUNSET="arch:wlsunset"
DEPS_WAYLAND_SWAYIDLE="arch:swayidle"
DEPS_WAYLAND_SWAYLOCK="arch:swaylock"
DEPS_WAYLAND_XWAYLANDSATELLITE="arch:xwayland-satellite"

###############################################################################
# Audio stack
###############################################################################
DEPS_AUDIO_PIPEWIRE="arch:pipewire"
DEPS_AUDIO_PIPEWIRE_PULSE="arch:pipewire-pulse"
DEPS_AUDIO_WIREPLUMBER="arch:wireplumber"
DEPS_AUDIO_PLAYERCTL="arch:playerctl"
DEPS_AUDIO_PLASMA_BROWSER_INTEGRATION="arch:plasma-browser-integration"
DEPS_AUDIO_PAVUCONTROL="arch:pavucontrol"
DEPS_AUDIO_CAVA="arch:AUR:cava"
DEPS_AUDIO_EASYEFFECTS="arch:easyeffects"
DEPS_AUDIO_LSP_PLUGINS_LV2="arch:lsp-plugins-lv2"

###############################################################################
# Network
###############################################################################
DEPS_NET_NETWORKMANAGER="arch:networkmanager"
DEPS_NET_NMCONNECTIONEDITOR="arch:nm-connection-editor"
DEPS_NET_GNOMEKEYRING="arch:gnome-keyring"
DEPS_NET_BLUEMAN="arch:blueman"

###############################################################################
# Theming and appearance
###############################################################################
DEPS_THEME_QT6CT="arch:qt6ct"
DEPS_THEME_KVANTUM="arch:kvantum"
DEPS_THEME_BREEZE="arch:breeze"
DEPS_THEME_PLASMA_INTEGRATION="arch:plasma-integration"
DEPS_THEME_DARKLY="arch:AUR:darkly-bin"
DEPS_THEME_KDE_CLI_TOOLS="arch:kde-cli-tools"

###############################################################################
# Fonts (critical for UI)
###############################################################################
DEPS_FONT_MATERIAL_SYMBOLS="arch:ttf-material-symbols-variable"
DEPS_FONT_JETBRAINS_MONO="arch:ttf-jetbrains-mono-nerd"
DEPS_FONT_DEJAVU="arch:ttf-dejavu"
DEPS_FONT_TWEMOJI="arch:AUR:ttf-twemoji"

###############################################################################
# Development/Build tools
###############################################################################
DEPS_BUILD_CMAKE="arch:cmake"
DEPS_BUILD_MESON="arch:meson"
DEPS_BUILD_NINJA="arch:ninja"
DEPS_BUILD_GCC="arch:gcc"
DEPS_BUILD_RUST="arch:rust"
DEPS_BUILD_CARGO="arch:rust"

###############################################################################
# Miscellaneous tools
###############################################################################
DEPS_MISC_FISH="arch:fish"
DEPS_MISC_GUM="arch:gum"
DEPS_MISC_STARSHIP="arch:starship"
DEPS_MISC_LIBNOTIFY="arch:libnotify"
DEPS_MISC_IMAGEMAGICK="arch:imagemagick"
DEPS_MISC_FFMPEG="arch:ffmpeg"
DEPS_MISC_TESSERACT="arch:tesseract"
DEPS_MISC_LIBQALCULATE="arch:libqalculate"
DEPS_MISC_BRIGHTNESSCTL="arch:brightnessctl"
DEPS_MISC_NAUTILUS="arch:nautilus"
DEPS_MISC_FOOT="arch:foot"
DEPS_MISC_KITTY="arch:kitty"
DEPS_MISC_POLKIT="arch:polkit"
DEPS_MISC_UV="arch:uv"
DEPS_MISC_GOWALL="arch:AUR:gowall-bin"
DEPS_MISC_MISSIONCENTER="arch:mission-center"
DEPS_MISC_KCONFIG="arch:kconfig"

###############################################################################
# XDG Portals
###############################################################################
DEPS_PORTAL_BASE="arch:xdg-desktop-portal"
DEPS_PORTAL_GTK="arch:xdg-desktop-portal-gtk"
DEPS_PORTAL_GNOME="arch:xdg-desktop-portal-gnome"

###############################################################################
# Helper functions
###############################################################################

# Get package name for current distro
# Usage: get_pkg_name "DEPS_CORE_JQ"
get_pkg_name() {
    local dep_var="$1"
    local distro="${OS_GROUP_ID:-arch}"
    local dep_string="${!dep_var}"
    
    if [[ -z "$dep_string" ]]; then
        echo ""
        return 1
    fi
    
    # Parse the dependency string
    local pkg=""
    for entry in $dep_string; do
        local entry_distro="${entry%%:*}"
        local entry_pkg="${entry#*:}"
        
        if [[ "$entry_distro" == "$distro" ]]; then
            pkg="$entry_pkg"
            break
        fi
    done
    
    echo "$pkg"
}

# Check if package requires special handling
# Returns: "normal", "aur", or "unavailable"
get_pkg_type() {
    local pkg="$1"
    
    case "$pkg" in
        AUR:*) echo "aur" ;;
        -) echo "unavailable" ;;
        "") echo "unavailable" ;;
        *) echo "normal" ;;
    esac
}

# Extract actual package name from special format
# e.g., "AUR:quickshell-git" -> "quickshell-git"
get_pkg_value() {
    local pkg="$1"
    echo "${pkg#*:}"
}

# Get all packages of a category for current distro
# Usage: get_category_packages "CORE"
get_category_packages() {
    local category="$1"
    local distro="${OS_GROUP_ID:-arch}"
    local packages=()
    
    # Find all DEPS_<category>_* variables
    for var in $(compgen -v | grep "^DEPS_${category}_"); do
        local pkg=$(get_pkg_name "$var")
        if [[ -n "$pkg" && "$pkg" != "-" ]]; then
            packages+=("$pkg")
        fi
    done
    
    echo "${packages[@]}"
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Install a package using the appropriate method for current distro
install_package() {
    local pkg="$1"
    local pkg_type=$(get_pkg_type "$pkg")
    local pkg_value=$(get_pkg_value "$pkg")
    local distro="${OS_GROUP_ID:-arch}"
    
    case "$pkg_type" in
        normal)
            local cmd="${PKG_INSTALL_CMD[$distro]}"
            if [[ -n "$cmd" ]]; then
                sudo $cmd "$pkg_value"
            else
                echo "Unknown distro: $distro"
                return 1
            fi
            ;;
        aur)
            if [[ "$distro" == "arch" ]]; then
                local aur_cmd="${AUR_HELPER_CMD[$distro]}"
                $aur_cmd "$pkg_value"
            else
                echo "AUR packages only available on Arch"
                return 1
            fi
            ;;
        unavailable)
            echo "Package not available for $distro"
            return 1
            ;;
    esac
}
