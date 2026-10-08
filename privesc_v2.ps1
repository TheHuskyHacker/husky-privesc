<#
.SYNOPSIS
    Husky Privesc - Windows Privilege Escalation Enumerator v2
.DESCRIPTION
    Enumerates common Windows privesc vectors including writable service
    binaries, service directory DLL hijack, unquoted paths, token privileges,
    credential files, internal services, and more.
    Now uses registry-based fallback so service checks work WITHOUT admin.
.EXAMPLE
    powershell -ep bypass -f privesc.ps1
#>
$Host.UI.RawUI.WindowTitle = "Husky Privesc v2"

# -- Output helpers ----------------------------------------------
function Write-Banner {
    Write-Host ""
    Write-Host "    HUSKY HACKER" -ForegroundColor Cyan
    Write-Host "    P R I V E S C   E N U M E R A T O R   v2" -ForegroundColor White
    Write-Host "    Find the path. Take the crown." -ForegroundColor DarkGray
    Write-Host ""
}
function Write-Section($t) { Write-Host ""; Write-Host "  === $t ===" -ForegroundColor Cyan }
function Write-Crit($m,$d) { Write-Host "  [CRITICAL] $m" -ForegroundColor Red; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:crits++ }
function Write-High($m,$d) { Write-Host "  [HIGH] $m" -ForegroundColor Yellow; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:highs++ }
function Write-Med($m,$d)  { Write-Host "  [MEDIUM] $m" -ForegroundColor Cyan; if($d){Write-Host "    -> $d" -ForegroundColor DarkGray}; $script:meds++ }
function Write-Info($m)    { Write-Host "  [*] $m" -ForegroundColor DarkGray }
$script:crits = 0; $script:highs = 0; $script:meds = 0

# -- Helper: extract exe path from ImagePath / PathName ----------
function Get-ExePath {
    param([string]$raw)
    if (-not $raw) { return $null }
    $raw = $raw.Trim()
    if ($raw.StartsWith('"')) {
        $close = $raw.IndexOf('"', 1)
        if ($close -gt 1) { return $raw.Substring(1, $close - 1) }
    }
    # No quotes - take up to first space (or whole string)
    $parts = $raw -split '\s+', 2
    return $parts[0]
}

# -- Helper: check if an ACL grants write to low-priv identities -
function Test-WeakAcl {
    param([string]$path)
    if (-not (Test-Path $path -ErrorAction SilentlyContinue)) { return $null }
    try {
        $acl = Get-Acl $path -ErrorAction Stop
        $cu  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $weakIds = @()
        foreach ($ace in $acl.Access) {
            $id = $ace.IdentityReference.ToString()
            $rights = $ace.FileSystemRights.ToString()
            if ($ace.AccessControlType -ne 'Allow') { continue }
            if ($rights -notmatch 'Modify|FullControl|Write|WriteData|AppendData|ChangePermissions|TakeOwnership') { continue }
            if ($id -match 'Everyone|BUILTIN\\Users|Authenticated Users|INTERACTIVE' -or $id -eq $cu) {
                $weakIds += "$id ($rights)"
            }
        }
        if ($weakIds.Count -gt 0) { return $weakIds }
    } catch {}
    return $null
}

# -- Helper: translate registry Start value ----------------------
function Get-StartTypeName {
    param([int]$s)
    switch ($s) {
        0 { "Boot"        }
        1 { "System"      }
        2 { "Auto"        }
        3 { "Manual (DEMAND_START - attacker can trigger with sc.exe start)" }
        4 { "Disabled"    }
        default { "Unknown ($s)" }
    }
}

# -- Helper: translate ObjectName to plain English ---------------
function Get-ServiceIdentityNote {
    param([string]$obj)
    if (-not $obj) { return "LocalSystem (SYSTEM - highest privilege)" }
    switch -Wildcard ($obj) {
        'LocalSystem'           { "LocalSystem (SYSTEM - highest privilege)" }
        'NT AUTHORITY\SYSTEM'   { "LocalSystem (SYSTEM - highest privilege)" }
        'NT AUTHORITY\LocalService'   { "LocalService (limited)" }
        'NT AUTHORITY\NetworkService' { "NetworkService (limited)" }
        default { "$obj (domain/custom account)" }
    }
}

