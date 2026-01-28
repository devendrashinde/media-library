# OSMC Production Configuration

This file contains recommended configuration for running Media Library in production on OSMC.

## .env File Template

Copy to `/opt/media-library/backend/.env` and customize:

```env
################################################################################
# Media Library - Production Configuration
################################################################################

# Server Configuration
PORT=3000
NODE_ENV=production

# Database Configuration
DB_FILE=/opt/media-library/media.db

# File Paths
# IMPORTANT: Customize these to match your OSMC setup
MEDIA_DIR=/home/osmc/Videos
THUMB_DIR=/opt/media-library/thumbnails

# Optional: Add multiple media directories (one per line)
# MEDIA_DIR=/home/osmc/Videos
# MEDIA_DIR=/home/osmc/Music
# MEDIA_DIR=/mnt/nas/media
```

## Common OSMC Media Paths

Edit MEDIA_DIR to match your setup:

```bash
# Videos (Default OSMC location)
MEDIA_DIR=/home/osmc/Videos

# Music
MEDIA_DIR=/home/osmc/Music

# Pictures
MEDIA_DIR=/home/osmc/Pictures

# External USB drive
MEDIA_DIR=/mnt/usb/media

# Network share / NAS
MEDIA_DIR=/mnt/nas/shared
MEDIA_DIR=/home/osmc/nfs-mount

# Multiple directories (requires code modification)
```

## Docker Compose Configuration

For Docker deployment, edit `docker-compose.yml` volumes section:

```yaml
volumes:
  # Videos
  - /home/osmc/Videos:/data/media
  
  # OR multiple locations (mount separately)
  - /home/osmc/Videos:/data/videos
  - /home/osmc/Music:/data/music
  - /mnt/nas/media:/data/nas
  
  # Persistent data
  - media-library-data:/data
```

## Performance Optimization

### For Raspberry Pi (Limited Resources)

In `.env`:
```env
# Reduce memory usage
NODE_OPTIONS=--max-old-space-size=256

# Smaller thumbnails for faster generation
# Edit app.js line ~120:
# .resize(150, 150, { fit: 'cover' })  # Instead of 200x200
```

### For More Powerful Hardware

In `.env`:
```env
# Increase memory for faster processing
NODE_OPTIONS=--max-old-space-size=512

# In docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 1G
```

## Systemd Service Configuration (Native)

For native deployment, edit `/etc/systemd/system/media-library-backend.service`:

```ini
[Unit]
Description=Media Library Backend
After=network.target

[Service]
Type=simple
User=osmc
WorkingDirectory=/opt/media-library/backend

# Adjust for your hardware
Environment="NODE_OPTIONS=--max-old-space-size=512"
Environment="NODE_ENV=production"

# Load .env file
EnvironmentFile=/opt/media-library/backend/.env

ExecStart=/usr/bin/node /opt/media-library/backend/app.js
Restart=always
RestartSec=10

# Logging
StandardOutput=append:/opt/media-library/logs/backend.log
StandardError=append:/opt/media-library/logs/backend.log

# Resource limits (Raspberry Pi)
MemoryLimit=512M
CPUQuota=100%

[Install]
WantedBy=multi-user.target
```

## Nginx Configuration (Optional)

For production with reverse proxy:

```nginx
# /etc/nginx/sites-available/media-library

upstream backend {
    server localhost:3000;
    keepalive 32;
}

# Optional: Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=stream:10m rate=5r/s;

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # File upload limit
    client_max_body_size 100M;
    
    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    gzip_min_length 1000;
    
    # Root location - serve frontend
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # API endpoints - with rate limiting
    location ~ ^/(albums|files|search|tags) {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Media streaming - with range request support
    location ~ ^/media/ {
        limit_req zone=stream burst=5 nodelay;
        
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Range $http_range;
        proxy_set_header If-Range $http_if_range;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Thumbnails - cache for 30 days
    location ~ ^/thumbnails/ {
        proxy_pass http://backend;
        proxy_cache_valid 200 30d;
        add_header Cache-Control "public, max-age=2592000";
        expires 30d;
    }
}
```

