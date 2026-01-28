# 🚀 Media Library - OSMC Deployment Package

Complete deployment guides and scripts for running the Media Library on OSMC Linux.

## 📦 What's Included

- **OSMC_DEPLOYMENT_GUIDE.md** - Detailed native installation guide
- **DOCKER_DEPLOYMENT.md** - Docker and Docker Compose setup
- **deploy-osmc.sh** - Automated deployment script (recommended)
- **Dockerfile** - Docker container definition
- **docker-compose.yml** - Multi-container orchestration
- **docker-compose.osmc.yml** - OSMC-specific configuration
- **docker-compose.full.yml** - Full stack with Nginx

---

## ⚡ Quick Start (5 minutes)

### Option 1: Automated Script (Easiest)

```bash
# Make script executable
chmod +x deploy-osmc.sh

# Run interactive deployment
./deploy-osmc.sh

# Or specify options
./deploy-osmc.sh /path/to/media docker
```

The script will:
- ✅ Check prerequisites
- ✅ Build frontend
- ✅ Deploy backend
- ✅ Set up services
- ✅ Start the application
- ✅ Display access URLs

### Option 2: Docker (Simple)

```bash
# Build frontend first
cd frontend && npm install && npm run build && cd ..

# Start with Docker Compose
docker-compose up -d

# Access at http://osmc-ip:4200 or :3000
```

### Option 3: Manual Native Installation

See **OSMC_DEPLOYMENT_GUIDE.md** for step-by-step instructions.

---

## 🖥️ Minimum System Requirements

**OSMC Device (e.g., Raspberry Pi 4):**
- 2 GB RAM (4 GB+ recommended)
- 1 GB free disk space for app
- Network connection
- External/USB media storage (recommended)

**Software:**
- OSMC installed and working
- SSH access enabled
- 30 minutes for initial setup

---

## 🎯 Deployment Methods Comparison

| Method | Setup Time | Complexity | Updates | Recommended |
|--------|-----------|-----------|---------|-------------|
| **Docker** | 5 min | Low | Very Easy | ⭐⭐⭐ YES |
| **Docker + Nginx** | 10 min | Medium | Easy | ⭐⭐ For advanced |
| **Native** | 30 min | High | Manual | For learning |

**Recommendation: Use Docker for easiest deployment!**

---

## 📋 Pre-Deployment Checklist

- [ ] OSMC installed and SSH working
- [ ] Media files ready (images, videos, audio)
- [ ] Connected to network with known IP
- [ ] At least 1 GB free disk space
- [ ] Node.js (v18+) or Docker installed

---

## 🚀 Full Deployment Steps

### Step 1: Prepare Your OSMC System

```bash
# SSH into OSMC
ssh osmc@osmc-ip

# Update system
sudo apt-get update
sudo apt-get upgrade
```

### Step 2: Copy Application Files

**Option A: Via Git (if available)**
```bash
git clone <your-repo-url> ~/media-library
cd ~/media-library
```

**Option B: Via SCP**
```bash
scp -r . osmc@osmc-ip:~/media-library
ssh osmc@osmc-ip
cd ~/media-library
```

**Option C: Via Zip**
```bash
# On development machine
zip -r media-library.zip .

# Transfer and extract on OSMC
scp media-library.zip osmc@osmc-ip:
ssh osmc@osmc-ip
unzip media-library.zip
cd media-library
```

### Step 3: Run Deployment Script

```bash
# Make executable
chmod +x deploy-osmc.sh

# Run (interactive mode)
./deploy-osmc.sh

# Or specify options
./deploy-osmc.sh /home/osmc/Videos docker
```

### Step 4: Access Your Application

**Default URLs:**
- Frontend: `http://osmc-ip:4200`
- Backend API: `http://osmc-ip:3000`
- With Nginx: `http://osmc-ip`

---

## 📁 Directory Structure

After deployment:

```
/opt/media-library/              (Docker/Native)
├── backend/                     # Node.js API server
│   ├── app.js
│   ├── package.json
│   ├── .env                    # Configuration
│   └── media.db                # SQLite database
├── frontend-dist/              # Built Angular app
├── thumbnails/                 # Generated thumbnails
├── logs/                        # Service logs
├── media/                       # Symlink to media files
└── data/                        # Docker volumes

/home/osmc/Videos/              # Your actual media files
├── Movie1.mp4
├── Movie2.mp4
├── Song1.mp3
└── ...
```

---

## 🔧 Configuration

### Environment Variables

Edit `/opt/media-library/backend/.env`:

```env
# Server Configuration
PORT=3000
NODE_ENV=production

# File Paths (customize as needed)
MEDIA_DIR=/home/osmc/Videos
THUMB_DIR=/opt/media-library/thumbnails
DB_FILE=/opt/media-library/media.db
```

### Docker Configuration

Edit `docker-compose.yml`:

```yaml
volumes:
  - /home/osmc/Videos:/data/media    # Point to your media
  - /home/osmc/Music:/data/music      # Add multiple directories
```

### Nginx Configuration (Optional)

If using reverse proxy, edit `nginx.conf` to customize port/hostname.

---

## 🌐 Network Access

### Local Network Access

