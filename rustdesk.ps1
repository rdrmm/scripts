#####################################################
# rdRMM script to install rustdesk and return id/pw #
#####################################################
$BaseDir = "C:\ProgramData\rdrmm\rustdesk"
$ExePath = Join-Path $BaseDir "rustdesk.exe"
$RustDeskUrl = "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk.exe"

$ConfigPath = "C:\Windows\System32\config\systemprofile\AppData\Roaming\RustDesk\RustDesk.toml"
$LogPath    = "C:\Windows\System32\config\systemprofile\AppData\Local\RustDesk\log\rustdesk.log"

# Ensure directory exists
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

# Download RustDesk if missing
if (-not (Test-Path $ExePath)) {
    Invoke-WebRequest -Uri $RustDeskUrl -OutFile $ExePath -UseBasicParsing
}

# Start RustDesk (SYSTEM)
Start-Process -FilePath $ExePath

# Wait for config/logs
$MaxWait = 20
$Elapsed = 0
while ($Elapsed -lt $MaxWait) {
    if (Test-Path $ConfigPath -or Test-Path $LogPath) { break }
    Start-Sleep -Seconds 1
    $Elapsed++
}

# Prepare result
$result = [ordered]@{
    id           = $null
    password     = $null
    passwordType = $null
    message      = $null
}

# Try config first (permanent password)
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath

    $idLine = $config | Select-String '^id\s*=' | Select-Object -Last 1
    if ($idLine) { $result.id = ($idLine.ToString().Split('"')[1]) }

    $pwLine = $config | Select-String '^password\s*=' | Select-Object -Last 1
    if ($pwLine) {
        $result.password = ($pwLine.ToString().Split('"')[1])
        $result.passwordType = "permanent"
        $result.message = "Permanent password found in config."
    }
}

# If no permanent password, check logs for temporary password
if (-not $result.password -and (Test-Path $LogPath)) {
    $log = Get-Content $LogPath

    if (-not $result.id) {
        $idLine = $log | Select-String "ID:" | Select-Object -Last 1
        if ($idLine) { $result.id = ($idLine.ToString().Split(":")[1].Trim()) }
    }

    $pwLine = $log | Select-String "Password:" | Select-Object -Last 1
    if ($pwLine) {
        $result.password = ($pwLine.ToString().Split(":")[1].Trim())
        $result.passwordType = "temporary"
        $result.message = "Temporary password found in logs."
    }
}

if (-not $result.id -and -not $result.password) {
    $result.message = "RustDesk ID/password not found yet."
}

$result | ConvertTo-Json -Depth 5
