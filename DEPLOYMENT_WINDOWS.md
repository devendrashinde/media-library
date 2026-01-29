# Windows to OSMC Deployment Guide

This guide explains how to deploy changes from your Windows development machine to the OSMC (Raspberry Pi) media library deployment.

## Prerequisites

1. **OpenSSH Client** (Windows 10/11+)
   - Built-in on Windows 10/11
   - Check: Open PowerShell and run `ssh -V`

2. **SSH Key Setup** (Optional but recommended)
   - Generate key: `ssh-keygen -t rsa -b 4096`
   - Copy to OSMC: `ssh-copy-id osmc@192.168.1.96`
   - Then you won't need to enter password each time

3. **Network Connection**
   - OSMC must be accessible from Windows on the same network

## Quick Deploy

### 1. First Time Setup

Edit `quick-deploy.ps1` and update the IP address:

```powershell
$OSMCHost = "192.168.1.96"  # Change to your OSMC IP
$OSMCUser = "osmc"           # Default OSMC username
```

### 2. Run Deployment

```powershell
# Open PowerShell in the media-library directory
cd C:\MyData\media-library

# Run the deployment
.\quick-deploy.ps1
```

You'll be prompted for the OSMC password (osmc).

## Full Deployment Script

For more control, use the full deployment script with options:

```powershell
# Deploy everything (default)
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -OSMCUser osmc

# Skip frontend build (if not changed)
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -OSMCUser osmc -SkipFrontendBuild

# Skip service restarts (for testing)
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -OSMCUser osmc -SkipBackendRestart -SkipFrontendRestart

# Deploy only backend
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -OSMCUser osmc -SkipFrontendBuild
```

## What Each Script Does

### deploy-windows-to-osmc.ps1

1. **Checks Prerequisites**
   - Verifies Node.js, npm, and SSH are installed
   - Tests SSH connection to OSMC

2. **Builds Frontend**
   - Runs `npm install` and `npm run build`
   - Creates optimized dist files

3. **Deploys Backend**
   - Uploads `app.js`, `package.json`, `start.sh`
   - These contain your latest code changes

4. **Deploys Frontend**
   - Uploads all built frontend files
   - Syncs to frontend-dist directory

5. **Installs Dependencies**
   - Runs `npm install` on OSMC
   - Ensures all packages are ARM-compatible

6. **Restarts Services**
   - Restarts backend and frontend services
   - Waits for services to stabilize

## Troubleshooting

### SSH Connection Failed

```powershell
# Test SSH connection manually
ssh osmc@192.168.1.96 "echo test"
```

If this fails:
1. Check OSMC is on network
2. Check IP address is correct
3. Check password is "osmc"
4. Ensure SSH is enabled on OSMC

### npm install Fails on OSMC

This usually means missing build tools. SSH to OSMC and run:

```bash
sudo apt-get update
sudo apt-get install -y build-essential python3
```

### Services Don't Start After Deploy

Check the logs:

```powershell
ssh osmc@192.168.1.96 "sudo journalctl -u media-library-backend -n 50"
ssh osmc@192.168.1.96 "sudo journalctl -u media-library-frontend -n 50"
```

### Files Not Syncing

The script copies files individually. For faster syncing, ensure:
1. Network connection is stable
2. SSH connection is fast
3. No firewall blocking scp transfers

## Common Workflows

### Deploy Only Backend Changes

```powershell
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -SkipFrontendBuild -SkipFrontendRestart
```

### Deploy Only Frontend Changes

```powershell
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -SkipBackendRestart
```

### Test Build Without Restarting Services

```powershell
.\deploy-windows-to-osmc.ps1 -OSMCHost 192.168.1.96 -SkipBackendRestart -SkipFrontendRestart
```

### Manual SSH for Debugging

```powershell
# SSH into OSMC
ssh osmc@192.168.1.96

# Check backend status
sudo systemctl status media-library-backend

# View backend logs
sudo journalctl -u media-library-backend -f

# Restart backend
sudo systemctl restart media-library-backend

# Check running processes
ps aux | grep node
```

## File Structure

```
media-library/
├── deploy-windows-to-osmc.ps1    ← Full deployment script
├── quick-deploy.ps1              ← Quick deployment shortcut
├── backend/
│   ├── app.js                     ← Main application
│   ├── package.json               ← Dependencies
│   ├── start.sh                   ← Startup script
│   └── .env                       ← Configuration (local, not synced)
├── frontend/
│   ├── src/                       ← Source code
│   ├── angular.json               ← Build config
│   ├── package.json               ← Dependencies
│   └── dist/                      ← Built files (created by npm run build)
└── frontend-dist/                 ← Served on OSMC (created by deploy script)
```

## Notes

- **.env files are NOT synced** - Update them manually on OSMC if needed
- **node_modules are NOT synced** - Rebuilt on OSMC using `npm install`
- **thumbnails and database** are never touched - Only code files are deployed
- **Media files** are never touched - Only backend/frontend code

## After Deployment

1. **Verify Services**
   ```powershell
   ssh osmc@192.168.1.96 "sudo systemctl status media-library-backend"
   ssh osmc@192.168.1.96 "sudo systemctl status media-library-frontend"
   ```

2. **Test Frontend**
   - Open: http://192.168.1.96:4200
   - Check browser console for errors

3. **Test Backend API**
   ```powershell
   curl http://192.168.1.96:3000/albums
   ```

4. **Trigger Scan** (if backend changed)
   ```powershell
   curl -X POST http://192.168.1.96:3000/scan/album/photos
   ```

## Performance Tips

- Use SSH keys to avoid password prompts
- Deploy during off-hours to avoid interfering with scanning
- Monitor OSMC resources during long deploys with large frontend builds
- Consider running slow builds on Windows, then just upload dist files

## Getting Help

If deployment fails:

1. Check the error message carefully
2. Verify SSH connection works: `ssh osmc@192.168.1.96 "echo test"`
3. Check OSMC logs: `ssh osmc@192.168.1.96 "sudo journalctl -u media-library-backend -n 100"`
4. Run deployment with verbose output to see all steps

## Security Note

These scripts use SSH with password authentication by default. For production:

1. Set up SSH keys (recommended)
2. Disable password authentication on OSMC
3. Consider restricting SSH to specific ports
4. Use firewall rules to limit SSH access to trusted IPs