Write-Banner

# ================================================================
#  1. SYSTEM INFORMATION
# ================================================================
Write-Section "System Information"
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction Stop
    Write-Info "Hostname: $($env:COMPUTERNAME)"
    Write-Info "OS: $($os.Caption) $($os.Version)"
    Write-Info "Domain: $($cs.Domain)"
    Write-Info "User: $($env:USERDOMAIN)\$($env:USERNAME)"
    Write-Info "Arch: $($os.OSArchitecture)"
    if ($cs.PartOfDomain) { Write-Info "DOMAIN JOINED to $($cs.Domain)" }
} catch {
    Write-Info "Hostname: $($env:COMPUTERNAME)"
    Write-Info "User: $($env:USERDOMAIN)\$($env:USERNAME)"
}

# ================================================================
#  2. TOKEN PRIVILEGES
# ================================================================
Write-Section "Token Privileges"
$privs = whoami /priv 2>$null
if ($privs) {
    $dp = @{
        "SeImpersonatePrivilege"       = "GodPotato/PrintSpoofer/JuicyPotato -> SYSTEM"
        "SeAssignPrimaryTokenPrivilege" = "Token manipulation -> SYSTEM"
        "SeBackupPrivilege"            = "Backup SAM/SYSTEM -> offline hash extraction"
        "SeRestorePrivilege"           = "Overwrite system files"
        "SeTcbPrivilege"               = "TcbElevation.exe -> SYSTEM"
        "SeDebugPrivilege"             = "Debug processes -> migrate into SYSTEM"
        "SeLoadDriverPrivilege"        = "Load vulnerable kernel driver"
        "SeTakeOwnershipPrivilege"     = "Take ownership of any object"
        "SeCreateTokenPrivilege"       = "Create arbitrary tokens"
    }
    foreach ($p in $dp.Keys) {
        $m = $privs | Select-String -Pattern $p
        if ($m) {
            if ($m -match "Enabled") { Write-Crit "$p is ENABLED" $dp[$p] }
            else { Write-High "$p present (disabled)" $dp[$p] }
        }
    }
}

# ================================================================
#  3. GROUP MEMBERSHIP
# ================================================================
Write-Section "Group Membership"
$groups = whoami /groups 2>$null
$ig = @("BUILTIN\\Administrators","Backup Operators","Server Operators",
        "Account Operators","DnsAdmins","Domain Admins",
        "Remote Desktop Users","Remote Management Users")
foreach ($g in $ig) {
    if ($groups -match [regex]::Escape($g)) { Write-High "Member of: $g" }
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Write-Crit "Running as LOCAL ADMINISTRATOR" "Grab hashes with Mimikatz" }

# ================================================================
#  4. SERVICE MISCONFIGURATIONS  (the big upgrade)
# ================================================================
Write-Section "Service Misconfigurations"

# --- Gather services: try WMI first, fall back to registry ------
$services = @()
$wmiWorked = $false

try {
    Write-Info "Trying WMI service enumeration..."
    $wmiSvcs = Get-CimInstance Win32_Service -ErrorAction Stop
    foreach ($s in $wmiSvcs) {
        if (-not $s.PathName) { continue }
        $services += [PSCustomObject]@{
            Name      = $s.Name
            Display   = $s.DisplayName
            PathName  = $s.PathName
            ExePath   = Get-ExePath $s.PathName
            RunAs     = if ($s.StartName) { $s.StartName } else { "LocalSystem" }
            StartType = $s.StartMode   # Auto / Manual / Disabled
            State     = $s.State
            Source    = "WMI"
        }
    }
    $wmiWorked = $true
    Write-Info "WMI: Enumerated $($services.Count) services"
} catch {
    Write-Info "WMI access denied - falling back to registry (works without admin)"
}

