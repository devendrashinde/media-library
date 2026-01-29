# Media Library - Windows to OSMC Deployment Script
# This script builds and deploys changes from Windows to OSMC Raspberry Pi
# 
# Usage: .\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -OSMCUser osmc
#

param(
    [Parameter(Mandatory=$true, HelpMessage="OSMC IP or hostname (e.g., 192.168.1.96)")]
    [string]$OSMCHost,
    
    [Parameter(Mandatory=$false, HelpMessage="OSMC username (default: osmc)")]
    [string]$OSMCUser = "osmc",
    
    [Parameter(Mandatory=$false, HelpMessage="Deploy path on OSMC (default: /home/osmc/media-library)")]
    [string]$DeployPath = "/home/osmc/media-library",
    
    [Parameter(Mandatory=$false, HelpMessage="Skip frontend rebuild")]
    [switch]$SkipFrontendBuild,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip backend restart")]
    [switch]$SkipBackendRestart,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip frontend restart")]
    [switch]$SkipFrontendRestart
)

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host "ERROR: $args" -ForegroundColor Red }
function Write-Warning { Write-Host "WARNING: $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "INFO: $args" -ForegroundColor Cyan }

# Check prerequisites
function Check-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Node.js
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Error "Node.js not found. Please install Node.js v18+"
        exit 1
    }
    $nodeVersion = node -v
    Write-Success "Found Node.js: $nodeVersion"
    
    # Check npm
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm not found"
        exit 1
    }
    
    # Check OpenSSH (for ssh/scp)
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-Error "SSH not found. Please install OpenSSH or Git Bash"
        exit 1
    }
    
    Write-Success "All prerequisites met"
}

# Test SSH connection
function Test-SSHConnection {
    Write-Info "Testing SSH connection to $OSMCHost..."
    try {
        ssh -o BatchMode=yes -o ConnectTimeout=5 "$OSMCUser@$OSMCHost" "echo 'SSH connection successful'" | Out-Null
        Write-Success "SSH connection successful"
        return $true
    } catch {
        Write-Error "SSH connection failed to $OSMCUser@$OSMCHost"
        exit 1
    }
}

# Build frontend
function Build-Frontend {
    if ($SkipFrontendBuild) {
        Write-Info "Skipping frontend build (--SkipFrontendBuild)"
        return
    }
    
    Write-Info "Building frontend..."
    
    # Navigate to frontend directory
    $frontendPath = Join-Path (Get-Location) "frontend"
    if (-not (Test-Path $frontendPath)) {
        Write-Error "Frontend directory not found at $frontendPath"
        exit 1
    }
    
    Push-Location $frontendPath
    
    try {
        # Install dependencies
        Write-Info "Installing frontend dependencies..."
        npm install --silent
        if ($LASTEXITCODE -ne 0) {
            Write-Error "npm install failed"
            exit 1
        }
        
        # Build
        Write-Info "Running frontend build..."
        npm run build --silent
        if ($LASTEXITCODE -ne 0) {
            Write-Error "npm run build failed"
            exit 1
        }
        
        Write-Success "Frontend built successfully"
    } finally {
        Pop-Location
    }
}

# Deploy backend
function Deploy-Backend {
    Write-Info "Deploying backend to OSMC..."
    
    $backendLocal = Join-Path (Get-Location) "backend"
    $backendRemote = "$OSMCUser@$OSMCHost`:$DeployPath/backend"
    
    # Files to sync (exclude node_modules, .env local overrides)
    Write-Info "Syncing backend files..."
    
    # Sync app.js and other core files
    $filesToSync = @(
        "app.js",
        "package.json",
        "start.sh"
    )
    
    foreach ($file in $filesToSync) {
        $localFile = Join-Path $backendLocal $file
        if (Test-Path $localFile) {
            Write-Info "Uploading $file..."
            scp -q "$localFile" "$backendRemote/"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to upload $file"
                exit 1
            }
        }
    }
    
    Write-Success "Backend files deployed"
}

