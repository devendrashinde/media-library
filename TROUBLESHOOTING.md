# Media Library - Troubleshooting Guide

## Common Deployment Issues

### Platform Not Supported (Linux NOT supported)

**Error:**
```
linux is NOT supported
```

**Cause:** 
The `pdf-poppler` package is Windows-only and was causing the error when imported on Linux. This has been fixed in the latest version.

**Solution:**
Ensure you have the latest backend code:
1. Pull the latest changes
2. Delete `node_modules`: `rm -rf ~/media-library/backend/node_modules`
3. Reinstall dependencies: `npm install --production`

The app should now start without platform errors.

---

### App Gets Killed During Initial Scan (Large Media Libraries)

**Symptom:**
```
[WATCHER] Watching: /path/to/media
Killed
```

**Cause:**
The app runs out of memory (OOM) during the initial scan of a large media library. With thousands of files, the initial indexing process consumes too much RAM and the system terminates it.

**Solution 1 - Disable Auto-Scan on Startup (Recommended for 10,000+ files):**

Edit `.env` file:
```bash
nano ~/media-library/backend/.env
```

Add this line:
```
AUTO_SCAN_ON_STARTUP=false
SCAN_BATCH_SIZE=25
SCAN_DELAY_MS=200
```

Restart the app:
```bash
sudo systemctl restart media-library-backend
```

The app will start immediately without scanning. Then trigger scan manually:
```bash
# Trigger scan via API
curl -X POST http://localhost:3000/scan

# Check scan progress
curl http://localhost:3000/scan/status
```

**Solution 2 - Increase Node Heap Size:**

Edit the systemd service:
```bash
sudo nano /etc/systemd/system/media-library-backend.service
```

Find the `Environment` line and update it:
```ini
Environment="NODE_OPTIONS=--max-old-space-size=2048 --expose-gc"
```

For Raspberry Pi with limited RAM:
- 512 MB: `--max-old-space-size=256`
- 1 GB: `--max-old-space-size=512`
- 2 GB: `--max-old-space-size=1024`
- 4 GB: `--max-old-space-size=2048`

Then restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart media-library-backend
```

**Solution 3 - Increase Swap Space (if needed):**

```bash
# Create swap file (2 GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Monitor Scan Progress:**

```bash
# View logs
sudo journalctl -u media-library-backend -f

# Or check via API
watch -n 2 'curl -s http://localhost:3000/scan/status | python3 -m json.tool'
```

**Configuration for Different Library Sizes:**

Edit `.env` and choose based on your library size:

```bash
# Small library (< 1000 files)
AUTO_SCAN_ON_STARTUP=true
SCAN_BATCH_SIZE=100
SCAN_DELAY_MS=0

# Medium library (1000-10000 files)
AUTO_SCAN_ON_STARTUP=true
SCAN_BATCH_SIZE=50
SCAN_DELAY_MS=0

# Large library (10000-50000 files)
AUTO_SCAN_ON_STARTUP=false
SCAN_BATCH_SIZE=50
SCAN_DELAY_MS=100

# Huge library (50000+ files)
AUTO_SCAN_ON_STARTUP=false
SCAN_BATCH_SIZE=25
SCAN_DELAY_MS=200
```

---

### Backend API 404 / CORS Errors

**Symptoms:**
- Frontend returns 404 when accessing `/api/albums`
- Browser console shows CORS errors
- Backend is running but frontend can't reach it

**Cause:**
The frontend is being served as static files (via http-server) and doesn't know where the backend API is located. On `localhost:4200`, it assumes the API is also on `localhost:4200`.

**Solution:**

1. **Rebuild the frontend** to use the new environment configuration:
   ```bash
   cd ~/media-library/frontend
   npm run build
   ```

2. **Copy the built files to the deployment location:**
   ```bash
   rm -rf ~/media-library/frontend-dist/*
   cp -r dist/media-frontend/* ~/media-library/frontend-dist/
   ```

3. **Restart both services:**
   ```bash
   sudo systemctl restart media-library-backend media-library-frontend
   ```

The frontend now automatically detects the current hostname and connects to the backend on `http://<hostname>:3000`.

**Testing:**
- Access frontend: `http://192.168.1.96:4200`
- The browser's JavaScript will request API from: `http://192.168.1.96:3000`

---

### File Watcher Limit Reached (ENOSPC)

**Error:**
```
Error: ENOSPC: System limit for number of file watchers reached
```

