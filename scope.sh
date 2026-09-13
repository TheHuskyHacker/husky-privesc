#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Husky Scope — OSCP exam IP environment manager.
#
# Sets up target IPs as environment variables so you never
# type an IP address again. Auto-detects your tun0.
# Saves config so it survives terminal restarts.
#
# Usage:
#   source scope.sh                     # load saved config
#   source scope.sh setup               # interactive setup
#   source scope.sh add box1 10.10.10.5 # add a target
#   source scope.sh show                # show all targets
#   source scope.sh serve               # start tool server
#
# IMPORTANT: Use 'source' (or '.') not 'bash' — otherwise
# the variables won't persist in your shell.
# ═══════════════════════════════════════════════════════════

SCOPE_FILE="${HOME}/.oscp_scope"

# Colors
RED='\033[91m'  GRN='\033[92m'  YEL='\033[93m'
CYN='\033[96m'  BLD='\033[1m'   DIM='\033[2m'   RST='\033[0m'

_banner() {
    echo -e "${CYN}"
    echo '    __  ____  _______ __ ____  __'
    echo '   / / / / / / / ___// //_/\ \ \/ /'
    echo '  / /_/ / / / /\__ \/ ,<    \  /'
    echo ' / __  / /_/ /___/ / /| |   / /'
    echo '/_/ /_/\____//____/_/ |_|  /_/'
    echo -e "${RED}"
    echo '    __  _____   ________ __ __________'
    echo '   / / / /   | / ____/ //_// ____/ __ \'
    echo '  / /_/ / /| |/ /   / ,<  / __/ / /_/ /'
    echo ' / __  / ___ / /___/ /| |/ /___/ _, _/'
    echo '/_/ /_/_/  |_\____/_/ |_/_____/_/ |_|'
    echo -e "${RST}"
    echo -e "    ${BLD}S C O P E   M A N A G E R${RST}"
    echo -e "    ${DIM}Set once. Use everywhere.${RST}"
    echo ""
}

# ═══════ Auto-detect attacker IP ═══════
_detect_ip() {
    local ip=""
    # Try tun0 first (VPN), then common interfaces
    for iface in tun0 tun1 eth0 ens33 ens160 wlan0; do
        ip=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    done
    echo ""
}

# ═══════ Save current scope to file ═══════
_save_scope() {
    {
        echo "# Husky Scope — saved $(date)"
        echo "# source this file to restore variables"
        echo ""
        [ -n "$ATTACKER" ] && echo "export ATTACKER='$ATTACKER'"
        [ -n "$IFACE" ] && echo "export IFACE='$IFACE'"
        [ -n "$TOOLS_DIR" ] && echo "export TOOLS_DIR='$TOOLS_DIR'"
        echo ""

        # Save all target variables
        [ -n "$T1" ] && echo "export T1='$T1'"
        [ -n "$T1_NAME" ] && echo "export T1_NAME='$T1_NAME'"
        [ -n "$T2" ] && echo "export T2='$T2'"
        [ -n "$T2_NAME" ] && echo "export T2_NAME='$T2_NAME'"
        [ -n "$T3" ] && echo "export T3='$T3'"
        [ -n "$T3_NAME" ] && echo "export T3_NAME='$T3_NAME'"
        [ -n "$AD_MS01" ] && echo "export AD_MS01='$AD_MS01'"
        [ -n "$AD_MS01_NAME" ] && echo "export AD_MS01_NAME='$AD_MS01_NAME'"
        [ -n "$AD_MS02" ] && echo "export AD_MS02='$AD_MS02'"
        [ -n "$AD_MS02_NAME" ] && echo "export AD_MS02_NAME='$AD_MS02_NAME'"
        [ -n "$AD_DC" ] && echo "export AD_DC='$AD_DC'"
        [ -n "$AD_DC_NAME" ] && echo "export AD_DC_NAME='$AD_DC_NAME'"
        [ -n "$AD_DOMAIN" ] && echo "export AD_DOMAIN='$AD_DOMAIN'"
        [ -n "$AD_USER" ] && echo "export AD_USER='$AD_USER'"
        [ -n "$AD_PASS" ] && echo "export AD_PASS='$AD_PASS'"
        echo ""

        # Save any custom targets
        if [ -n "$CUSTOM_TARGETS" ]; then
            echo "export CUSTOM_TARGETS='$CUSTOM_TARGETS'"
            for ct in $CUSTOM_TARGETS; do
                local var_ip="${ct}_IP"
                local var_name="${ct}_NAME"
                [ -n "${!var_ip}" ] && echo "export ${var_ip}='${!var_ip}'"
                [ -n "${!var_name}" ] && echo "export ${var_name}='${!var_name}'"
            done
        fi

    } > "$SCOPE_FILE"
    echo -e "  ${GRN}[+]${RST} Scope saved to ${SCOPE_FILE}"
}

