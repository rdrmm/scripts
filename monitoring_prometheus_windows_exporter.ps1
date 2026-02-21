####################################################################
# rdRMM script to install prometheus + windows_exporter on Windows #
####################################################################

$ErrorActionPreference = "Stop"

Write-Host "Creating install directories..."
$root = "C:\rdRMM\monitoring"
$promDir = "$root\prometheus"
$exporterDir = "$root\windows_exporter"

New-Item -ItemType Directory -Force -Path $root, $promDir, $exporterDir | Out-Null

# -------------------------------
# Download latest Prometheus
# -------------------------------
Write-Host "Fetching latest Prometheus release info..."
$promRelease = Invoke-RestMethod https://api.github.com/repos/prometheus/prometheus/releases/latest
$promAsset = $promRelease.assets |
    Where-Object { $_.name -like '*windows-amd64*' -and $_.name -like '*zip*' } |
    Select-Object -First 1

Write-Host "Downloading Prometheus $($promRelease.tag_name)..."
Invoke-WebRequest -Uri $promAsset.browser_download_url -OutFile "$root\prometheus.zip"

Write-Host "Extracting Prometheus..."
Expand-Archive "$root\prometheus.zip" -DestinationPath $promDir -Force
$promSubDir = (Get-ChildItem -Path $promDir -Recurse -File -Filter 'prometheus.exe'). Where({ $true }, 1).Directory.FullName
Move-Item "$promSubDir\*" $promDir -Force
Remove-Item $promSubDir -Recurse -Force
Remove-Item "$root\prometheus.zip"

# -------------------------------
# Download latest windows_exporter
# -------------------------------
Write-Host "Fetching latest windows_exporter release info..."
$expRelease = Invoke-RestMethod https://api.github.com/repos/prometheus-community/windows_exporter/releases/latest
$expAsset = $expRelease.assets | Where-Object { $_.name -match "amd64.msi" } | Select-Object -First 1

Write-Host "Downloading windows_exporter $($expRelease.tag_name)..."
$msiPath = "$root\windows_exporter.msi"
Invoke-WebRequest -Uri $expAsset.browser_download_url -OutFile $msiPath

Write-Host "Installing windows_exporter..."
Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn" -Wait
Remove-Item $msiPath

# -------------------------------
# Configure Prometheus
# -------------------------------
Write-Host "Writing prometheus.yml..."

@"
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'windows'
    static_configs:
      - targets: ['localhost:9182']
"@ | Set-Content "$promDir\prometheus.yml"

# -------------------------------
# Install Prometheus as a service
# -------------------------------
Write-Host "Installing Prometheus as a Windows service..."

sc.exe create Prometheus binPath= "`"$promDir\prometheus.exe --config.file=$promDir\prometheus.yml`"" start= auto
sc.exe description Prometheus "Prometheus Monitoring Server"

# -------------------------------
# Start services
# -------------------------------
Write-Host "Starting services..."
Start-Service windows_exporter
Start-Service Prometheus

Write-Host "`nInstallation complete!"
Write-Host "Prometheus running at: http://localhost:9090"
Write-Host "windows_exporter metrics at: http://localhost:9182/metrics"