**Cause:**
Linux systems have a limit on the number of inotify file watches. Large media libraries with thousands of files exceed this limit (usually 8,192 by default).

**Solution 1 - Increase System Limit (Recommended):**

```bash
# Temporarily increase the limit
sudo sysctl -w fs.inotify.max_user_watches=524288

# Make it permanent
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf

# Reload sysctl settings
sudo sysctl -p
```

**Solution 2 - Enable Polling Mode (Slower, but works without limit):**

Edit `backend/app.js` and uncomment the `usePolling: true` line in the watcher config:

```javascript
const watcher = chokidar.watch(MEDIA_DIR_ABS, {
  persistent: true,
  usePolling: true,  // <-- Uncomment this line
  interval: 2000,
  // ... rest of config
});
```

Then restart the app. Polling is slower but doesn't have system limits.

**Solution 3 - Check Current Limit:**

```bash
# View current limit
cat /proc/sys/fs/inotify/max_user_watches

# View maximum possible limit
cat /proc/sys/fs/inotify/max_queued_events
```

The deployment script (`deploy-osmc.sh`) automatically increases this limit to 524,288 watches.

---

### Media Directory Not Found (ENOENT)

**Error:**
```
Error: ENOENT: no such file or directory, scandir '/home/osmc/media-library/backend/media'
```

**Cause:**
The MEDIA_DIR environment variable points to a directory that doesn't exist yet. By default it's `./media` which resolves to the backend directory.

**Solution:**
Set the correct media directory in your `.env` file before starting the app:

```bash
# Edit the .env file
nano ~/media-library/backend/.env

# Make sure MEDIA_DIR points to an existing directory:
# MEDIA_DIR=/home/osmc/Videos
# or
# MEDIA_DIR=/mnt/nas/media

# Save and exit (Ctrl+X, Y, Enter)
# Then restart the app:
node app.js
```

**Or create the media directory if you want to use the default location:**
```bash
mkdir -p ~/media-library/backend/media
node app.js
```

The app will now start and watch the media directory for changes.

---

### SQLite3 Native Bindings Error on OSMC/Raspberry Pi

**Error:**
```
Error: Could not locate the bindings file. Tried:
 → /home/osmc/media-library/backend/node_modules/sqlite3/lib/binding/node-v108-linux-arm/node_sqlite3.node
```

**Cause:** 
The `sqlite3` module is a native Node.js addon that must be compiled for the target platform. If you deployed files from Windows to ARM Linux (Raspberry Pi), the Windows binaries won't work.

**Solution 1 - Rebuild sqlite3 (Quick Fix):**
```bash
cd ~/media-library/backend
npm rebuild sqlite3 --build-from-source
```

**Solution 2 - Fresh Install (Recommended):**
```bash
cd ~/media-library/backend

# Remove Windows-compiled modules
rm -rf node_modules package-lock.json

# Install build tools if needed
sudo apt-get update
sudo apt-get install -y build-essential python3

# Reinstall all dependencies (will compile for ARM)
npm install
```

**Solution 3 - Use Updated Deployment Script:**
The latest `deploy-osmc.sh` script automatically handles this:
```bash
./deploy-osmc.sh
```

**Prevention:**
- Always use the deployment script when deploying from Windows to OSMC
- The script automatically removes `node_modules` and rebuilds for ARM architecture
- Never copy `node_modules` folder from Windows to Linux

---

### Node.js Version Mismatch

**Error:**
```
Error: The module was compiled against a different Node.js version
```

**Solution:**
```bash
# Check Node version
node --version

# Should be v18.x or higher
# If not, upgrade:
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Rebuild native modules for new Node version
cd ~/media-library/backend
npm rebuild
```

---

### FFMPEG Not Found

**Error:**
```
Error: spawn ffmpeg ENOENT
```

**Solution:**
```bash
# Install ffmpeg
sudo apt-get update
sudo apt-get install -y ffmpeg

# Verify installation
ffmpeg -version
```

---

### Port Already in Use

**Error:**
```
Error: listen EADDRINUSE: address already in use :::3000
```

**Solution:**
```bash
# Find process using port 3000
sudo lsof -i :3000

# Kill the process
sudo kill -9 <PID>

# Or use a different port in backend/.env
echo "PORT=3001" >> backend/.env
```

---

### Permission Denied Errors

**Error:**
```
EACCES: permission denied, mkdir '/opt/media-library/thumbnails'
```