# ═══════ Load scope from file ═══════
_load_scope() {
    if [ -f "$SCOPE_FILE" ]; then
        source "$SCOPE_FILE"
        # Refresh attacker IP (tun0 might have changed)
        local new_ip=$(_detect_ip)
        if [ -n "$new_ip" ] && [ "$new_ip" != "$ATTACKER" ]; then
            export ATTACKER="$new_ip"
            echo -e "  ${YEL}[*]${RST} Attacker IP refreshed: ${BLD}${ATTACKER}${RST}"
        fi
        return 0
    fi
    return 1
}

# ═══════ Show current scope ═══════
_show_scope() {
    echo ""
    echo -e "  ${BLD}${CYN}═══ Current Scope ═══${RST}"
    echo ""
    echo -e "  ${BLD}Attacker${RST}"
    echo -e "    ${GRN}ATTACKER${RST}  = ${BLD}${ATTACKER:-not set}${RST}  ${DIM}(\$ATTACKER)${RST}"
    [ -n "$IFACE" ] && echo -e "    ${DIM}Interface = ${IFACE}${RST}"
    [ -n "$TOOLS_DIR" ] && echo -e "    ${DIM}Tools     = ${TOOLS_DIR}${RST}"

    echo ""
    echo -e "  ${BLD}Standalone Targets${RST}"
    echo -e "    ${YEL}T1${RST}        = ${BLD}${T1:-not set}${RST}  ${DIM}${T1_NAME:+($T1_NAME)} (\$T1)${RST}"
    echo -e "    ${YEL}T2${RST}        = ${BLD}${T2:-not set}${RST}  ${DIM}${T2_NAME:+($T2_NAME)} (\$T2)${RST}"
    echo -e "    ${YEL}T3${RST}        = ${BLD}${T3:-not set}${RST}  ${DIM}${T3_NAME:+($T3_NAME)} (\$T3)${RST}"

    echo ""
    echo -e "  ${BLD}Active Directory Set${RST}"
    echo -e "    ${RED}AD_MS01${RST}   = ${BLD}${AD_MS01:-not set}${RST}  ${DIM}${AD_MS01_NAME:+($AD_MS01_NAME)} (\$AD_MS01)${RST}"
    echo -e "    ${RED}AD_MS02${RST}   = ${BLD}${AD_MS02:-not set}${RST}  ${DIM}${AD_MS02_NAME:+($AD_MS02_NAME)} (\$AD_MS02)${RST}"
    echo -e "    ${RED}AD_DC${RST}     = ${BLD}${AD_DC:-not set}${RST}  ${DIM}${AD_DC_NAME:+($AD_DC_NAME)} (\$AD_DC)${RST}"
    [ -n "$AD_DOMAIN" ] && echo -e "    ${DIM}Domain    = ${AD_DOMAIN} (\$AD_DOMAIN)${RST}"
    [ -n "$AD_USER" ] && echo -e "    ${DIM}User      = ${AD_USER} (\$AD_USER)${RST}"
    [ -n "$AD_PASS" ] && echo -e "    ${DIM}Pass      = ${AD_PASS} (\$AD_PASS)${RST}"

    # Custom targets
    if [ -n "$CUSTOM_TARGETS" ]; then
        echo ""
        echo -e "  ${BLD}Custom Targets${RST}"
        for ct in $CUSTOM_TARGETS; do
            local var_ip="${ct}_IP"
            local var_name="${ct}_NAME"
            echo -e "    ${CYN}${ct}${RST} = ${BLD}${!var_ip:-not set}${RST}  ${DIM}${!var_name:+(${!var_name})} (\$${ct}_IP)${RST}"
        done
    fi

    echo ""
    echo -e "  ${DIM}─────────────────────────────────────${RST}"
    echo -e "  ${BLD}Usage examples:${RST}"
    echo -e "    ${CYN}nmap -sCV \$T1${RST}"
    echo -e "    ${CYN}evil-winrm -i \$AD_DC -u \$AD_USER -p \$AD_PASS${RST}"
    echo -e "    ${CYN}huskyrecon \$T1 -o ./recon/t1${RST}"
    echo -e "    ${CYN}revshell -l bash -i \$ATTACKER -p 4444${RST}"
    echo -e "    ${CYN}impacket-secretsdump \"\$AD_DOMAIN/\$AD_USER:\$AD_PASS\"@\$AD_DC${RST}"
    echo ""
}

