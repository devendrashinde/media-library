# Quick Start: Configure Thumbnails Directory

## TL;DR - Quick Setup

### Local Development (5 seconds)
```bash
echo "THUMB_DIR=/path/to/external/storage" >> backend/.env
```

### Docker (10 seconds)
Edit `docker-compose.yml`:
```yaml
volumes:
  - ./thumbnails:/data/thumbnails  # Change ./thumbnails to your path
```

### Raspberry Pi (30 seconds)
```bash
./deploy-osmc.sh
# Script will ask: "Enter thumbnails directory path [leave empty to use app directory]"
# Type your path: /mnt/external-drive/thumbnails
```

---

## Use Cases

### 📱 USB Drive (Most Common)
```bash
# Linux/OSMC
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb
echo "THUMB_DIR=/mnt/usb/thumbnails" >> backend/.env

# Docker
- ./thumbnails:/data/thumbnails  →  - /mnt/usb:/data/thumbnails
```

### 🌐 NAS Storage
```bash
# Mount NAS
sudo mount -t nfs 192.168.1.50:/exports /mnt/nas

# Configure
echo "THUMB_DIR=/mnt/nas/media-thumbs" >> backend/.env
```

### ⚡ Fast SSD
```bash
# For performance-critical setups
echo "THUMB_DIR=/mnt/fast-ssd/thumbnails" >> backend/.env
```

### 🐳 Docker Multi-Drive
```yaml
volumes:
  - ./media:/data/media                        # Main drive
  - /mnt/external:/data/thumbnails             # External/separate drive
```

---

## Verify It Works

```bash
# 1. Check if directory exists
ls -la /path/to/thumbnails

# 2. Verify permissions (should be writable)
touch /path/to/thumbnails/test && rm /path/to/thumbnails/test

# 3. Restart application
sudo systemctl restart media-library-backend  # For native
# Or: docker-compose restart  # For Docker

# 4. Check logs
tail -f /opt/media-library/logs/backend.log

# 5. Access application
# http://localhost:4200

# 6. Upload some media files
# Application should generate thumbnails in THUMB_DIR
```

---

## Common Paths

| System | Path | Example |
|--------|------|---------|
| Linux/OSMC - USB | `/mnt/usb` | `THUMB_DIR=/mnt/usb/thumbnails` |
| Linux - External SSD | `/mnt/external` | `THUMB_DIR=/mnt/external/thumbnails` |
| Linux - NAS | `/mnt/nas` | `THUMB_DIR=/mnt/nas/thumbs` |
| Docker - Host drive | `/var/media` | `- /var/media:/data/thumbnails` |
| Windows WSL | `/mnt/d` | `THUMB_DIR=/mnt/d/thumbnails` |

---

## Troubleshooting

### ❌ "Permission denied"
```bash
sudo chown $USER:$USER /path/to/thumbnails
sudo chmod 755 /path/to/thumbnails
```

### ❌ "Directory not found"
```bash
mkdir -p /path/to/thumbnails
sudo chmod 755 /path/to/thumbnails
```

### ❌ "Storage disconnected"
- For permanent mounts: Add to `/etc/fstab`
- For USB: Configure auto-remount
- See [THUMBNAILS_CONFIG.md](THUMBNAILS_CONFIG.md) for details

### ❌ "Thumbnails not generating"
```bash
# Check if FFmpeg is installed
ffmpeg -version

# Check disk space
df -h /path/to/thumbnails

# View logs
sudo journalctl -u media-library-backend -f
```

---

## Environment Variable (.env)

Backend `.env` file format:
```env
# Required
MEDIA_DIR=/home/osmc/Videos

# Optional - thumbnails (default: ./thumbnails)
THUMB_DIR=/mnt/external/thumbnails

# Optional - database (default: media.db)
DB_FILE=/opt/media-library/media.db

# Optional - port (default: 3000)
PORT=3000

# Optional - environment (default: development)
NODE_ENV=production
```

---

## Full Documentation

For complete details, see:
- 📖 [THUMBNAILS_CONFIG.md](THUMBNAILS_CONFIG.md) - Full configuration guide
- 📖 [README.md](README.md#-configuration) - Configuration section
- 📖 [DEPLOY_FROM_WINDOWS.md](DEPLOY_FROM_WINDOWS.md) - Windows deployment
- 📖 [OSMC_DEPLOYMENT_GUIDE.md](OSMC_DEPLOYMENT_GUIDE.md) - OSMC setup

---

## Performance Tips

✅ **For best performance:**
1. Keep media on large, slower storage (HDD/NAS)
2. Store thumbnails on fast storage (SSD/USB 3.0+)
3. Store database locally (with app)

✅ **Formula:**
- Slow + Large = Media files
- Fast + Small = Thumbnails
- Local + Fast = Database + App

---

**Questions?** Check [THUMBNAILS_CONFIG.md](THUMBNAILS_CONFIG.md) or documentation files.
