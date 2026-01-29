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
    [string]$MediaDir = "/home/osmc/Apps/photos/data",
    
    [Parameter(Mandatory=$false)]
    [string]$ThumbDir = "/home/osmc/Apps/photos/thumbs",
    
    [Parameter(Mandatory=$false)]
    [string]$DbFile = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("native", "docker")]
    [string]$DeployType = "native"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Media Library - Windows to Pi Deployment            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Interactive prompts if parameters not provided
if (-not $PiHost) {
    $PiHost = Read-Host "Enter Raspberry Pi IP address or hostname"
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Pi Host: $PiHost"
Write-Host "  Pi User: $PiUser"
Write-Host "  Media Directory: $MediaDir"
if ($ThumbDir) {
    Write-Host "  Thumbnails Directory: $ThumbDir"
} else {
    Write-Host "  Thumbnails Directory: (same as app directory)"
}
if ($DbFile) {
    Write-Host "  Database File: $DbFile"
} else {
    Write-Host "  Database File: (same as app directory)"
}
Write-Host "  Deployment Type: $DeployType"
Write-Host ""

# Test SSH connection
Write-Host "[1/6] Testing SSH connection to Raspberry Pi..." -ForegroundColor Blue
try {
    ssh -o ConnectTimeout=5 -o BatchMode=yes "${PiUser}@${PiHost}" "exit" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "SSH connection failed"
    }
    Write-Host "[OK] SSH connection successful" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot connect to ${PiUser}@${PiHost}" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "  1. SSH is enabled on OSMC (via MyOSMC app)"
    Write-Host "  2. You have SSH key authentication set up OR use -PiPassword parameter"
    Write-Host "  3. The IP address/hostname is correct"
    Write-Host ""
    Write-Host "To set up SSH key authentication:" -ForegroundColor Yellow
    Write-Host "  ssh-copy-id ${PiUser}@${PiHost}"
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
    Write-Host "[ERROR] Frontend build failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend built successfully" -ForegroundColor Green

# Create deployment package
Write-Host ""
Write-Host "[3/6] Creating deployment package..." -ForegroundColor Blue
Set-Location $PSScriptRoot

$PackageName = "media-library-deploy.tar.gz"
$SkipPackageCreation = $false

# Check if package already exists
if (Test-Path $PackageName) {
    Write-Host "Package already exists: $PackageName" -ForegroundColor Yellow
    $rebuild = Read-Host "Rebuild package? (y/n)"
    if ($rebuild -ne 'y' -and $rebuild -ne 'Y') {
        Write-Host "[OK] Using existing package" -ForegroundColor Green
        $SkipPackageCreation = $true
    } else {
        Write-Host "Rebuilding package..." -ForegroundColor Yellow
    }
}

if (-not $SkipPackageCreation) {
    # Verify required directories exist
    if (-not (Test-Path "backend")) {
    Write-Host "[ERROR] backend directory not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "frontend/dist")) {
    Write-Host "[WARNING] frontend/dist not found - building frontend again..." -ForegroundColor Yellow
    Set-Location "$PSScriptRoot\frontend"
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Frontend build failed" -ForegroundColor Red
        exit 1
    }
    Set-Location $PSScriptRoot
}

# Check if required files exist
$requiredFiles = @("deploy-osmc.sh")
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "[ERROR] $file not found" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Creating archive..." -ForegroundColor Yellow

# Create a temporary directory for packaging
$tempDir = Join-Path $env:TEMP "media-library-deploy-temp"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy files, excluding node_modules, media, thumbnails
Write-Host "Copying files (excluding node_modules, media, thumbnails)..." -ForegroundColor Yellow

# Copy backend (excluding certain directories)
New-Item -ItemType Directory -Path "$tempDir\backend" -Force | Out-Null
Get-ChildItem "backend" -Directory | Where-Object { $_.Name -notin @('node_modules', 'media', 'thumbnails') } | ForEach-Object {
    Copy-Item $_.FullName -Destination "$tempDir\backend\$($_.Name)" -Recurse -Force
}
Get-ChildItem "backend" -File | Where-Object { $_.Extension -ne '.db' } | ForEach-Object {
    Copy-Item $_.FullName -Destination "$tempDir\backend\" -Force
}

# Copy pre-built frontend dist if it exists (so Pi doesn't have to rebuild)
# Note: We exclude the frontend source directory as it's not needed for deployment
if (Test-Path "frontend\dist") {
    Copy-Item "frontend\dist" -Destination "$tempDir\frontend-dist" -Recurse -Force
    Write-Host "Included pre-built frontend from frontend/dist" -ForegroundColor Green
}

# Copy deployment script
Copy-Item "deploy-osmc.sh" -Destination "$tempDir\"

# Include root package.json if it exists
if (Test-Path "package.json") {
    Copy-Item "package.json" -Destination "$tempDir\"
}

# Add docker files if docker deployment
if ($DeployType -eq "docker") {
    if (Test-Path "Dockerfile") { Copy-Item "Dockerfile" -Destination "$tempDir\" }
    if (Test-Path "docker-compose.yml") { Copy-Item "docker-compose.yml" -Destination "$tempDir\" }
}

# Compress from temp directory using tar
Write-Host "Compressing archive..." -ForegroundColor Yellow
Set-Location $tempDir
tar -czf "$PSScriptRoot\$PackageName" *
Set-Location $PSScriptRoot

# Cleanup temp directory
Remove-Item $tempDir -Recurse -Force

    if (-not (Test-Path $PackageName)) {
        Write-Host "[ERROR] Failed to create ZIP package" -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] Package created: $PackageName" -ForegroundColor Green
}

# Transfer to Raspberry Pi
Write-Host ""
Write-Host "[4/6] Transferring files to Raspberry Pi..." -ForegroundColor Blue
scp $PackageName "${PiUser}@${PiHost}:/home/${PiUser}/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] File transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Files transferred successfully" -ForegroundColor Green

# Extract and prepare on Raspberry Pi
Write-Host ""
Write-Host "[5/6] Extracting files on Raspberry Pi..." -ForegroundColor Blue

# Remove old directory if exists
ssh "${PiUser}@${PiHost}" "rm -rf /home/${PiUser}/media-library"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Could not remove old directory" -ForegroundColor Yellow
}

# Create fresh directory
ssh "${PiUser}@${PiHost}" "mkdir -p /home/${PiUser}/media-library"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create directory" -ForegroundColor Red
    exit 1
}