# ═══════ Interactive setup ═══════
_setup() {
    _banner

    echo -e "  ${BLD}${CYN}═══ Exam Scope Setup ═══${RST}"
    echo ""

    # Attacker IP
    local detected=$(_detect_ip)
    if [ -n "$detected" ]; then
        echo -e "  ${GRN}[+]${RST} Auto-detected attacker IP: ${BLD}${detected}${RST}"
        export ATTACKER="$detected"
        # Detect interface name
        for iface in tun0 tun1 eth0 ens33 ens160 wlan0; do
            local iface_ip=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
            if [ "$iface_ip" = "$detected" ]; then
                export IFACE="$iface"
                break
            fi
        done
    else
        echo -ne "  Attacker IP: "
        read -r ATTACKER
        export ATTACKER
    fi

    # Tools directory
    export TOOLS_DIR="${HOME}/oscp-tools"
    echo -e "  ${DIM}Tools directory: ${TOOLS_DIR}${RST}"

    # Standalone targets
    echo ""
    echo -e "  ${BLD}Standalone Targets${RST} ${DIM}(press Enter to skip)${RST}"

    echo -ne "  Standalone 1 IP: "
    read -r T1_input
    if [ -n "$T1_input" ]; then
        export T1="$T1_input"
        echo -ne "  Standalone 1 name (e.g. Box1): "
        read -r T1_NAME_input
        export T1_NAME="${T1_NAME_input:-Standalone1}"
    fi

    echo -ne "  Standalone 2 IP: "
    read -r T2_input
    if [ -n "$T2_input" ]; then
        export T2="$T2_input"
        echo -ne "  Standalone 2 name: "
        read -r T2_NAME_input
        export T2_NAME="${T2_NAME_input:-Standalone2}"
    fi

    echo -ne "  Standalone 3 IP: "
    read -r T3_input
    if [ -n "$T3_input" ]; then
        export T3="$T3_input"
        echo -ne "  Standalone 3 name: "
        read -r T3_NAME_input
        export T3_NAME="${T3_NAME_input:-Standalone3}"
    fi

    # AD set
    echo ""
    echo -e "  ${BLD}Active Directory Set${RST} ${DIM}(press Enter to skip)${RST}"

    echo -ne "  AD Machine 1 (MS01) IP: "
    read -r AD_MS01_input
    if [ -n "$AD_MS01_input" ]; then
        export AD_MS01="$AD_MS01_input"
        echo -ne "  MS01 hostname: "
        read -r AD_MS01_NAME_input
        export AD_MS01_NAME="${AD_MS01_NAME_input:-MS01}"
    fi

    echo -ne "  AD Machine 2 (MS02) IP: "
    read -r AD_MS02_input
    if [ -n "$AD_MS02_input" ]; then
        export AD_MS02="$AD_MS02_input"
        echo -ne "  MS02 hostname: "
        read -r AD_MS02_NAME_input
        export AD_MS02_NAME="${AD_MS02_NAME_input:-MS02}"
    fi

    echo -ne "  Domain Controller (DC) IP: "
    read -r AD_DC_input
    if [ -n "$AD_DC_input" ]; then
        export AD_DC="$AD_DC_input"
        echo -ne "  DC hostname: "
        read -r AD_DC_NAME_input
        export AD_DC_NAME="${AD_DC_NAME_input:-DC01}"
    fi

    echo -ne "  AD Domain (e.g. corp.local): "
    read -r AD_DOMAIN_input
    [ -n "$AD_DOMAIN_input" ] && export AD_DOMAIN="$AD_DOMAIN_input"

    echo -ne "  AD Starting user: "
    read -r AD_USER_input
    [ -n "$AD_USER_input" ] && export AD_USER="$AD_USER_input"

    echo -ne "  AD Starting password: "
    read -r AD_PASS_input
    [ -n "$AD_PASS_input" ] && export AD_PASS="$AD_PASS_input"

    echo ""
    _save_scope
    _show_scope

    # Add to report
    echo -e "  ${DIM}Tip: Add to your report now:${RST}"
    [ -n "$T1" ] && echo -e "    ${CYN}report add '${T1_NAME}' $T1${RST}"
    [ -n "$T2" ] && echo -e "    ${CYN}report add '${T2_NAME}' $T2${RST}"
    [ -n "$T3" ] && echo -e "    ${CYN}report add '${T3_NAME}' $T3${RST}"
    [ -n "$AD_MS01" ] && echo -e "    ${CYN}report add '${AD_MS01_NAME}' $AD_MS01 --os Windows --domain $AD_DOMAIN${RST}"
    [ -n "$AD_MS02" ] && echo -e "    ${CYN}report add '${AD_MS02_NAME}' $AD_MS02 --os Windows --domain $AD_DOMAIN${RST}"
    [ -n "$AD_DC" ] && echo -e "    ${CYN}report add '${AD_DC_NAME}' $AD_DC --os Windows --points 40 --domain $AD_DOMAIN${RST}"
    echo ""
}