Enable it:
```bash
sudo ln -s /etc/nginx/sites-available/media-library \
           /etc/nginx/sites-enabled/media-library
sudo systemctl restart nginx
```

## Firewall Configuration

For UFW (Uncomplicated Firewall):

```bash
# Allow HTTP (Nginx)
sudo ufw allow 80/tcp

# Allow HTTPS (if using SSL)
sudo ufw allow 443/tcp

# Allow from specific IP only
sudo ufw allow from 192.168.1.0/24 to any port 3000

# Check rules
sudo ufw status
```

## Backup Configuration

Regular backups protect your database and configuration:

### Create Backup Script

Save as `/opt/media-library/backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/home/osmc/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
cp /opt/media-library/media.db $BACKUP_DIR/media_$TIMESTAMP.db

# Backup config
cp /opt/media-library/backend/.env $BACKUP_DIR/env_$TIMESTAMP

# Keep only last 30 days
find $BACKUP_DIR -name "media_*.db" -mtime +30 -delete
find $BACKUP_DIR -name "env_*" -mtime +30 -delete

echo "✓ Backup complete: $BACKUP_DIR"
```

### Schedule Daily Backups

```bash
# Make executable
chmod +x /opt/media-library/backup.sh

# Add to crontab (2 AM daily)
crontab -e

# Add line:
0 2 * * * /opt/media-library/backup.sh
```

## Monitoring

### System Monitoring (Docker)

```bash
# Real-time resource usage
docker stats media-library

# Container logs
docker-compose logs -f media-library --tail 100
```

### System Monitoring (Native)

```bash
# Real-time logs
tail -f /opt/media-library/logs/backend.log

# Service status
systemctl status media-library-backend

# Resource usage
ps aux | grep "node.*app.js"

# Database size
du -sh /opt/media-library/media.db

# Disk usage
df -h /opt/media-library
```

## Maintenance Tasks

### Weekly
- [ ] Check application logs for errors
- [ ] Verify media files are being indexed
- [ ] Test media playback

### Monthly
- [ ] Backup database and config
- [ ] Clean up old thumbnails (>30 days)
- [ ] Review disk space usage
- [ ] Check Node.js updates

### Quarterly
- [ ] Update OSMC system
- [ ] Update Node.js version
- [ ] Review and optimize performance
- [ ] Full system backup

## Upgrade Procedure

1. Backup current database:
   ```bash
   cp /opt/media-library/media.db /opt/media-library/media.db.backup
   ```

2. Pull latest code:
   ```bash
   cd ~/media-library
   git pull
   ```

3. Install dependencies:
   ```bash
   npm install --production
   ```

4. Restart application:
   ```bash
   # Docker
   docker-compose up -d --build
   
   # Native
   sudo systemctl restart media-library-backend
   ```

5. Verify it works:
   - Access http://osmc-ip:4200
   - Test playing a file

## Rollback Procedure

If something breaks:

1. Restore backup:
   ```bash
   cp /opt/media-library/media.db.backup /opt/media-library/media.db
   ```

2. Restore previous code:
   ```bash
   git checkout previous-version
   npm install --production
   ```

3. Restart:
   ```bash
   sudo systemctl restart media-library-backend
   ```

## Production Checklist

Before going live:

- [ ] OSMC system updated
- [ ] All prerequisites installed
- [ ] Application deployed successfully
- [ ] Media directory configured correctly
- [ ] .env file created with proper paths
- [ ] Systemd service (or Docker) running
- [ ] Application accessible from browser
- [ ] Media files appearing in UI
- [ ] Thumbnails generating
- [ ] Playback working
- [ ] Tags feature working
- [ ] Logs being generated
- [ ] Backup system in place
- [ ] Firewall configured
- [ ] Initial backup created

---

## Getting Help

If you need help with configuration:

1. Check the relevant deployment guide
2. Review logs for error messages
3. Verify prerequisites are installed
4. Test network connectivity
5. Check file permissions

Good luck with your deployment! 🚀

