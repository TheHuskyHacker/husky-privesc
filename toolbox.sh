#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Husky Tool Grabber — downloads all PEN-200 privesc & AD
# tools for Linux and Windows targets. Run once on your
# attacker box before the exam.
#
# Creates: ~/oscp-tools/ with organized subdirectories
#
# Usage: chmod +x toolbox.sh && ./toolbox.sh
#        or: ./toolbox.sh /custom/path
# ═══════════════════════════════════════════════════════════

TOOLS_DIR="${1:-$HOME/oscp-tools}"

RED='\033[91m' GRN='\033[92m' YEL='\033[93m'
CYN='\033[96m' BLD='\033[1m'  DIM='\033[2m'  RST='\033[0m'

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
echo -e "    ${BLD}T O O L   G R A B B E R${RST}"
echo -e "    ${DIM}Every tool. One script. Exam ready.${RST}"
echo ""
echo -e "  ${BLD}Target:${RST} $TOOLS_DIR"
echo ""

DOWNLOADED=0; FAILED=0; SKIPPED=0

grab() {
    local url="$1" dest="$2" desc="$3"
    local filename=$(basename "$dest")
    if [ -f "$dest" ]; then
        echo -e "  ${DIM}[*]${RST} ${filename} — already have it"
        ((SKIPPED++)); return 0
    fi
    echo -ne "  ${DIM}[*]${RST} ${desc:-$filename}..."
    if curl -sL --fail --connect-timeout 10 --max-time 120 -o "$dest" "$url" 2>/dev/null; then
        local size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null || echo 0)
        if [ "${size:-0}" -gt 100 ] 2>/dev/null; then
            echo -e " ${GRN}OK${RST} (${size} bytes)"
            ((DOWNLOADED++))
        else
            echo -e " ${RED}EMPTY${RST}"; rm -f "$dest"; ((FAILED++))
        fi
    else
        echo -e " ${RED}FAIL${RST}"; rm -f "$dest"; ((FAILED++))
    fi
}

section() { echo -e "\n  ${BLD}${CYN}═══ $1 ═══${RST}"; }

mkdir -p "$TOOLS_DIR"/{linux,windows/potatoes,windows/sharp,ad,web,pivoting,misc}

# ═══════ LINUX PRIVESC ═══════
section "Linux Privilege Escalation"
grab "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" "$TOOLS_DIR/linux/linpeas.sh" "linPEAS"
grab "https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh" "$TOOLS_DIR/linux/linux-exploit-suggester.sh" "linux-exploit-suggester"
grab "https://raw.githubusercontent.com/jondonas/linux-exploit-suggester-2/master/linux-exploit-suggester-2.pl" "$TOOLS_DIR/linux/linux-exploit-suggester-2.pl" "linux-exploit-suggester-2"
grab "https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh" "$TOOLS_DIR/linux/LinEnum.sh" "LinEnum"
grab "https://raw.githubusercontent.com/diego-treitos/linux-smart-enumeration/master/lse.sh" "$TOOLS_DIR/linux/lse.sh" "Linux Smart Enumeration"
grab "https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64" "$TOOLS_DIR/linux/pspy64" "pspy64"
grab "https://github.com/DominicBreuker/pspy/releases/latest/download/pspy32" "$TOOLS_DIR/linux/pspy32" "pspy32"
grab "https://raw.githubusercontent.com/joeammond/CVE-2021-4034/main/CVE-2021-4034.py" "$TOOLS_DIR/linux/pwnkit.py" "PwnKit CVE-2021-4034"
grab "https://raw.githubusercontent.com/sleventyeleven/linuxprivchecker/master/linuxprivchecker.py" "$TOOLS_DIR/linux/linuxprivchecker.py" "linuxprivchecker"
grab "https://raw.githubusercontent.com/pentestmonkey/unix-privesc-check/master/unix-privesc-check" "$TOOLS_DIR/linux/unix-privesc-check.sh" "unix-privesc-check"

