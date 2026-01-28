# Thumbnails Configuration Guide

This guide explains how to configure the thumbnails directory for your media-library installation.

## Why Configure Thumbnails Directory?

By default, generated thumbnails are stored in the same directory as your media-library application. However, you may want to store thumbnails elsewhere for several reasons:

- **External Storage**: Store thumbnails on a USB drive, external SSD, or NAS for better performance
- **Space Management**: Keep thumbnails on a separate drive from your main installation
- **Performance**: Use a faster storage device for thumbnails (e.g., SSD while media is on HDD)
- **Scalability**: As your media library grows, thumbnails can consume significant disk space

## Configuration Methods

### 1. Local Development (.env file)

Create or edit `.env` in the `backend/` directory:

```bash
cd backend
# Edit or create .env file
echo "THUMB_DIR=/path/to/your/thumbnails" >> .env
```

**Example configurations:**
```env
# Same directory as app (default)
THUMB_DIR=./thumbnails

# Absolute path to external USB
THUMB_DIR=/mnt/usb-drive/thumbnails

# NAS or network mount
THUMB_DIR=/mnt/nas/media-lib-thumbnails

# External SSD on Linux
THUMB_DIR=/mnt/external-ssd/thumbnails
```

### 2. Docker Deployment

Edit `docker-compose.yml` and modify the volumes section:

```yaml
services:
  media-library:
    # ... other config ...
    volumes:
      - ./media:/data/media                           # Media files (required)
      - media-library-data:/data                     # Database
      - /path/to/external/storage:/data/thumbnails  # Thumbnails on external storage
    environment:
      - THUMB_DIR=/data/thumbnails
```

**Example with external USB drive:**
```yaml
volumes:
  - ./media:/data/media
  - media-library-data:/data
  - /mnt/external-usb:/data/thumbnails
```

**Example with NAS mount:**
```yaml
volumes:
  - ./media:/data/media
  - media-library-data:/data
  - /mnt/nas-backup/thumbnails:/data/thumbnails
```

### 3. Raspberry Pi / OSMC Deployment

When deploying to OSMC, you can configure the thumbnails directory during setup:

**Interactive deployment (script will ask):**
```bash
./deploy-osmc.sh
# Script will prompt: "Enter thumbnails directory path [leave empty to use app directory]"
```

**Command-line deployment with external storage:**
```bash
./deploy-osmc.sh /home/osmc/Videos /mnt/external-drive/thumbnails native

# Or for Docker deployment:
./deploy-osmc.sh /home/osmc/Videos /mnt/external-drive/thumbnails docker
```

**From Windows:**
```powershell
.\deploy-to-pi.ps1 -PiHost 192.168.1.100 `
                   -PiUser osmc `
                   -MediaDir /home/osmc/Videos `
                   -ThumbDir /mnt/external-drive/thumbnails
```

## Setting Up External Storage

### Linux / OSMC

#### USB Drive
```bash
# Find your USB drive
lsblk

# Create mount point
sudo mkdir -p /mnt/external-usb

# Mount the drive (replace sda1 with your device)
sudo mount /dev/sda1 /mnt/external-usb

# Make mount permanent (optional)
echo '/dev/sda1 /mnt/external-usb ext4 defaults 0 2' | sudo tee -a /etc/fstab
```

#### NAS / Network Storage
```bash
# Create mount point
sudo mkdir -p /mnt/nas-media

# Mount NAS (adjust for your NAS)
sudo mount -t nfs 192.168.1.50:/exports/media /mnt/nas-media

# Or for SMB/CIFS
sudo mount -t cifs //192.168.1.50/media /mnt/nas-media -o username=user,password=pass
```

### Docker Volume Mount

For Docker containers, volumes are defined in `docker-compose.yml`. Make sure the host path exists:

```bash
# Create the directory first
mkdir -p /path/to/thumbnails

# Set proper permissions
chmod 755 /path/to/thumbnails
```

## Performance Considerations

### Thumbnail Generation Performance

- **Video Thumbnails**: FFmpeg processing is CPU-intensive
- **Large Collections**: With thousands of files, consider using fast storage (SSD)
- **Network Storage**: NAS/network mounts may be slower for real-time generation

### Recommended Setup

For optimal performance:

1. **Media Files**: Large capacity HDD or NAS (throughput-optimized)
2. **Thumbnails**: SSD or fast external drive (random I/O optimized)
3. **Database**: Same as app installation (usually included)

```bash
# Example performance-optimized setup
MEDIA_DIR=/mnt/nas/media                    # Large NAS storage
THUMB_DIR=/mnt/ssd-external/thumbnails     # Fast external SSD
DB_FILE=/opt/media-library/media.db         # Local fast storage
```

## Troubleshooting

### Permission Denied Errors

```bash
# Check ownership
ls -la /path/to/thumbnails

# Fix permissions (if using external storage)
sudo chown $USER:$USER /path/to/thumbnails
sudo chmod 755 /path/to/thumbnails
```

### Thumbnails Not Generating

1. **Check disk space:**
   ```bash
   df -h /path/to/thumbnails
   ```

2. **Verify write permissions:**
   ```bash
   touch /path/to/thumbnails/test.txt
   rm /path/to/thumbnails/test.txt
   ```

3. **Check FFmpeg installation** (for video thumbnails):
   ```bash
   ffmpeg -version
   ```

### Storage Mount Disappeared

If using external storage and mount disconnects:

1. **Make mount automatic:**
   - Add to `/etc/fstab` for permanent mounts
   - Configure auto-remount settings

2. **Add mount health check:**
   ```bash
   # Check if mount is active
   mountpoint /mnt/external-drive
   
   # Remount if needed
   sudo mount /mnt/external-drive
   ```

## Migration

### Moving Existing Thumbnails

If you've already generated thumbnails and want to move them:

1. **Stop the application:**
   ```bash
   sudo systemctl stop media-library-backend
   # Or: docker-compose down
   ```

2. **Copy thumbnails to new location:**
   ```bash
   cp -r ./thumbnails/* /path/to/new/location/
   ```

3. **Update configuration:**
   - Edit `.env` and set `THUMB_DIR=/path/to/new/location`

4. **Restart the application:**
   ```bash
   sudo systemctl start media-library-backend
   # Or: docker-compose up -d
   ```

The application will automatically use the new directory and continue generating missing thumbnails.

## Monitoring Thumbnails Directory

### Check Disk Usage

```bash
# Total space used by thumbnails
du -sh /path/to/thumbnails

# List largest thumbnail files
du -sh /path/to/thumbnails/* | sort -hr | head -20
```

### Set Up Disk Space Alerts

```bash
# Check available space
df -h /path/to/thumbnails

# Create alert script (optional)
# Alert when less than 5GB free
available=$(df /path/to/thumbnails | awk 'NR==2 {print $4}')
if [ $available -lt $((5*1024*1024)) ]; then
    echo "Warning: Low disk space on thumbnails drive"
fi
```

## Advanced: Custom Cleanup

If you want to manually clean up old thumbnails:

1. **Stop the application first**
2. **List old files:**
   ```bash
   find /path/to/thumbnails -type f -mtime +30 -ls
   ```
3. **Remove old thumbnails:**
   ```bash
   find /path/to/thumbnails -type f -mtime +30 -delete
   ```
4. **Restart application** (it will regenerate as needed)

---

**Note**: The application automatically generates thumbnails as needed. You don't need to manually create thumbnail files; just ensure the directory exists and has write permissions.