# ═══════ Add a single target ═══════
_add_target() {
    local var_name="$1"
    local ip="$2"
    local label="$3"

    if [ -z "$var_name" ] || [ -z "$ip" ]; then
        echo -e "  ${RED}[!]${RST} Usage: source scope.sh add <VAR_NAME> <IP> [label]"
        echo -e "  ${DIM}    Example: source scope.sh add T1 10.10.10.5 WebBox${RST}"
        echo -e "  ${DIM}    Example: source scope.sh add AD_DC 10.10.10.100 DC01${RST}"
        echo -e "  ${DIM}    Example: source scope.sh add PIVOT 172.16.0.10 InternalHost${RST}"
        return 1
    fi

    # Handle known variable names
    case "$var_name" in
        T1|T2|T3|AD_MS01|AD_MS02|AD_DC)
            export "${var_name}=${ip}"
            [ -n "$label" ] && export "${var_name}_NAME=${label}"
            echo -e "  ${GRN}[+]${RST} Set \$${var_name} = ${BLD}${ip}${RST} ${DIM}${label:+($label)}${RST}"
            ;;
        AD_DOMAIN|AD_USER|AD_PASS)
            export "${var_name}=${ip}"
            echo -e "  ${GRN}[+]${RST} Set \$${var_name} = ${BLD}${ip}${RST}"
            ;;
        *)
            # Custom target
            local upper_name=$(echo "$var_name" | tr '[:lower:]' '[:upper:]')
            export "${upper_name}_IP=${ip}"
            [ -n "$label" ] && export "${upper_name}_NAME=${label}"
            export CUSTOM_TARGETS="${CUSTOM_TARGETS} ${upper_name}"
            echo -e "  ${GRN}[+]${RST} Set \$${upper_name}_IP = ${BLD}${ip}${RST} ${DIM}${label:+($label)}${RST}"
            ;;
    esac

    _save_scope
}

# ═══════ Refresh attacker IP ═══════
_refresh() {
    local new_ip=$(_detect_ip)
    if [ -n "$new_ip" ]; then
        export ATTACKER="$new_ip"
        echo -e "  ${GRN}[+]${RST} Attacker IP: ${BLD}${ATTACKER}${RST}"
        _save_scope
    else
        echo -e "  ${RED}[!]${RST} Could not detect IP — is VPN connected?"
    fi
}

# ═══════ Start tool server ═══════
_serve() {
    local tools="${TOOLS_DIR:-$HOME/oscp-tools}"
    if [ -d "$tools" ]; then
        echo -e "  ${GRN}[+]${RST} Serving tools from ${BLD}${tools}${RST} on port 80"
        echo -e "  ${DIM}    Ctrl+C to stop${RST}"
        cd "$tools" && python3 -m http.server 80
    else
        echo -e "  ${RED}[!]${RST} Tools directory not found: $tools"
        echo -e "  ${DIM}    Run toolbox.sh first${RST}"
    fi
}

# ═══════ Add to /etc/hosts ═══════
_hosts() {
    echo -e "\n  ${BLD}Add to /etc/hosts:${RST}"
    echo ""
    [ -n "$T1" ] && echo "  $T1    ${T1_NAME:-standalone1}"
    [ -n "$T2" ] && echo "  $T2    ${T2_NAME:-standalone2}"
    [ -n "$T3" ] && echo "  $T3    ${T3_NAME:-standalone3}"
    [ -n "$AD_MS01" ] && echo "  $AD_MS01    ${AD_MS01_NAME:-ms01}.${AD_DOMAIN:-domain.local} ${AD_MS01_NAME:-ms01}"
    [ -n "$AD_MS02" ] && echo "  $AD_MS02    ${AD_MS02_NAME:-ms02}.${AD_DOMAIN:-domain.local} ${AD_MS02_NAME:-ms02}"
    [ -n "$AD_DC" ] && echo "  $AD_DC    ${AD_DC_NAME:-dc01}.${AD_DOMAIN:-domain.local} ${AD_DC_NAME:-dc01}"
    echo ""
    echo -e "  ${DIM}Copy and paste into: sudo nano /etc/hosts${RST}"
    echo ""
}

