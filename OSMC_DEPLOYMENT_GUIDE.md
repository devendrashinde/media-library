# Media Library - OSMC Linux Deployment Guide

## Prerequisites

OSMC is based on Debian/Linux. You'll need:

```bash
# Update package manager
sudo apt-get update
sudo apt-get upgrade

# Install Node.js (v18 or higher)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install ffmpeg (for video thumbnail generation)
sudo apt-get install -y ffmpeg

# Install imagemagick or graphicsmagick (optional, for image processing)
sudo apt-get install -y graphicsmagick

# Verify installations
node --version    # Should be v18+
npm --version     # Should be v9+
ffmpeg -version   # Should show version
```

## Step 1: Build the Frontend

The Angular frontend needs to be built into static files:

```bash
# On your development machine (or OSMC if it has enough resources)
cd frontend

# Build for production
npm install
npm run build

# This creates a 'dist/media-frontend' folder with static files
```

## Step 2: Prepare OSMC Directories

```bash
# Create application directory
sudo mkdir -p /opt/media-library
sudo chown $USER:$USER /opt/media-library

# Create subdirectories
mkdir -p /opt/media-library/backend
mkdir -p /opt/media-library/frontend-dist
mkdir -p /opt/media-library/media
mkdir -p /opt/media-library/thumbnails
mkdir -p /opt/media-library/logs

cd /opt/media-library
```

## Step 3: Deploy Backend

```bash
# Copy backend files
cp -r backend/* /opt/media-library/backend/

# Install dependencies
cd /opt/media-library/backend
npm install --production

# Create production .env file
cat > .env << 'EOF'
PORT=3000
NODE_ENV=production
MEDIA_DIR=/home/osmc/Videos
THUMB_DIR=/opt/media-library/thumbnails
DB_FILE=/opt/media-library/media.db
EOF

# Adjust MEDIA_DIR to your actual media location
# Common locations:
# - /home/osmc/Videos
# - /home/osmc/Music
# - /mnt/nas/media (if using NAS)
```

## Step 4: Deploy Frontend

```bash
# Copy built frontend files
cp -r frontend/dist/media-frontend/* /opt/media-library/frontend-dist/

# Verify index.html exists
ls -la /opt/media-library/frontend-dist/index.html
```

## Step 5: Create Systemd Service Files

### Backend Service: `/etc/systemd/system/media-library-backend.service`

```bash
sudo tee /etc/systemd/system/media-library-backend.service > /dev/null << 'EOF'
[Unit]
Description=Media Library Backend Service
After=network.target

[Service]
Type=simple
User=osmc
WorkingDirectory=/opt/media-library/backend
ExecStart=/usr/bin/node /opt/media-library/backend/app.js
Restart=always
RestartSec=10
StandardOutput=append:/opt/media-library/logs/backend.log
StandardError=append:/opt/media-library/logs/backend.log

# Environment variables
Environment="NODE_ENV=production"
Environment="PORT=3000"

[Install]
WantedBy=multi-user.target
EOF
```

### Frontend Service (using Express Static): Create `/opt/media-library/frontend-server.js`

```javascript
const express = require('express');
const path = require('path');
const app = express();

// Serve static files from dist folder
app.use(express.static(path.join(__dirname, 'frontend-dist')));

// Redirect all routes to index.html (Angular routing)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'frontend-dist/index.html'));
});

const PORT = process.env.FRONTEND_PORT || 4200;
app.listen(PORT, () => {
  console.log(`✅ Frontend running at http://localhost:${PORT}`);
});
```

### Frontend Service: `/etc/systemd/system/media-library-frontend.service`

```bash
sudo tee /etc/systemd/system/media-library-frontend.service > /dev/null << 'EOF'
[Unit]
Description=Media Library Frontend Service
After=network.target

[Service]
Type=simple
User=osmc
WorkingDirectory=/opt/media-library
ExecStart=/usr/bin/node /opt/media-library/frontend-server.js
Restart=always
RestartSec=10
StandardOutput=append:/opt/media-library/logs/frontend.log
StandardError=append:/opt/media-library/logs/frontend.log

Environment="FRONTEND_PORT=4200"