From another computer on your network:
```
http://osmc-ip:4200
http://osmc-ip:3000
http://osmc-name:4200
```

Find your OSMC IP:
```bash
# On OSMC
hostname -I

# Or from another machine
ping osmc
```

### Remote Access (Advanced)

1. **Port Forwarding**: Forward port 80 or 443 to OSMC
2. **VPN**: Use VPN for secure remote access
3. **Reverse Proxy**: Use ngrok or similar

---

## 📊 Monitoring

### View Logs

**Docker:**
```bash
docker-compose logs -f media-library
docker-compose logs media-library --tail 100
```

**Native (Systemd):**
```bash
sudo journalctl -u media-library-backend -f
tail -f /opt/media-library/logs/backend.log
```

### Check Status

**Docker:**
```bash
docker-compose ps
docker stats media-library
```

**Native:**
```bash
sudo systemctl status media-library-backend
sudo systemctl status media-library-frontend
```

### Performance Monitoring

```bash
# CPU and Memory usage
docker stats

# Disk usage
df -h /opt/media-library
du -sh /opt/media-library/*

# Database size
ls -lh /opt/media-library/media.db
```

---

## 🔄 Updates and Maintenance

### Update Application

**Docker:**
```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose up -d --build
```

**Native:**
```bash
# Backup database first
cp /opt/media-library/media.db /opt/media-library/media.db.backup

# Update files
git pull

# Restart service
sudo systemctl restart media-library-backend
```

### Backup Data

**Docker:**
```bash
# Backup database
docker cp media-library:/data/media.db ~/backups/media.db

# Full backup
docker-compose exec media-library tar czf - /data | \
  gzip > ~/backups/media-$(date +%Y%m%d).tar.gz
```

**Native:**
```bash
# Backup database
cp /opt/media-library/media.db ~/backups/media-$(date +%Y%m%d).db

# Backup configuration
cp /opt/media-library/backend/.env ~/backups/env-$(date +%Y%m%d)
```

### Clean Up

**Remove old thumbnails:**
```bash
# Docker
docker-compose exec media-library sh -c \
  'find /data/thumbnails -type f -mtime +30 -delete'

# Native
find /opt/media-library/thumbnails -type f -mtime +30 -delete
```

---

## 🐛 Troubleshooting

### Application Won't Start

1. Check prerequisites: `node --version`, `npm --version`
2. Check media directory exists: `ls /home/osmc/Videos`
3. Check ports available: `netstat -tulpn | grep -E ':(3000|4200)'`
4. View logs: `docker-compose logs` or `journalctl -u media-library-backend`

### No Media Files Showing

1. Verify MEDIA_DIR in .env: `cat /opt/media-library/backend/.env | grep MEDIA_DIR`
2. Check permissions: `ls -la /home/osmc/Videos`
3. Check database: `sqlite3 /opt/media-library/media.db "SELECT COUNT(*) FROM media"`
4. Restart watcher: `sudo systemctl restart media-library-backend`

### Slow Performance

1. Check available memory: `free -h`
2. Reduce thumbnail quality in app.js (line ~120)
3. Enable caching headers in Nginx
4. Use SSD for database if available
5. Limit concurrent users

### Port Conflicts

Change port in .env (Docker) or .service file:
```bash
PORT=3001  # Instead of 3000
```

### Docker Issues

```bash
# Clean up
docker-compose down
docker system prune

# Rebuild
docker-compose up -d --build

# Check logs
docker-compose logs media-library
```

See **OSMC_DEPLOYMENT_GUIDE.md** or **DOCKER_DEPLOYMENT.md** for detailed troubleshooting.

---

## 🔐 Security Considerations

1. **Local Network Only**: Keep on local network by default
2. **Firewall**: Close unnecessary ports
3. **Authentication**: Add nginx auth if exposed publicly
4. **HTTPS**: Use reverse proxy with SSL certificates
5. **Backups**: Regular database backups
6. **Updates**: Keep Node.js and ffmpeg updated

---

## 📚 Additional Documentation

- **OSMC_DEPLOYMENT_GUIDE.md** - Complete native installation
- **DOCKER_DEPLOYMENT.md** - Docker-specific instructions
- **OPTIONS_B_AND_C_APPLIED.md** - Feature list and improvements
- **CRITICAL_FIXES_APPLIED.md** - Backend fixes and enhancements

---

## 🆘 Getting Help

1. Check the relevant guide (native or Docker)
2. Review logs for error messages
3. Verify prerequisites are installed
4. Check network connectivity
5. Ensure media directory permissions
6. Review GitHub issues/documentation

---

## 🎉 Success!

Your Media Library should now be running! 

**Next steps:**
1. ✅ Open http://osmc-ip:4200 in browser
2. ✅ Browse your media files
3. ✅ Add tags to files
4. ✅ Play videos and music
5. ✅ Enjoy your media library!

---

## 📝 Notes

- Initial media indexing may take time (depending on file count)
- Thumbnail generation runs automatically
- Database and thumbnails persist across restarts
- Logs are available for debugging
- All config is externalized (.env file)

---

## 🚀 You're All Set!

Enjoy your Media Library on OSMC!