# ═══════ WINDOWS PRIVESC ═══════
section "Windows Privilege Escalation"
grab "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe" "$TOOLS_DIR/windows/winPEASx64.exe" "winPEAS x64"
grab "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx86.exe" "$TOOLS_DIR/windows/winPEASx86.exe" "winPEAS x86"
grab "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEAS.bat" "$TOOLS_DIR/windows/winPEAS.bat" "winPEAS bat"
grab "https://github.com/BeichenDream/GodPotato/releases/latest/download/GodPotato-NET4.exe" "$TOOLS_DIR/windows/potatoes/GodPotato-NET4.exe" "GodPotato NET4"
grab "https://github.com/BeichenDream/GodPotato/releases/latest/download/GodPotato-NET2.exe" "$TOOLS_DIR/windows/potatoes/GodPotato-NET2.exe" "GodPotato NET2"
grab "https://github.com/itm4n/PrintSpoofer/releases/latest/download/PrintSpoofer64.exe" "$TOOLS_DIR/windows/potatoes/PrintSpoofer64.exe" "PrintSpoofer x64"
grab "https://github.com/itm4n/PrintSpoofer/releases/latest/download/PrintSpoofer32.exe" "$TOOLS_DIR/windows/potatoes/PrintSpoofer32.exe" "PrintSpoofer x32"
grab "https://github.com/tylerdotrar/SigmaPotato/releases/latest/download/SigmaPotato.exe" "$TOOLS_DIR/windows/potatoes/SigmaPotato.exe" "SigmaPotato"
grab "https://github.com/ohpe/juicy-potato/releases/latest/download/JuicyPotato.exe" "$TOOLS_DIR/windows/potatoes/JuicyPotato.exe" "JuicyPotato"
grab "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1" "$TOOLS_DIR/windows/PowerUp.ps1" "PowerUp.ps1"
grab "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/SharpUp.exe" "$TOOLS_DIR/windows/sharp/SharpUp.exe" "SharpUp"
grab "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Seatbelt.exe" "$TOOLS_DIR/windows/sharp/Seatbelt.exe" "Seatbelt"
grab "https://github.com/itm4n/FullPowers/releases/latest/download/FullPowers.exe" "$TOOLS_DIR/windows/FullPowers.exe" "FullPowers"
grab "https://github.com/antonioCoco/RunasCs/releases/latest/download/RunasCs.zip" "$TOOLS_DIR/windows/RunasCs.zip" "RunasCs"
grab "https://github.com/int0x33/nc.exe/raw/master/nc64.exe" "$TOOLS_DIR/windows/nc64.exe" "nc64.exe"
grab "https://github.com/int0x33/nc.exe/raw/master/nc.exe" "$TOOLS_DIR/windows/nc.exe" "nc.exe (32-bit)"

# ═══════ ACTIVE DIRECTORY ═══════
section "Active Directory"
grab "https://github.com/gentilkiwi/mimikatz/releases/latest/download/mimikatz_trunk.zip" "$TOOLS_DIR/ad/mimikatz_trunk.zip" "Mimikatz"
grab "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe" "$TOOLS_DIR/ad/Rubeus.exe" "Rubeus"
grab "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Certify.exe" "$TOOLS_DIR/ad/Certify.exe" "Certify"
grab "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Whisker.exe" "$TOOLS_DIR/ad/Whisker.exe" "Whisker"
grab "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Recon/PowerView.ps1" "$TOOLS_DIR/ad/PowerView.ps1" "PowerView.ps1"
grab "https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1" "$TOOLS_DIR/ad/Invoke-PowerShellTcp.ps1" "Nishang Invoke-PowerShellTcp"
grab "https://github.com/Kevin-Robertson/Inveigh/releases/latest/download/Inveigh.exe" "$TOOLS_DIR/ad/Inveigh.exe" "Inveigh"
grab "https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64" "$TOOLS_DIR/ad/kerbrute" "kerbrute"
grab "https://raw.githubusercontent.com/Hackndo/pyGPOAbuse/main/pygpoabuse.py" "$TOOLS_DIR/ad/pygpoabuse.py" "pyGPOAbuse"
grab "https://github.com/AlessandroZ/LaZagne/releases/latest/download/LaZagne.exe" "$TOOLS_DIR/ad/LaZagne.exe" "LaZagne"

# ═══════ PIVOTING ═══════
section "Pivoting"
grab "https://github.com/andrew-d/static-binaries/raw/master/binaries/linux/x86_64/socat" "$TOOLS_DIR/pivoting/socat_static" "socat (static Linux)"
grab "https://github.com/andrew-d/static-binaries/raw/master/binaries/linux/x86_64/nmap" "$TOOLS_DIR/pivoting/nmap_static" "nmap (static Linux)"