if (-not $wmiWorked) {
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services'
        $svcKeys = Get-ChildItem $regPath -ErrorAction Stop
        foreach ($key in $svcKeys) {
            try {
                $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
                # Only real services have an ImagePath and a Type that includes
                # SERVICE_WIN32 (0x10 or 0x20, bit mask 0x30)
                $stype = $props.Type
                if ($null -eq $stype) { continue }
                if (($stype -band 0x30) -eq 0) { continue }  # not a Win32 service

                $imgPath = $props.ImagePath
                if (-not $imgPath) { continue }

                $services += [PSCustomObject]@{
                    Name      = $key.PSChildName
                    Display   = $props.DisplayName
                    PathName  = $imgPath
                    ExePath   = Get-ExePath $imgPath
                    RunAs     = if ($props.ObjectName) { $props.ObjectName } else { "LocalSystem" }
                    StartType = Get-StartTypeName ([int]$props.Start)
                    State     = $null  # can't get state from registry
                    Source    = "Registry"
                }
            } catch {}
        }
        Write-Info "Registry: Enumerated $($services.Count) services"
    } catch {
        Write-Info "ERROR: Could not enumerate services from WMI or registry"
    }
}

# --- 4a. Unquoted service paths --------------------------------
Write-Info "Checking unquoted service paths..."
foreach ($svc in $services) {
    $p = $svc.PathName
    if ($p -and $p -notmatch '^"' -and $p -notmatch '^C:\\Windows\\' -and $p -match ' ') {
        $identity = Get-ServiceIdentityNote $svc.RunAs
        Write-High "Unquoted service path: $($svc.Name)" "$p | Runs as: $identity"
    }
}

# --- 4b. Writable service binaries ------------------------------
Write-Info "Checking service binary permissions..."
$checked = @{}  # avoid duplicate checks on the same path
foreach ($svc in $services) {
    $exe = $svc.ExePath
    if (-not $exe) { continue }
    if ($checked.ContainsKey($exe.ToLower())) { continue }
    $checked[$exe.ToLower()] = $true

    # Skip Windows system binaries - they're almost never writable
    if ($exe -match '^C:\\Windows\\' -and $exe -notmatch '^C:\\Windows\\Temp\\') { continue }

    $weakAces = Test-WeakAcl $exe
    if ($weakAces) {
        $identity  = Get-ServiceIdentityNote $svc.RunAs
        $startInfo = $svc.StartType
        $detail    = "Path: $exe`n    -> Runs as: $identity`n    -> Start: $startInfo`n    -> Weak ACEs: $($weakAces -join ', ')"

        # CRITICAL if it runs as SYSTEM and can be started manually
        if ($identity -match 'SYSTEM|LocalSystem' -and $startInfo -match 'Manual|DEMAND') {
            Write-Crit "Writable service binary (SYSTEM + manual start!): $($svc.Name)" $detail
        } elseif ($identity -match 'SYSTEM|LocalSystem') {
            Write-Crit "Writable service binary (SYSTEM): $($svc.Name)" $detail
        } else {
            Write-High "Writable service binary: $($svc.Name)" $detail
        }
    }
}

# --- 4c. Writable service DIRECTORIES (DLL hijack) ---------------
Write-Info "Checking service directory permissions (DLL hijack)..."
$checkedDirs = @{}
foreach ($svc in $services) {
    $exe = $svc.ExePath
    if (-not $exe) { continue }
    if ($exe -match '^C:\\Windows\\') { continue }

    $dir = Split-Path $exe -Parent -ErrorAction SilentlyContinue
    if (-not $dir) { continue }
    if ($checkedDirs.ContainsKey($dir.ToLower())) { continue }
    $checkedDirs[$dir.ToLower()] = $true

    $weakAces = Test-WeakAcl $dir
    if ($weakAces) {
        $identity = Get-ServiceIdentityNote $svc.RunAs
        $detail   = "Dir: $dir`n    -> Service: $($svc.Name) runs as $identity`n    -> Weak ACEs: $($weakAces -join ', ')"
        if ($identity -match 'SYSTEM|LocalSystem') {
            Write-Crit "Writable service directory (DLL hijack -> SYSTEM): $($svc.Name)" $detail
        } else {
            Write-High "Writable service directory (DLL hijack): $($svc.Name)" $detail
        }
    }
}