[Install]
WantedBy=multi-user.target
EOF
```

## Step 6: Enable and Start Services

```bash
# Reload systemd daemon
sudo systemctl daemon-reload

# Enable services to start on boot
sudo systemctl enable media-library-backend
sudo systemctl enable media-library-frontend

# Start services
sudo systemctl start media-library-backend
sudo systemctl start media-library-frontend

# Check status
sudo systemctl status media-library-backend
sudo systemctl status media-library-frontend

# View logs
tail -f /opt/media-library/logs/backend.log
tail -f /opt/media-library/logs/frontend.log
```

## Step 7: Configure Nginx Reverse Proxy (Optional but Recommended)

If you want to serve both backend and frontend on the same port:

### Install Nginx
```bash
sudo apt-get install -y nginx
```

### Create Nginx Config: `/etc/nginx/sites-available/media-library`

```nginx
upstream backend {
    server localhost:3000;
}

upstream frontend {
    server localhost:4200;
}

server {
    listen 80;
    server_name localhost;

    # Frontend
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        # Angular routing
        try_files $uri /index.html;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://backend/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Thumbnails
    location /thumbnails/ {
        proxy_pass http://backend/thumbnails/;
        proxy_cache_valid 200 30d;
        expires 30d;
    }

    # Media streaming
    location /media/ {
        proxy_pass http://backend/media/;
        proxy_http_version 1.1;
        proxy_set_header Range $http_range;
        proxy_set_header If-Range $http_if_range;
        proxy_request_buffering off;
    }
}
```

### Enable Nginx
```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/media-library /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Now access at http://your-osmc-ip:80
```

## Step 8: Adjust Frontend API URL

Update the frontend API URL to use the new proxy:

### File: `frontend/src/environments/environment.prod.ts`

```typescript
export const environment = {
  production: true,
  apiUrl: '/api'  // Uses same-origin proxy
};
```

Rebuild frontend:
```bash
cd frontend
npm run build
cp -r dist/media-frontend/* /opt/media-library/frontend-dist/
sudo systemctl restart media-library-frontend
```

## Step 9: File Permissions

```bash
# Ensure OSMC user can access media
sudo chown -R osmc:osmc /opt/media-library
sudo chmod -R 755 /opt/media-library

# If media is elsewhere, ensure read permissions
sudo usermod -aG video osmc  # For media playback permissions
```

## Step 10: Firewall Configuration (if needed)

```bash
# Allow ports through firewall
sudo ufw allow 80/tcp      # Nginx
sudo ufw allow 3000/tcp    # Backend (if accessing directly)
sudo ufw allow 4200/tcp    # Frontend (if accessing directly)

# Or disable firewall for local network
sudo ufw disable  # Not recommended for public networks
```

---

# Complete Deployment Script

Create `/opt/media-library/deploy.sh`:

```bash
#!/bin/bash

set -e

MEDIA_LIBRARY_DIR="/opt/media-library"
MEDIA_DIR="${1:-/home/osmc/Videos}"

echo "🚀 Deploying Media Library to OSMC"

# Create directories
echo "📁 Creating directories..."
sudo mkdir -p $MEDIA_LIBRARY_DIR/{backend,frontend-dist,media,thumbnails,logs}
sudo chown $USER:$USER $MEDIA_LIBRARY_DIR

# Install dependencies
echo "📦 Installing backend dependencies..."
cd $MEDIA_LIBRARY_DIR/backend
npm install --production

# Create .env
echo "🔧 Creating .env file..."
cat > $MEDIA_LIBRARY_DIR/backend/.env << EOF
PORT=3000
NODE_ENV=production
MEDIA_DIR=$MEDIA_DIR
THUMB_DIR=$MEDIA_LIBRARY_DIR/thumbnails
DB_FILE=$MEDIA_LIBRARY_DIR/media.db
EOF

# Create systemd services
echo "⚙️ Creating systemd services..."
sudo tee /etc/systemd/system/media-library-backend.service > /dev/null << 'SYSEOF'
[Unit]
Description=Media Library Backend Service
After=network.target

[Service]
Type=simple
User=osmc
WorkingDirectory=/opt/media-library/backend
ExecStart=/usr/bin/node /opt/media-library/backend/app.js
Restart=always
RestartSec=10
StandardOutput=append:/opt/media-library/logs/backend.log
StandardError=append:/opt/media-library/logs/backend.log
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
SYSEOF

# Reload and start
echo "▶️ Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable media-library-backend
sudo systemctl start media-library-backend

echo "✅ Deployment complete!"
echo ""
echo "Backend running at: http://localhost:3000"
echo "Logs available at: $MEDIA_LIBRARY_DIR/logs/backend.log"
echo ""
echo "View logs:"
echo "  tail -f $MEDIA_LIBRARY_DIR/logs/backend.log"
echo ""
echo "Check status:"
echo "  sudo systemctl status media-library-backend"
```

Make it executable:
```bash
chmod +x /opt/media-library/deploy.sh
./deploy.sh /home/osmc/Videos  # Or your actual media path
```

---

# Access Your Media Library

### Direct Access (No Nginx)
- **Backend API**: `http://osmc-ip:3000`
- **Frontend**: `http://osmc-ip:4200`

### With Nginx Proxy
- **Both**: `http://osmc-ip:80` or `http://osmc-ip`

### Update frontend proxy config for OSMC:

`frontend/proxy.conf.json`:
```json
{
  "/api": {
    "target": "http://localhost:3000",
    "secure": false,
    "changeOrigin": true,
    "pathRewrite": {
      "^/api": ""
    }
  }
}
```

---

# Troubleshooting

### Check Backend Status
```bash
sudo systemctl status media-library-backend
journalctl -u media-library-backend -f  # Real-time logs
```

### Check Frontend Status
```bash
sudo systemctl status media-library-frontend
journalctl -u media-library-frontend -f
```

### Verify Ports Are Open
```bash
netstat -tulpn | grep -E ':(3000|4200|80)'
lsof -i -P -n | grep LISTEN
```

### Check Media Directory
```bash
ls -la /home/osmc/Videos/
# Verify .env MEDIA_DIR matches
cat /opt/media-library/backend/.env | grep MEDIA_DIR
```

### Restart Services
```bash
# Backend
sudo systemctl restart media-library-backend

# Frontend
sudo systemctl restart media-library-frontend

# Both
sudo systemctl restart media-library-*
```

### View Full Logs
```bash
cat /opt/media-library/logs/backend.log
cat /opt/media-library/logs/frontend.log
```

---

# Performance Optimization for OSMC

### 1. Increase Node.js Memory (for Raspberry Pi)
Edit `/etc/systemd/system/media-library-backend.service`:
```ini
[Service]
Environment="NODE_OPTIONS=--max-old-space-size=512"
```

### 2. Reduce Thumbnail Size (faster generation)
Edit `backend/app.js`, change thumbnail generation:
```javascript
// Smaller thumbnails for faster processing
.resize(150, 150, { fit: 'cover' })  // was 200x200
```

### 3. Increase FFmpeg Timeout
For slower systems, increase thumbnail generation timeout.

### 4. Use SSD for Database
If possible, place `/opt/media-library` on an SSD:
```bash
# Check available storage
df -h
# Move if needed:
sudo mv /opt/media-library /mnt/ssd/media-library
sudo ln -s /mnt/ssd/media-library /opt/media-library
```

---

# Backup Configuration

Create backup script at `/opt/media-library/backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/home/osmc/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup database
cp /opt/media-library/media.db $BACKUP_DIR/media_$TIMESTAMP.db

# Backup config
cp /opt/media-library/backend/.env $BACKUP_DIR/env_$TIMESTAMP

echo "✅ Backup complete: $BACKUP_DIR/"
ls -lh $BACKUP_DIR/
```

Schedule daily backups:
```bash
# Add to crontab
crontab -e

# Add line:
0 2 * * * /opt/media-library/backup.sh  # Backup at 2 AM daily
```

---

# Next Steps

1. ✅ Install Node.js and dependencies
2. ✅ Copy project to `/opt/media-library`
3. ✅ Build frontend
4. ✅ Create systemd services
5. ✅ Start services
6. ✅ (Optional) Set up Nginx
7. ✅ Access at `http://osmc-ip`
8. ✅ Monitor logs

Your media library will auto-start on OSMC reboot! 🎉