# Deploy frontend
function Deploy-Frontend {
    Write-Info "Deploying frontend to OSMC..."
    
    $distPath = Join-Path (Get-Location) "frontend\dist\media-frontend"
    
    if (-not (Test-Path $distPath)) {
        Write-Error "Frontend dist directory not found at $distPath"
        Write-Info "Make sure frontend was built with 'npm run build'"
        exit 1
    }
    
    Write-Info "Syncing frontend dist files (this may take a moment)..."
    
    # Create remote directory if it doesn't exist
    ssh "$OSMCUser@$OSMCHost" "mkdir -p $DeployPath/frontend-dist"
    
    # Sync dist files
    $distRemote = "$OSMCUser@$OSMCHost`:$DeployPath/frontend-dist"
    
    # Use rsync-like behavior with scp for directory sync
    # Copy everything from dist to remote
    ssh "$OSMCUser@$OSMCHost" "rm -rf $DeployPath/frontend-dist/*"
    
    # Get all files in dist directory
    $files = Get-ChildItem -Path $distPath -Recurse -File
    
    Write-Info "Uploading $($files.Count) files..."
    
    $count = 0
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($distPath.Length + 1)
        $remoteFile = "$OSMCUser@$OSMCHost`:$DeployPath/frontend-dist/$relative"
        
        # Create remote directory if needed
        $remoteDir = Split-Path $remoteFile
        ssh "$OSMCUser@$OSMCHost" "mkdir -p '$remoteDir'"
        
        scp -q "$($file.FullName)" "$remoteFile"
        
        $count++
        if ($count % 20 -eq 0) {
            Write-Info "Uploaded $count/$($files.Count) files..."
        }
    }
    
    Write-Success "Frontend files deployed ($($files.Count) files)"
}

# Install dependencies on OSMC
function Install-OSMCDependencies {
    Write-Info "Installing dependencies on OSMC backend..."
    
    ssh "$OSMCUser@$OSMCHost" @"
        cd $DeployPath/backend
        if [ -d "node_modules" ]; then
            echo "Removing existing node_modules..."
            rm -rf node_modules
        fi
        echo "Installing npm dependencies..."
        npm install --production --silent
        if [ `$? -ne 0 ]; then
            echo "ERROR: npm install failed"
            exit 1
        fi
        echo "Dependencies installed successfully"
"@
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install dependencies on OSMC"
        exit 1
    }
    
    Write-Success "Dependencies installed on OSMC"
}

# Restart services
function Restart-Services {
    Write-Info "Restarting services on OSMC..."
    
    if (-not $SkipBackendRestart) {
        Write-Info "Restarting backend service..."
        ssh "$OSMCUser@$OSMCHost" "sudo systemctl restart media-library-backend"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Backend service restarted"
        } else {
            Write-Warning "Failed to restart backend service"
        }
    }
    
    if (-not $SkipFrontendRestart) {
        Write-Info "Restarting frontend service..."
        ssh "$OSMCUser@$OSMCHost" "sudo systemctl restart media-library-frontend"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Frontend service restarted"
        } else {
            Write-Warning "Failed to restart frontend service"
        }
    }
    
    # Wait for services to start
    Write-Info "Waiting for services to start..."
    Start-Sleep -Seconds 3
    
    # Check service status
    Write-Info "Checking service status..."
    ssh "$OSMCUser@$OSMCHost" @"
        echo "=== Backend Status ==="
        sudo systemctl is-active media-library-backend
        echo ""
        echo "=== Frontend Status ==="
        sudo systemctl is-active media-library-frontend
"@
}

# Main deployment flow
function Main {
    Write-Info "========================================="
    Write-Info "Media Library - Windows to OSMC Deploy"
    Write-Info "========================================="
    Write-Info "Target: $OSMCHost ($OSMCUser)"
    Write-Info "Deploy Path: $DeployPath"
    Write-Info ""
    
    Check-Prerequisites
    Test-SSHConnection
    Build-Frontend
    Deploy-Backend
    Deploy-Frontend
    Install-OSMCDependencies
    Restart-Services
    
    Write-Info ""
    Write-Success "========================================="
    Write-Success "Deployment completed successfully!"
    Write-Success "========================================="
    Write-Info ""
    Write-Info "Frontend: http://$OSMCHost:4200"
    Write-Info "Backend API: http://$OSMCHost:3000"
    Write-Info ""
    Write-Info "View logs:"
    Write-Info "  Backend: ssh $OSMCUser@$OSMCHost 'sudo journalctl -u media-library-backend -f'"
    Write-Info "  Frontend: ssh $OSMCUser@$OSMCHost 'sudo journalctl -u media-library-frontend -f'"
}

# Run main
Main