# --- 4d. Non-standard program directories with weak ACLs ---------
Write-Info "Scanning non-standard program directories..."
$customDirs = @("C:\Services","C:\Apps","C:\Tools","C:\Opt","C:\Program Files (Custom)",
                "C:\inetpub","C:\WebApps","C:\scripts")
foreach ($d in $customDirs) {
    if (-not (Test-Path $d -ErrorAction SilentlyContinue)) { continue }
    try {
        Get-ChildItem $d -Recurse -Include *.exe,*.dll -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 50MB } | Select-Object -First 50 | ForEach-Object {
                $weakAces = Test-WeakAcl $_.FullName
                if ($weakAces) {
                    Write-High "Writable binary in custom dir: $($_.FullName)" "ACEs: $($weakAces -join ', ')"
                }
            }
    } catch {}
}

# ================================================================
#  5. SCHEDULED TASKS
# ================================================================
Write-Section "Scheduled Tasks"
Write-Info "Checking writable task binaries..."
try {
    $tasks = schtasks /query /fo CSV /v 2>$null | ConvertFrom-Csv -ErrorAction SilentlyContinue
    foreach ($t in $tasks) {
        $act = $t."Task To Run"
        if ($act -and $act -ne "N/A" -and $act -notmatch "COM handler") {
            $tp = (Get-ExePath $act)
            if ($tp -and (Test-Path $tp -ErrorAction SilentlyContinue)) {
                $weakAces = Test-WeakAcl $tp
                if ($weakAces) {
                    $runAs = $t."Run As User"
                    Write-High "Writable task binary: $($t.TaskName)" "Binary: $tp | Runs as: $runAs | ACEs: $($weakAces -join ', ')"
                }
            }
        }
    }
} catch {}

# ================================================================
#  6. AlwaysInstallElevated
# ================================================================
Write-Section "AlwaysInstallElevated"
$aie1 = $null; $aie2 = $null
try { $aie1 = (Get-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated } catch {}
try { $aie2 = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -Name AlwaysInstallElevated -ErrorAction SilentlyContinue).AlwaysInstallElevated } catch {}
if ($aie1 -eq 1 -and $aie2 -eq 1) {
    Write-Crit "AlwaysInstallElevated ENABLED!" "msfvenom -f msi > evil.msi && msiexec /quiet /qn /i evil.msi"
} else {
    Write-Info "AlwaysInstallElevated: Not enabled"
}

# ================================================================
#  7. STORED CREDENTIALS
# ================================================================
Write-Section "Stored Credentials"
$ck = cmdkey /list 2>$null
if ($ck -match "Target:") {
    Write-High "Stored credentials found" "runas /savecred /user:<user> cmd.exe"
    $ck | Select-String "Target:" | ForEach-Object { Write-Info "  $_" }
}
try {
    $au = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
    $ap = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultPassword
    if ($ap) { Write-Crit "AutoLogon password found!" "User: $au  Pass: $ap" }
    elseif ($au) { Write-Med "AutoLogon user: $au (no pass in registry)" }
} catch {}
try {
    $dp2 = Get-ChildItem "$env:APPDATA\Microsoft\Credentials" -ErrorAction SilentlyContinue
    if ($dp2) { Write-Med "DPAPI credential files: $($dp2.Count) file(s)" "Mimikatz dpapi::cred" }
} catch {}

# ================================================================
#  8. POWERSHELL HISTORY
# ================================================================
Write-Section "PowerShell History"
$hp = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $hp) {
    $hs = (Get-Item $hp).Length
    Write-High "PS history found: $hp ($hs bytes)"
    try {
        Select-String -Path $hp -Pattern "pass|pwd|cred|secret|key|token|api" -ErrorAction SilentlyContinue |
            Select-Object -First 5 | ForEach-Object { Write-Info "  $($_.Line.Trim())" }
    } catch {}
} else { Write-Info "No PowerShell history" }

# Also check other users' histories if readable
try {
    Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $hp } | ForEach-Object {
            Write-High "Other user PS history readable: $($_.FullName) ($($_.Length) bytes)"
            try {
                Select-String -Path $_.FullName -Pattern "pass|pwd|cred|secret|key|token|api" -ErrorAction SilentlyContinue |
                    Select-Object -First 3 | ForEach-Object { Write-Info "  $($_.Line.Trim())" }
            } catch {}
        }
} catch {}