# ═══════ Quick nmap on all targets ═══════
_scanall() {
    echo -e "  ${CYN}[*]${RST} Quick nmap on all targets..."
    for var in T1 T2 T3 AD_MS01 AD_MS02 AD_DC; do
        local ip="${!var}"
        local name_var="${var}_NAME"
        local name="${!name_var}"
        if [ -n "$ip" ]; then
            echo -e "\n  ${BLD}${name:-$var}${RST} (${ip})"
            nmap -sC -sV --open -T4 "$ip" -oN "./recon/${var}_quick.txt" 2>/dev/null | grep "open" | head -15
        fi
    done
}

# ═══════ Reset scope ═══════
_reset() {
    echo -ne "  ${YEL}[!]${RST} Reset all targets? (y/N): "
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        unset T1 T1_NAME T2 T2_NAME T3 T3_NAME
        unset AD_MS01 AD_MS01_NAME AD_MS02 AD_MS02_NAME AD_DC AD_DC_NAME
        unset AD_DOMAIN AD_USER AD_PASS
        unset CUSTOM_TARGETS
        rm -f "$SCOPE_FILE"
        # Refresh attacker IP
        export ATTACKER=$(_detect_ip)
        echo -e "  ${GRN}[+]${RST} Scope reset. Attacker IP kept: ${ATTACKER}"
    fi
}

# ═══════ Help ═══════
_help() {
    echo -e "
  ${BLD}Usage:${RST} source scope.sh <command>

  ${BLD}Commands:${RST}
    ${CYN}setup${RST}                          Interactive exam setup
    ${CYN}show${RST}                           Show current scope & variables
    ${CYN}add${RST} <VAR> <IP> [label]         Add/update a target
    ${CYN}refresh${RST}                        Refresh attacker IP from tun0
    ${CYN}hosts${RST}                          Generate /etc/hosts entries
    ${CYN}serve${RST}                          Start HTTP tool server
    ${CYN}scanall${RST}                        Quick nmap all targets
    ${CYN}reset${RST}                          Clear all targets
    ${CYN}help${RST}                           Show this help

  ${BLD}Variables set:${RST}
    \$ATTACKER          Your attacker IP (auto-detected)
    \$T1 \$T2 \$T3       Standalone target IPs
    \$AD_MS01 \$AD_MS02  AD member server IPs
    \$AD_DC             Domain Controller IP
    \$AD_DOMAIN         AD domain name
    \$AD_USER           AD starting username
    \$AD_PASS           AD starting password

  ${BLD}Examples:${RST}
    source scope.sh setup
    source scope.sh add T1 10.10.10.5 WebBox
    source scope.sh add PIVOT 172.16.0.10 InternalPivot
    nmap -sCV \$T1
    evil-winrm -i \$AD_DC -u \$AD_USER -p \$AD_PASS
    huskyrecon \$T2 -o ./recon/t2
    revshell -l bash -i \$ATTACKER -p 4444
"
}

# ═══════ Main dispatcher ═══════
case "${1:-}" in
    setup)    _setup ;;
    show)     _banner; _show_scope ;;
    add)      _add_target "$2" "$3" "$4" ;;
    refresh)  _refresh ;;
    hosts)    _hosts ;;
    serve)    _serve ;;
    scanall)  _scanall ;;
    reset)    _reset ;;
    help|-h)  _banner; _help ;;
    *)
        # Default: load saved scope silently, or show help
        if _load_scope; then
            echo -e "  ${GRN}[+]${RST} Scope loaded — ${BLD}\$ATTACKER=${ATTACKER}${RST}"
            [ -n "$T1" ] && echo -e "  ${DIM}    \$T1=${T1} \$T2=${T2:-—} \$T3=${T3:-—} \$AD_DC=${AD_DC:-—}${RST}"
            echo -e "  ${DIM}    'source scope.sh show' for full view${RST}"
        else
            _banner
            _help
        fi
        ;;
esac