# Chisel — try to get latest
echo -ne "  ${DIM}[*]${RST} Fetching chisel latest version..."
CHISEL_VER=$(curl -sI https://github.com/jpillora/chisel/releases/latest 2>/dev/null | grep -i location | grep -oP 'v[\d.]+' || echo "v1.10.1")
echo -e " ${CHISEL_VER}"
grab "https://github.com/jpillora/chisel/releases/download/${CHISEL_VER}/chisel_${CHISEL_VER#v}_linux_amd64.gz" "$TOOLS_DIR/pivoting/chisel_linux.gz" "Chisel Linux"
grab "https://github.com/jpillora/chisel/releases/download/${CHISEL_VER}/chisel_${CHISEL_VER#v}_windows_amd64.gz" "$TOOLS_DIR/pivoting/chisel_windows.gz" "Chisel Windows"

# Decompress chisel
[ -f "$TOOLS_DIR/pivoting/chisel_linux.gz" ] && [ ! -f "$TOOLS_DIR/pivoting/chisel_linux" ] && gunzip -k "$TOOLS_DIR/pivoting/chisel_linux.gz" 2>/dev/null
[ -f "$TOOLS_DIR/pivoting/chisel_windows.gz" ] && [ ! -f "$TOOLS_DIR/pivoting/chisel.exe" ] && { gunzip -k "$TOOLS_DIR/pivoting/chisel_windows.gz" 2>/dev/null; mv "$TOOLS_DIR/pivoting/chisel_windows" "$TOOLS_DIR/pivoting/chisel.exe" 2>/dev/null; }

# Ligolo-ng
echo -ne "  ${DIM}[*]${RST} Fetching ligolo-ng latest version..."
LIGOLO_VER=$(curl -sI https://github.com/nicocha30/ligolo-ng/releases/latest 2>/dev/null | grep -i location | grep -oP 'v[\d.]+' || echo "v0.8.2")
echo -e " ${LIGOLO_VER}"
grab "https://github.com/nicocha30/ligolo-ng/releases/download/${LIGOLO_VER}/ligolo-ng_proxy_${LIGOLO_VER#v}_linux_amd64.tar.gz" "$TOOLS_DIR/pivoting/ligolo_proxy.tar.gz" "Ligolo proxy (Linux)"
grab "https://github.com/nicocha30/ligolo-ng/releases/download/${LIGOLO_VER}/ligolo-ng_agent_${LIGOLO_VER#v}_linux_amd64.tar.gz" "$TOOLS_DIR/pivoting/ligolo_agent_linux.tar.gz" "Ligolo agent (Linux)"
grab "https://github.com/nicocha30/ligolo-ng/releases/download/${LIGOLO_VER}/ligolo-ng_agent_${LIGOLO_VER#v}_windows_amd64.zip" "$TOOLS_DIR/pivoting/ligolo_agent_windows.zip" "Ligolo agent (Windows)"

# Extract ligolo
for tar in "$TOOLS_DIR"/pivoting/ligolo_*.tar.gz; do
    [ -f "$tar" ] && tar xzf "$tar" -C "$TOOLS_DIR/pivoting/" 2>/dev/null
done

# ═══════ WEB SHELLS ═══════
section "Web Exploitation"
grab "https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php" "$TOOLS_DIR/web/php-reverse-shell.php" "PHP reverse shell"
grab "https://raw.githubusercontent.com/flozz/p0wny-shell/master/shell.php" "$TOOLS_DIR/web/p0wny-shell.php" "p0wny-shell"
grab "https://raw.githubusercontent.com/WhiteWinterWolf/wwwolf-php-webshell/master/webshell.php" "$TOOLS_DIR/web/wwwolf-webshell.php" "wwwolf webshell"

# ═══════ Set permissions ═══════
chmod +x "$TOOLS_DIR"/linux/*.sh "$TOOLS_DIR"/linux/*.pl 2>/dev/null
chmod +x "$TOOLS_DIR"/linux/pspy* 2>/dev/null
chmod +x "$TOOLS_DIR"/pivoting/chisel_linux "$TOOLS_DIR"/pivoting/socat_static "$TOOLS_DIR"/pivoting/nmap_static 2>/dev/null
chmod +x "$TOOLS_DIR"/pivoting/proxy "$TOOLS_DIR"/pivoting/agent 2>/dev/null
chmod +x "$TOOLS_DIR"/ad/kerbrute 2>/dev/null

# ═══════ PIP REMINDER ═══════
section "Pip Packages (install separately)"
echo -e "  ${CYN}pip install impacket${RST}             # secretsdump, psexec, getST"
echo -e "  ${CYN}pip install bloodyAD${RST}             # AD object manipulation"
echo -e "  ${CYN}pip install bloodhound${RST}           # Python BloodHound collector"
echo -e "  ${CYN}pip install certipy-ad${RST}           # AD certificate abuse"
echo -e "  ${CYN}gem install evil-winrm${RST}           # WinRM shell"
echo -e "  ${CYN}sudo apt install seclists${RST}        # Wordlists"

# ═══════ SUMMARY ═══════
section "Summary"
TOTAL=$(find "$TOOLS_DIR" -type f | wc -l)
echo ""
echo -e "  ${GRN}Downloaded: ${DOWNLOADED}${RST}  ${YEL}Skipped: ${SKIPPED}${RST}  ${RED}Failed: ${FAILED}${RST}  ${BLD}Total: ${TOTAL} files${RST}"
echo ""
echo -e "  ${DIM}├── linux/${RST}              linPEAS, pspy, exploit-suggester, LinEnum"
echo -e "  ${DIM}├── windows/${RST}            winPEAS, PowerUp, nc.exe, RunasCs"
echo -e "  ${DIM}│   ├── potatoes/${RST}       GodPotato, PrintSpoofer, SigmaPotato, JuicyPotato"
echo -e "  ${DIM}│   └── sharp/${RST}          SharpUp, Seatbelt"
echo -e "  ${DIM}├── ad/${RST}                 Mimikatz, Rubeus, SharpHound, PowerView, kerbrute"
echo -e "  ${DIM}├── web/${RST}                PHP reverse shell, webshells"
echo -e "  ${DIM}├── pivoting/${RST}           Chisel, Ligolo-ng, socat, static nmap"
echo -e "  ${DIM}└── misc/${RST}               LaZagne"
echo ""
echo -e "  ${BLD}Exam day — serve them:${RST}"
echo -e "    ${CYN}cd $TOOLS_DIR && python3 -m http.server 8000${RST}"
echo ""