# ================================================================
#  9. INTERESTING FILES  (expanded search)
# ================================================================
Write-Section "Interesting Files"

# SAM/SYSTEM backups
@("C:\Windows\Repair\SAM","C:\Windows\Repair\SYSTEM",
  "C:\Windows\System32\config\RegBack\SAM","C:\Windows\System32\config\RegBack\SYSTEM") |
    ForEach-Object {
        if (Test-Path $_ -ErrorAction SilentlyContinue) {
            Write-High "SAM/SYSTEM backup: $_" "secretsdump -sam SAM -system SYSTEM LOCAL"
        }
    }

# Unattend files
@("C:\Unattend.xml","C:\Windows\Panther\Unattend.xml",
  "C:\Windows\Panther\Unattend\Unattend.xml",
  "C:\Windows\System32\Sysprep\unattend.xml") |
    ForEach-Object {
        if (Test-Path $_ -ErrorAction SilentlyContinue) {
            Write-High "Unattend file: $_" "May contain plaintext creds"
        }
    }

# Credential search in C:\Users (expanded file types)
Write-Info "Searching C:\Users for credential files..."
try {
    Get-ChildItem -Path C:\Users -Recurse -Include *.txt,*.xml,*.ini,*.config,*.json,*.ps1,*.cmd,*.bat,*.yaml,*.yml,*.env -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -lt 1MB -and $_.Length -gt 0 } | Select-Object -First 200 |
        Select-String -Pattern "password|passwd|pwd|credential|secret|connectionstring|apikey|api_key" -ErrorAction SilentlyContinue |
        Select-Object -Unique Path -First 15 | ForEach-Object { Write-Med "Possible creds: $($_.Path)" }
} catch {}

# Deep scan: service dirs, scripts, ProgramData (the stuff WinPEAS catches)
Write-Info "Searching service/script directories for credential files..."
$deepScanDirs = @("C:\Services","C:\scripts","C:\ProgramData","C:\inetpub","C:\Apps","C:\Tools","C:\Opt","C:\WebApps")
foreach ($scanDir in $deepScanDirs) {
    if (-not (Test-Path $scanDir -ErrorAction SilentlyContinue)) { continue }
    try {
        Get-ChildItem -Path $scanDir -Recurse -Include *.json,*.config,*.xml,*.ps1,*.bat,*.cmd,*.ini,*.txt,*.yaml,*.yml,*.env -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 1MB -and $_.Length -gt 0 } | Select-Object -First 100 |
            Select-String -Pattern "password|passwd|pwd|credential|secret|connectionstring|apikey|api_key|token" -ErrorAction SilentlyContinue |
            Select-Object -Unique Path -First 10 | ForEach-Object {
                Write-High "Credential in service/script dir: $($_.Path)" "Manual review recommended"
            }
    } catch {}
}

# Jenkins secrets
@("C:\ProgramData\Jenkins\.jenkins\secrets\initialAdminPassword",
  "C:\Program Files\Jenkins\secrets\initialAdminPassword",
  "C:\Program Files (x86)\Jenkins\secrets\initialAdminPassword") |
    ForEach-Object {
        if (Test-Path $_ -ErrorAction SilentlyContinue) {
            $pw = (Get-Content $_ -ErrorAction SilentlyContinue | Select-Object -First 1)
            Write-Crit "Jenkins initialAdminPassword found!" "File: $_ | Password: $pw"
        }
    }

# web.config connection strings
Write-Info "Searching for web.config with connection strings..."
try {
    Get-ChildItem -Path C:\ -Recurse -Include web.config,appsettings.json,app.config -ErrorAction SilentlyContinue -Depth 5 |
        Where-Object { $_.FullName -notmatch 'Windows\\' -and $_.Length -lt 1MB -and $_.Length -gt 0 } |
        Select-Object -First 20 |
        Select-String -Pattern "connectionString|password|pwd|Data Source|User Id" -ErrorAction SilentlyContinue |
        Select-Object -Unique Path -First 5 | ForEach-Object {
            Write-High "Config with connection string: $($_.Path)"
        }
} catch {}

