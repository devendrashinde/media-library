################################################################################
# Media Library - Windows to Raspberry Pi OSMC Deployment Script
# 
# Prerequisites:
#   - SSH client (built into Windows 10/11)
#   - Network access to Raspberry Pi
#   - Node.js installed on Windows (for building frontend)
#
# Usage: 
#   .\deploy-to-pi.ps1 -PiHost 192.168.1.100 -PiUser osmc -MediaDir /home/osmc/Videos
################################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$PiHost = "",
    
    [Parameter(Mandatory=$false)]
    [string]$PiUser = "osmc",
    
    [Parameter(Mandatory=$false)]
    [string]$MediaDir = "/home/osmc/Videos",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("native", "docker")]
    [string]$DeployType = "native"
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Media Library - Windows to Pi Deployment            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Interactive prompts if parameters not provided
if (-not $PiHost) {
    $PiHost = Read-Host "Enter Raspberry Pi IP address or hostname"
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Pi Host: $PiHost"
Write-Host "  Pi User: $PiUser"
Write-Host "  Media Directory: $MediaDir"
Write-Host "  Deployment Type: $DeployType"
Write-Host ""

# Test SSH connection
Write-Host "[1/6] Testing SSH connection to Raspberry Pi..." -ForegroundColor Blue
try {
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$PiUser@$PiHost" "exit" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "SSH connection failed"
    }
    Write-Host "✓ SSH connection successful" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot connect to $PiUser@$PiHost" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "  1. SSH is enabled on OSMC (via MyOSMC app)"
    Write-Host "  2. You have SSH key authentication set up OR use -PiPassword parameter"
    Write-Host "  3. The IP address/hostname is correct"
    Write-Host ""
    Write-Host "To set up SSH key authentication:" -ForegroundColor Yellow
    Write-Host "  ssh-copy-id $PiUser@$PiHost"
    exit 1
}

# Build frontend
Write-Host ""
Write-Host "[2/6] Building frontend..." -ForegroundColor Blue
Set-Location "$PSScriptRoot\frontend"
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing frontend dependencies..." -ForegroundColor Yellow
    npm install
}
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Frontend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Frontend built successfully" -ForegroundColor Green

# Create deployment package
Write-Host ""
Write-Host "[3/6] Creating deployment package..." -ForegroundColor Blue
Set-Location $PSScriptRoot

$PackageName = "media-library-deploy.tar.gz"
$FilesToInclude = @(
    "backend",
    "frontend/dist",
    "package.json",
    "deploy-osmc.sh"
)

# Check if DeployType is docker and include docker files
if ($DeployType -eq "docker") {
    $FilesToInclude += "Dockerfile"
    $FilesToInclude += "docker-compose.yml"
}

# Create tar.gz (requires tar.exe which is built into Windows 10/11)
tar -czf $PackageName $FilesToInclude 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to create package" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Package created: $PackageName" -ForegroundColor Green

# Transfer to Raspberry Pi
Write-Host ""
Write-Host "[4/6] Transferring files to Raspberry Pi..." -ForegroundColor Blue
scp $PackageName "$PiUser@$PiHost:/home/$PiUser/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ File transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Files transferred successfully" -ForegroundColor Green

# Extract and prepare on Raspberry Pi
Write-Host ""
Write-Host "[5/6] Extracting files on Raspberry Pi..." -ForegroundColor Blue
ssh "$PiUser@$PiHost" @"
    cd /home/$PiUser
    mkdir -p media-library
    tar -xzf $PackageName -C media-library
    cd media-library
    chmod +x deploy-osmc.sh
    echo 'Files extracted successfully'
"@
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Extraction failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Files extracted on Raspberry Pi" -ForegroundColor Green

# Run deployment script on Raspberry Pi
Write-Host ""
Write-Host "[6/6] Running deployment on Raspberry Pi..." -ForegroundColor Blue
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
Write-Host ""

ssh -t "$PiUser@$PiHost" "cd /home/$PiUser/media-library && ./deploy-osmc.sh $MediaDir $DeployType"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "          Deployment Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Access your Media Library at:" -ForegroundColor Cyan
Write-Host "  http://${PiHost}:4200" -ForegroundColor White
Write-Host ""
Write-Host "To check service status:" -ForegroundColor Yellow
Write-Host "  ssh $PiUser@$PiHost 'sudo systemctl status media-library'" -ForegroundColor White
Write-Host ""

# Cleanup
Remove-Item $PackageName -Force
