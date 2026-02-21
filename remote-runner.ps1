########################################################################
# rdRMM wrapper to execute commands from url under jobID and save logs #
########################################################################
param(
    [Parameter(Mandatory=$true)]
    [string]$Url,

    [Parameter(Mandatory=$true)]
    [string]$JobID,

    [string]$LogBaseDir = "C:\rdRMM\logs"
)

# Ensure log directory exists
if (-not (Test-Path $LogBaseDir)) {
    New-Item -ItemType Directory -Path $LogBaseDir -Force | Out-Null
}

# Build log file paths
$StdOutLog = Join-Path $LogBaseDir "$JobID-stdout.log"
$StdErrLog = Join-Path $LogBaseDir "$JobID-stderr.log"

Write-Host "Downloading script from $Url..."
$content = Invoke-WebRequest -Uri $Url -UseBasicParsing
$lines = $content.Content -split "`r?`n"

Write-Host "Executing script line by line..."
foreach ($line in $lines) {

    # Skip empty lines or comments
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) {
        continue
    }

    Write-Host "Running: $line"

    try {
        $output = Invoke-Expression $line 2>&1

        if ($LASTEXITCODE -ne 0 -or $output -is [System.Management.Automation.ErrorRecord]) {
            Add-Content -Path $StdErrLog -Value "ERROR executing: $line"
            Add-Content -Path $StdErrLog -Value $output
        }
        else {
            Add-Content -Path $StdOutLog -Value "OUTPUT from: $line"
            Add-Content -Path $StdOutLog -Value $output
        }
    }
    catch {
        Add-Content -Path $StdErrLog -Value "EXCEPTION executing: $line"
        Add-Content -Path $StdErrLog -Value $_
    }
}

Write-Host "Execution complete. Logs written to:"
Write-Host "  StdOut: $StdOutLog"
Write-Host "  StdErr: $StdErrLog"