# ================================================================
# 10. NETWORK AND INTERNAL SERVICES  (expanded)
# ================================================================
Write-Section "Network and Internal Services"
Write-Info "Listening ports:"
$lp = @{
    "80"="HTTP";"443"="HTTPS";"3306"="MySQL";"5432"="PostgreSQL";
    "6379"="Redis";"27017"="MongoDB";"1433"="MSSQL";"1434"="MSSQL-Browser";
    "8080"="HTTP-alt (Jenkins/Tomcat?)";"8443"="HTTPS-alt";
    "3000"="Dev-app (Grafana/Gitea?)";"9200"="Elasticsearch";
    "5601"="Kibana";"8888"="Jupyter?";"9090"="Prometheus?";
    "2049"="NFS";"11211"="Memcached";"4848"="GlassFish";
    "7474"="Neo4j";"15672"="RabbitMQ-mgmt";"8161"="ActiveMQ";
    "50000"="Jenkins-agent";"8009"="AJP (Tomcat)"
}
$netstatOut = netstat -ano 2>$null
$netstatOut | Select-String "LISTENING" | ForEach-Object {
    $l = $_.ToString().Trim()
    foreach ($port in $lp.Keys) {
        if ($l -match "(?:127\.0\.0\.1|0\.0\.0\.0):$port\s") {
            # Try to identify the PID and process name
            $pid_match = [regex]::Match($l, '\s+(\d+)\s*$')
            $procInfo = ""
            if ($pid_match.Success) {
                try {
                    $proc = Get-Process -Id $pid_match.Groups[1].Value -ErrorAction SilentlyContinue
                    if ($proc) { $procInfo = " | Process: $($proc.Name) (PID $($proc.Id))" }
                } catch {}
            }
            if ($l -match "0\.0\.0\.0:$port\s") {
                Write-High "$($lp[$port]) on 0.0.0.0:$port (exposed!)$procInfo" "Accessible from network"
            } else {
                Write-Med "Internal $($lp[$port]) on 127.0.0.1:$port$procInfo" "Tunnel with Ligolo/Chisel for access"
            }
        }
    }
}

# ================================================================
# 11. INSTALLED SOFTWARE
# ================================================================
Write-Section "Installed Software"
Write-Info "Non-default software:"
try {
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft|Windows|Update|Visual C|\.NET" } |
        Select-Object DisplayName,DisplayVersion -First 20 | ForEach-Object {
            $ver = $_.DisplayVersion
            $name = $_.DisplayName
            # Flag commonly exploitable software
            $exploitable = $false
            if ($name -match "Jenkins|Tomcat|XAMPP|WinSCP|FileZilla Server|VNC|TeamViewer|PuTTY|KeePass|mRemoteNG") {
                $exploitable = $true
            }
            if ($exploitable) {
                Write-Med "Exploitable software: $name $ver" "Check for stored creds / known CVEs"
            } else {
                Write-Info "  $name $ver"
            }
        }
} catch {}

# ================================================================
# 12. PATH HIJACK CHECK
# ================================================================
Write-Section "PATH Hijack"
Write-Info "Checking for writable directories in system PATH..."
$pathDirs = $env:Path -split ';'
foreach ($pd in $pathDirs) {
    if (-not $pd -or $pd -match '^C:\\Windows' -or $pd -match '^C:\\Program Files') { continue }
    if (Test-Path $pd -ErrorAction SilentlyContinue) {
        $weakAces = Test-WeakAcl $pd
        if ($weakAces) {
            Write-High "Writable directory in PATH: $pd" "Drop a malicious DLL here | ACEs: $($weakAces -join ', ')"
        }
    }
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "  =================================================" -ForegroundColor Red
Write-Host "  PRIVESC SUMMARY" -ForegroundColor White
Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host -NoNewline "  CRITICAL: $script:crits  " -ForegroundColor Red
Write-Host -NoNewline "HIGH: $script:highs  " -ForegroundColor Yellow
Write-Host "MEDIUM: $script:meds" -ForegroundColor Cyan
Write-Host "  =================================================" -ForegroundColor Red
Write-Host ""