# Extract tar.gz - tar extracts the structure directly
ssh "${PiUser}@${PiHost}" "cd /home/${PiUser}/media-library && tar -xzf ../$PackageName"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Extraction failed" -ForegroundColor Red
    exit 1
}

# Verify extracted structure
ssh "${PiUser}@${PiHost}" "ls -la /home/${PiUser}/media-library/"

# Make deploy script executable
ssh "${PiUser}@${PiHost}" "chmod +x /home/${PiUser}/media-library/deploy-osmc.sh"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to set permissions" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Files extracted on Raspberry Pi" -ForegroundColor Green

# Run deployment script on Raspberry Pi
Write-Host ""
Write-Host "[6/6] Running deployment on Raspberry Pi..." -ForegroundColor Blue
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
Write-Host ""

ssh -t "${PiUser}@${PiHost}" "cd /home/${PiUser}/media-library; ./deploy-osmc.sh $MediaDir $ThumbDir $DbFile $DeployType"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "          Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access your Media Library at:" -ForegroundColor Cyan
Write-Host "  http://${PiHost}:4200" -ForegroundColor White
Write-Host ""
Write-Host "To check service status:" -ForegroundColor Yellow
Write-Host "  ssh ${PiUser}@${PiHost} 'sudo systemctl status media-library'" -ForegroundColor White
Write-Host ""

# Cleanup
Remove-Item $PackageName -Force
