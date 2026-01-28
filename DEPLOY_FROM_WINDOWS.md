# Deploying from Windows to Raspberry Pi OSMC

## Prerequisites

### On Windows Machine:
- ✅ Node.js and npm installed
- ✅ SSH client (built into Windows 10/11)
- ✅ Network access to Raspberry Pi

### On Raspberry Pi OSMC:
- ✅ SSH enabled (via MyOSMC app → Services → SSH)
- ✅ Network connection
- ✅ Sufficient storage space

## Quick Start

### Step 1: Set up SSH Access (One-time setup)

First, test SSH connection:
```powershell
ssh osmc@192.168.1.XXX
# Default password is "osmc"
```

**Optional but recommended:** Set up SSH key authentication to avoid password prompts:
```powershell
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096

# Copy key to Raspberry Pi
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh osmc@192.168.1.XXX "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Step 2: Run the Deployment Script

From PowerShell in the project directory:

```powershell
cd C:\MyData\media-library

# Replace 192.168.1.XXX with your Pi's IP address
.\deploy-to-pi.ps1 -PiHost 192.168.1.XXX -PiUser osmc -MediaDir /home/osmc/Videos -DeployType native
```

**Interactive Mode** (script will ask for details):
```powershell
.\deploy-to-pi.ps1
```

### What the Script Does:

1. ✅ Tests SSH connection to Raspberry Pi
2. ✅ Builds the Angular frontend on Windows
3. ✅ Creates deployment package (.tar.gz)
4. ✅ Transfers files to Raspberry Pi via SCP
5. ✅ Extracts files on Raspberry Pi
6. ✅ Runs the deployment script on Raspberry Pi

## Manual Deployment (Alternative Method)

If you prefer manual control:

### 1. Build Frontend on Windows
```powershell
cd C:\MyData\media-library\frontend
npm install
npm run build
```

### 2. Create Package
```powershell
cd C:\MyData\media-library
tar -czf media-library.tar.gz backend frontend/dist package.json deploy-osmc.sh
```

### 3. Transfer to Raspberry Pi
```powershell
scp media-library.tar.gz osmc@192.168.1.XXX:/home/osmc/
```

### 4. SSH into Pi and Deploy
```powershell
ssh osmc@192.168.1.XXX
```

Then on the Pi:
```bash
cd /home/osmc
tar -xzf media-library.tar.gz
cd media-library
chmod +x deploy-osmc.sh
./deploy-osmc.sh /home/osmc/Videos native
```

## Deployment Options

### Native Deployment (Recommended for Pi)
```powershell
.\deploy-to-pi.ps1 -PiHost 192.168.1.XXX -DeployType native
```
- Installs directly on OSMC
- Uses systemd service
- Lower resource usage
- Better for Raspberry Pi performance

### Docker Deployment
```powershell
.\deploy-to-pi.ps1 -PiHost 192.168.1.XXX -DeployType docker
```
- Uses Docker containers
- Easier updates
- More resource intensive
- Requires Docker installed on Pi

## Troubleshooting

### SSH Connection Issues

**Error: "Connection refused"**
- Enable SSH in OSMC: MyOSMC → Services → SSH → Enable
- Check Pi is on network: `ping 192.168.1.XXX`

**Error: "Permission denied"**
- Verify username (default is `osmc`)
- Check password (default is `osmc`)
- Try: `ssh osmc@192.168.1.XXX` and enter password manually

### Build Issues

**Error: "npm not found"**
```powershell
# Install Node.js from https://nodejs.org/
# Or use Chocolatey:
choco install nodejs
```

**Error: "tar not found"**
- Windows 10/11 has tar built-in
- Update Windows or use WSL

### Deployment Issues

**Error: "Port 4200 already in use"**
```bash
# SSH into Pi and check:
ssh osmc@192.168.1.XXX
sudo systemctl stop media-library
sudo systemctl start media-library
```

**Error: "Cannot find media directory"**
```bash
# SSH into Pi and create directory:
ssh osmc@192.168.1.XXX
mkdir -p /home/osmc/Videos
```

## Updating the Application

To update after making changes on Windows:

```powershell
# Simply re-run the deployment script
.\deploy-to-pi.ps1 -PiHost 192.168.1.XXX
```

The script will:
- Rebuild frontend with your changes
- Transfer updated files
- Restart the service

## Finding Your Raspberry Pi IP Address

### Method 1: From OSMC
1. Go to Settings → System Info → Network
2. Note the IP address

### Method 2: From Windows
```powershell
# Scan your network (if you have nmap)
nmap -sn 192.168.1.0/24 | grep osmc

# Or check your router's DHCP client list
```

### Method 3: From Router
- Log into your router admin panel
- Look for "DHCP Clients" or "Connected Devices"
- Find device named "osmc" or "raspberrypi"

## Post-Deployment

After successful deployment, access your media library:

```
http://192.168.1.XXX:4200
```

To check service status:
```powershell
ssh osmc@192.168.1.XXX "sudo systemctl status media-library"
```

To view logs:
```powershell
ssh osmc@192.168.1.XXX "sudo journalctl -u media-library -f"
```

## Tips

1. **Set Static IP**: Configure your Pi with a static IP in your router to avoid IP changes
2. **Bookmark**: Add http://pi-ip:4200 to your browser favorites
3. **Hostname**: Set up hostname resolution so you can use `http://osmc.local:4200`
4. **Autostart**: The service is configured to start automatically on boot
5. **Updates**: Re-run deployment script whenever you make changes on Windows

## Support

If deployment fails, check:
1. SSH connection works: `ssh osmc@192.168.1.XXX`
2. Node.js installed on Windows: `node --version`
3. Raspberry Pi has internet: `ssh osmc@192.168.1.XXX "ping -c 3 google.com"`
4. Sufficient disk space: `ssh osmc@192.168.1.XXX "df -h"`