**Solution:**
```bash
# Fix ownership
sudo chown -R osmc:osmc ~/media-library

# Fix permissions
chmod -R 755 ~/media-library

# Create directories with proper permissions
mkdir -p ~/media-library/thumbnails
mkdir -p ~/media-library/logs
chmod 755 ~/media-library/thumbnails ~/media-library/logs
```

---

### Database Locked Error

**Error:**
```
Error: SQLITE_BUSY: database is locked
```

**Solution:**
```bash
# Stop all services
sudo systemctl stop media-library-backend

# Check for zombie processes
ps aux | grep node

# Kill any remaining node processes
pkill -9 node

# Restart service
sudo systemctl start media-library-backend
```

---

### Out of Memory During Build

**Error:**
```
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
```

**Solution:**
```bash
# Increase Node.js heap size
export NODE_OPTIONS="--max-old-space-size=512"

# Then retry the build/install
npm install
```

Or build the frontend on a more powerful machine and deploy the built files.

---

### Frontend Not Loading / 404 Errors

**Symptoms:**
- Backend works but frontend shows 404
- Static files not found

**Solution:**
```bash
# Verify frontend files exist
ls -la ~/media-library/frontend-dist/

# Should see index.html, main.*.js, etc.

# If empty, rebuild frontend:
cd ~/media-library/frontend
npm install
npm run build

# Copy to deployment location
cp -r dist/media-frontend/* ~/media-library/frontend-dist/

# Restart frontend service
sudo systemctl restart media-library-frontend
```

---

### Backend API CORS Errors

**Error in browser console:**
```
Access to fetch at 'http://localhost:3000/api/media' from origin 'http://localhost:4200' has been blocked by CORS policy
```

**Solution:**
This should be handled by the backend. Check that `app.js` has CORS enabled:

```javascript
// In backend/app.js
const cors = require('cors');
app.use(cors());
```

If still having issues, check frontend proxy configuration in `proxy.conf.json`.

---

## Service Management Commands

```bash
# Check service status
sudo systemctl status media-library-backend
sudo systemctl status media-library-frontend

# View logs
sudo journalctl -u media-library-backend -f
sudo journalctl -u media-library-frontend -f

# Or use log files:
tail -f ~/media-library/logs/backend.log
tail -f ~/media-library/logs/frontend.log

# Restart services
sudo systemctl restart media-library-backend
sudo systemctl restart media-library-frontend

# Stop services
sudo systemctl stop media-library-backend
sudo systemctl stop media-library-frontend

# Disable auto-start
sudo systemctl disable media-library-backend
```

---

## Database Management

### View Database Contents
```bash
# Install sqlite3 CLI
sudo apt-get install sqlite3

# Open database
sqlite3 ~/media-library/media.db

# List tables
.tables

# View media entries
SELECT * FROM media LIMIT 10;

# Exit
.quit
```

### Rebuild Database
```bash
# Backup current database
cp ~/media-library/media.db ~/media-library/media.db.backup

# Remove database (will be recreated on next scan)
rm ~/media-library/media.db

# Restart backend to trigger rebuild
sudo systemctl restart media-library-backend

# Check logs to see scan progress
tail -f ~/media-library/logs/backend.log
```

---

## Network Access Issues

### Can't Access from Other Devices

**Solution:**
```bash
# Check OSMC firewall (if enabled)
sudo ufw status

# Allow ports
sudo ufw allow 3000
sudo ufw allow 4200

# Or check iptables
sudo iptables -L

# Find OSMC IP address
hostname -I

# Access from browser on another device:
# http://<OSMC-IP>:4200
```

### Set Up Nginx Reverse Proxy (Optional)

This allows access via port 80 without port numbers:

```bash
# Install nginx
sudo apt-get install -y nginx

# Create config
sudo tee /etc/nginx/sites-available/media-library > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        proxy_pass http://localhost:4200;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Enable and restart
sudo ln -sf /etc/nginx/sites-available/media-library /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## Getting Help

If you encounter an issue not listed here:

1. **Check logs first:**
   ```bash
   sudo journalctl -u media-library-backend -n 50
   tail -f ~/media-library/logs/backend.log
   ```

2. **Check system resources:**
   ```bash
   htop  # or: top
   df -h  # disk space
   free -h  # memory
   ```

3. **Verify configuration:**
   ```bash
   cat ~/media-library/backend/.env
   ```

4. **Test backend directly:**
   ```bash
   curl http://localhost:3000/api/media
   ```
