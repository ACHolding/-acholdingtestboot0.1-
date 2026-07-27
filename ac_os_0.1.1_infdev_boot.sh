#!/usr/bin/env bash
#
# AC OS 0.1.1 InfDev — Darwin OS rebrand installer
# [c] 1999-2026 ACHolding
#
# Rebrands the whole Darwin environment as AC OS 0.1.1 InfDev:
#   · computer name / hostname
#   · login motd
#   · shell prompt + session banner
#   · ac-os-info / acos / version commands
#
# Install:
#   chmod +x ac_os_0.1.1_infdev_boot.sh
#   ./ac_os_0.1.1_infdev_boot.sh
#
# Remove:
#   ./ac_os_0.1.1_infdev_boot.sh --restore
#

set -euo pipefail

OS_NAME="AC OS"
OS_VERSION="0.1.1"
OS_EDITION="InfDev"
FULL_NAME="${OS_NAME} ${OS_VERSION} ${OS_EDITION}"
COPYRIGHT="[c] 1999-2026 ACHolding"
HOST_LABEL="AC-OS-0-1-1-InfDev"
DISPLAY_NAME="AC OS 0.1.1 InfDev"

ZSHRC="${HOME}/.zshrc"
LOCAL_BIN="${HOME}/.local/bin"
INFO_COMMAND="${LOCAL_BIN}/ac-os-info"
BACKUP_DIR="${HOME}/.ac-os-backup"

BLOCK_START="# >>> AC OS 0.1.1 INFDEV >>>"
BLOCK_END="# <<< AC OS 0.1.1 INFDEV <<<"

# Also strip any older AC OS InfDev branding blocks on upgrade.
LEGACY_BLOCKS=(
    "# >>> AC OS 0.1 INFDEV >>>|# <<< AC OS 0.1 INFDEV <<<"
    "# >>> AC OS 0.1.1 INFDEV >>>|# <<< AC OS 0.1.1 INFDEV <<<"
)

require_darwin() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "${FULL_NAME} requires a Darwin host."
        echo "Current kernel: $(uname -s)"
        exit 1
    fi
}

remove_block() {
    local start="$1" end="$2"
    [[ -f "$ZSHRC" ]] || return 0

    awk -v start="$start" -v end="$end" '
        $0 == start { removing = 1; next }
        $0 == end   { removing = 0; next }
        !removing   { print }
    ' "$ZSHRC" > "${ZSHRC}.acos.tmp"

    mv "${ZSHRC}.acos.tmp" "$ZSHRC"
}

remove_all_acos_blocks() {
    local pair start end
    for pair in "${LEGACY_BLOCKS[@]}"; do
        start="${pair%%|*}"
        end="${pair##*|}"
        remove_block "$start" "$end"
    done
}

backup_config() {
    mkdir -p "$BACKUP_DIR"

    if [[ -f "$ZSHRC" && ! -f "${BACKUP_DIR}/zshrc.original" ]]; then
        cp "$ZSHRC" "${BACKUP_DIR}/zshrc.original"
    fi

    # Snapshot current identity once so --restore can put it back.
    if [[ ! -f "${BACKUP_DIR}/identity.txt" ]]; then
        {
            echo "ComputerName=$(scutil --get ComputerName 2>/dev/null || true)"
            echo "LocalHostName=$(scutil --get LocalHostName 2>/dev/null || true)"
            echo "HostName=$(scutil --get HostName 2>/dev/null || true)"
        } > "${BACKUP_DIR}/identity.txt"
    fi

    if [[ -f /etc/motd && ! -f "${BACKUP_DIR}/motd.original" ]]; then
        cp /etc/motd "${BACKUP_DIR}/motd.original" 2>/dev/null || true
    fi
}

create_info_command() {
    mkdir -p "$LOCAL_BIN"

    cat > "$INFO_COMMAND" <<EOF
#!/bin/bash
# ${FULL_NAME}  ${COPYRIGHT}

printf '\\033[1;36m${DISPLAY_NAME}\\033[0m\\n'
printf 'Edition:      Infinite Development\\n'
printf 'Version:      ${OS_VERSION}\\n'
printf 'Copyright:    ${COPYRIGHT}\\n'
printf 'Foundation:   Darwin\\n'
printf 'Kernel:       %s\\n' "\$(uname -s)"
printf 'Kernel build: %s\\n' "\$(uname -r)"
printf 'Architecture: %s\\n' "\$(uname -m)"
printf 'Machine:      %s\\n' "\$(hostname)"
printf 'Status:       InfDev — all systems operational\\n'
EOF

    chmod +x "$INFO_COMMAND"

    ln -sf "$INFO_COMMAND" "${LOCAL_BIN}/acos"
    ln -sf "$INFO_COMMAND" "${LOCAL_BIN}/ac-version"
    ln -sf "$INFO_COMMAND" "${LOCAL_BIN}/system-version"
    ln -sf "$INFO_COMMAND" "${LOCAL_BIN}/ac-os"
}

configure_terminal() {
    touch "$ZSHRC"
    remove_all_acos_blocks

    cat >> "$ZSHRC" <<EOF

${BLOCK_START}
# ${FULL_NAME}  ${COPYRIGHT}
export AC_OS_NAME="${OS_NAME}"
export AC_OS_VERSION="${OS_VERSION}"
export AC_OS_EDITION="${OS_EDITION}"
export AC_OS_FULL="${FULL_NAME}"
export AC_OS_COPYRIGHT="${COPYRIGHT}"
export PATH="\$HOME/.local/bin:\$PATH"

autoload -Uz colors && colors

# Window / tab title.
printf '\\033]0;${DISPLAY_NAME}  ${COPYRIGHT}\\007'

# System prompt.
PROMPT='%F{cyan}[${DISPLAY_NAME}]%f %F{blue}%n@%m%f %F{cyan}%~%f
%F{blue}❯%f '

# Boot banner once per interactive session.
if [[ -o interactive && -z "\${AC_OS_BANNER_SHOWN:-}" ]]; then
    export AC_OS_BANNER_SHOWN=1
    clear

    printf '\\033[1;36m'
    printf '╔══════════════════════════════════════════════════╗\\n'
    printf '║              AC OS  0.1.1  InfDev                ║\\n'
    printf '║           Infinite Development Build             ║\\n'
    printf '║         [c] 1999-2026  ACHolding                 ║\\n'
    printf '╚══════════════════════════════════════════════════╝\\n'
    printf '\\033[0m'

    printf 'Foundation: Darwin\\n'
    printf 'Kernel:     %s %s\\n' "\$(uname -s)" "\$(uname -r)"
    printf 'Machine:    %s\\n' "\$(uname -m)"
    printf 'Status:     All systems operational\\n\\n'
fi

alias neofetch='ac-os-info'
alias fastfetch='ac-os-info'
alias sysinfo='ac-os-info'
alias about='ac-os-info'
alias version='ac-os-info'
alias ac-clear='clear; ac-os-info'
alias ac-update='echo "${FULL_NAME} is continuously developing. ${COPYRIGHT}"'
${BLOCK_END}
EOF
}

configure_hostname() {
    echo "Setting computer identity to ${DISPLAY_NAME}..."
    echo "Administrator authentication may be requested."

    sudo scutil --set ComputerName "${DISPLAY_NAME}"
    sudo scutil --set LocalHostName "${HOST_LABEL}"
    sudo scutil --set HostName "${HOST_LABEL}"
}

create_system_banner() {
    echo "Installing the ${DISPLAY_NAME} login banner..."

    sudo mkdir -p /etc
    sudo tee /etc/motd >/dev/null <<EOF
================================================
            AC OS 0.1.1 InfDev
       Infinite Development Build
         [c] 1999-2026 ACHolding
            Darwin Foundation
================================================
EOF
}

restore_identity() {
    [[ -f "${BACKUP_DIR}/identity.txt" ]] || return 0

    local cn lhn hn
    cn="$(awk -F= '/^ComputerName=/{print substr($0,index($0,"=")+1)}' "${BACKUP_DIR}/identity.txt")"
    lhn="$(awk -F= '/^LocalHostName=/{print substr($0,index($0,"=")+1)}' "${BACKUP_DIR}/identity.txt")"
    hn="$(awk -F= '/^HostName=/{print substr($0,index($0,"=")+1)}' "${BACKUP_DIR}/identity.txt")"

    echo "Restoring computer identity (sudo may be required)..."
    [[ -n "$cn"  ]] && sudo scutil --set ComputerName "$cn" || true
    [[ -n "$lhn" ]] && sudo scutil --set LocalHostName "$lhn" || true
    [[ -n "$hn"  ]] && sudo scutil --set HostName "$hn" || true
}

restore() {
    echo "Removing ${FULL_NAME} OS branding..."

    if [[ -f "${BACKUP_DIR}/zshrc.original" ]]; then
        cp "${BACKUP_DIR}/zshrc.original" "$ZSHRC"
    else
        remove_all_acos_blocks
    fi

    rm -f \
        "$INFO_COMMAND" \
        "${LOCAL_BIN}/acos" \
        "${LOCAL_BIN}/ac-version" \
        "${LOCAL_BIN}/system-version" \
        "${LOCAL_BIN}/ac-os"

    if [[ -f "${BACKUP_DIR}/motd.original" ]]; then
        sudo cp "${BACKUP_DIR}/motd.original" /etc/motd 2>/dev/null || true
    else
        sudo rm -f /etc/motd 2>/dev/null || true
    fi

    restore_identity

    echo "${FULL_NAME} branding removed."
    echo "Restart Terminal or run: exec zsh"
}

show_usage() {
    cat <<EOF
${FULL_NAME}  ${COPYRIGHT}

Rebrand this Darwin machine as ${DISPLAY_NAME}.

  ./ac_os_0.1.1_infdev_boot.sh           install OS branding
  ./ac_os_0.1.1_infdev_boot.sh --restore remove branding
  ./ac_os_0.1.1_infdev_boot.sh --info    show version
  ./ac_os_0.1.1_infdev_boot.sh --help    this help
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--version|--info|info|about)
            echo "${FULL_NAME}  ${COPYRIGHT}"
            exit 0
            ;;
        --restore)
            require_darwin
            restore
            exit 0
            ;;
        ""|--install|--boot)
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_usage >&2
            exit 1
            ;;
    esac

    require_darwin

    echo "══════════════════════════════════════════════════"
    echo " ${FULL_NAME}"
    echo " ${COPYRIGHT}"
    echo " Darwin OS rebrand"
    echo "══════════════════════════════════════════════════"
    echo

    backup_config
    create_info_command
    configure_terminal
    configure_hostname
    create_system_banner

    echo
    echo "${FULL_NAME} branding installed."
    echo "Computer name → ${DISPLAY_NAME}"
    echo "Hostname      → ${HOST_LABEL}"
    echo
    echo "Restart Terminal or run:"
    echo
    echo "  exec zsh"
}

main "$@"
