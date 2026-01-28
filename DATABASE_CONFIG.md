# Database Configuration Guide

**Important**: Proper database configuration is critical for performance, reliability, and data safety.

---

## Quick Answer: Where Should DB_FILE Be?

### ✅ **RECOMMENDED** - Fast Local Storage
```bash
# Best option - local SSD or fast drive
DB_FILE=/opt/media-library/media.db

# External fast USB 3.0+ SSD (acceptable)
DB_FILE=/mnt/fast-external-ssd/media.db

# With app directory (default, good enough)
DB_FILE=/opt/media-library/media.db
```

### ⚠️ **NOT RECOMMENDED** - Network or Slow Storage
```bash
# Network storage (NAS, NFS, SMB) - ❌ DO NOT USE
DB_FILE=/mnt/nas/media.db              # SQLite corruption risk!

# USB 2.0 drives - ⚠️ Too slow
DB_FILE=/mnt/slow-usb/media.db

# Network mounts - ❌ DO NOT USE
DB_FILE=/network-mount/media.db
```

---

## Understanding SQLite Storage Requirements

### Why Database Storage Matters

SQLite is designed for **local access patterns** with specific requirements:

| Requirement | Why | Impact |
|-------------|-----|--------|
| **Fast Random I/O** | Frequent reads/writes to different parts of file | Network storage = high latency |
| **Reliable File Locking** | Multiple processes coordination | Network protocols can fail |
| **Immediate Durability** | Data written = data safe (fsync) | Network delays = data risk |
| **Millisecond Latency** | Queries need fast access | 100ms network latency = slow |

### Performance Comparison

```
Local SSD:           1ms latency  → Fast queries ✅
External USB 3.0:    5-10ms       → Acceptable ⚠️
External USB 2.0:    50-100ms     → Very slow ❌
Network (NAS):       100-500ms    → Unacceptably slow ❌
Network (SMB):       500-1000ms   → Extremely slow ❌
```

### Reliability Comparison

```
Local SSD:           No file locking issues      ✅ Reliable
USB Drive:           Occasional timeout issues  ⚠️ Somewhat reliable
Network Storage:     File locking problems      ❌ Not reliable
                     Corruption risk high       ❌ Data loss possible
```

---

## Configuration Methods

### Method 1: Environment Variable

**Local Development:**
```bash
# Edit backend/.env
DB_FILE=/opt/media-library/media.db
```

**Docker:**
```bash
# Set in docker-compose.yml or .env
DB_FILE=/data/media.db
```

### Method 2: Deployment Scripts

**Windows to Raspberry Pi:**
```powershell
# Use -DbFile parameter
.\deploy-to-pi.ps1 -DbFile /opt/media/media.db

# Or interactive (script will ask)
.\deploy-to-pi.ps1
```

**OSMC Deployment:**
```bash
# Command line
./deploy-osmc.sh /home/osmc/Videos /mnt/thumbs /opt/media/media.db native

# Or interactive (script will ask)
./deploy-osmc.sh
# When prompted: "Enter database file path [leave empty to use app directory]"
```

### Method 3: Interactive Setup

The deployment scripts will:
1. **Ask for database location**
2. **Warn if using network storage**
3. **Create parent directories if needed**
4. **Validate the path**

Example interaction:
```
Enter database file path [leave empty to use app directory]: /mnt/nas/media.db

⚠️  WARNING: Network storage for database is NOT recommended!
SQLite on network storage can cause corruption and performance issues.
Recommended: Use local SSD or fast external drive.
Continue with network storage? (y/n) 
```

---

## Recommended Setups

### Setup 1: Single Drive (Simple)
```bash
# Everything on local SSD
MEDIA_DIR=/home/user/media
THUMB_DIR=/home/user/media-library/thumbnails
DB_FILE=/home/user/media-library/media.db
```

**Pros**: Simple, all local, no issues  
**Cons**: Limited to single drive capacity

### Setup 2: Multi-Drive Optimized (Recommended for Large Libraries)
```bash
# Slow + Large = Media
MEDIA_DIR=/mnt/large-hdd/media

# Medium + External = Thumbnails
THUMB_DIR=/mnt/external-ssd/thumbnails

# Fast + Local = Database (MOST IMPORTANT)
DB_FILE=/opt/media-library/media.db
```

**Pros**: Optimal performance, separate storage  
**Cons**: Requires multiple drives

### Setup 3: Docker Container
```yaml
services:
  media-library:
    volumes:
      # Media on external (large, slow)
      - /mnt/nas:/data/media
      
      # Thumbnails on fast drive
      - /mnt/fast-ssd:/data/thumbnails
      
      # Database keeps local volume
      - media-library-data:/data
    
    environment:
      - MEDIA_DIR=/data/media
      - THUMB_DIR=/data/thumbnails
      - DB_FILE=/data/media.db              # Local in container
```

**Pros**: Container managed, clean isolation  
**Cons**: Need fast local storage for Docker volume

### Setup 4: Raspberry Pi OSMC
```bash
# Run deployment with options
./deploy-osmc.sh /home/osmc/Videos /mnt/usb/thumbs /opt/media/media.db docker

# Or accept defaults (recommended)
./deploy-osmc.sh /home/osmc/Videos
# Uses: DB_FILE=/opt/media-library/media.db (local, safe)
```

**Pros**: Optimized for Pi, database stays local  
**Cons**: Media on USB, thumbs on USB = slower

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Database on NAS with SQLite
```bash
DB_FILE=/mnt/nas/media.db  # ❌ WRONG

# Risks:
# - File locking over network fails
# - Queries are 100x slower
# - Database can become corrupted
# - Data loss possible
```

**Fix**:
```bash
DB_FILE=/opt/media-library/media.db  # ✅ CORRECT
```

### ❌ Mistake 2: Database on USB 2.0
```bash
DB_FILE=/mnt/slow-usb/media.db  # ⚠️ Not ideal

# Issues:
# - Very slow queries
# - High latency
# - Timeout problems
```

**Fix**:
```bash
DB_FILE=/mnt/fast-usb-3/media.db  # ⚠️ Better
DB_FILE=/opt/local-ssd/media.db   # ✅ Best
```

### ❌ Mistake 3: Database on Different Drive Without Backup
```bash
# Putting DB on unreliable external storage
DB_FILE=/mnt/untested-drive/media.db

# What if the drive fails?
# What if connection drops?
```

**Fix**:
```bash
# Regular backups
DB_FILE=/opt/media-library/media.db

# Plus backup strategy
# Cron job to backup media.db daily
```

---

## Storage Comparison Table

| Storage Type | Speed | Reliability | Cost | Suitable |
|--------------|-------|-------------|------|----------|
| **Local SSD** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | High | ✅ Database |
| **Local HDD** | ⭐⭐⭐ | ⭐⭐⭐⭐ | Low | ✅ Media |
| **USB 3.0 SSD** | ⭐⭐⭐⭐ | ⭐⭐⭐ | Medium | ⚠️ Acceptable |
| **USB 2.0 Drive** | ⭐⭐ | ⭐⭐ | Low | ❌ Too slow |
| **NAS (NFS)** | ⭐⭐ | ⭐⭐ | Medium | ✅ Media only |
| **NAS (SMB)** | ⭐ | ⭐⭐ | Medium | ✅ Media only |
| **Cloud Storage** | ⭐ | ⭐⭐ | High | ❌ Not suitable |

---

## Performance Impact

### Query Speed Comparison

Scenario: Search through 10,000 media items

```
Local SSD DB:        0.5 seconds  ✅
USB 3.0 SSD DB:      2 seconds    ⚠️
USB 2.0 DB:          10+ seconds  ❌
NAS DB:              30+ seconds  ❌
SMB NAS DB:          60+ seconds  ❌
```

### Thumbnail Generation with Different DB Locations

```
Local SSD DB:        Processing 100 items → 5 seconds ✅
NAS DB:              Processing 100 items → 30+ seconds ❌
Network Drop:        Processing stalls → Database locked ❌
```

---

## Troubleshooting Database Issues

### Problem: "Database is Locked"
```
Error: SQLITE_BUSY: database is locked
```

**Likely Causes**:
- Multiple processes accessing database
- Network storage with poor locking
- Database file on network with connection issues

**Solutions**:
```bash
# 1. Stop all instances
sudo systemctl stop media-library-backend
docker-compose down

# 2. Move database to local storage
DB_FILE=/opt/media-library/media.db

# 3. Restart with new location
sudo systemctl start media-library-backend
```

### Problem: "Disk I/O Error"
```
Error: disk I/O error
```

**Likely Causes**:
- Database on unreliable external storage
- Network connection dropped
- Corrupted database file

**Solutions**:
```bash
# 1. Move to local storage immediately
cp /mnt/nas/media.db /opt/media-library/media.db
DB_FILE=/opt/media-library/media.db

# 2. Verify database integrity
sqlite3 /opt/media-library/media.db "PRAGMA integrity_check;"

# 3. Restore from backup if corrupted
```

### Problem: Slow Queries / High Latency
```
Queries taking 30+ seconds
Search is extremely slow
```

**Cause**: Database on network storage

**Solution**:
```bash
# Move database to local SSD
DB_FILE=/opt/media-library/media.db

# Performance will improve 10-100x
```

### Problem: Application Crashes When Network Drops
```
Backend crashes when NAS disconnects
Database connection lost
```

**Cause**: Database on network storage

**Solution**:
```bash
# Move to local storage
DB_FILE=/opt/media-library/media.db

# Add connection retry logic (if using network media)
# But NEVER put database on network
```

---

## Best Practices

### ✅ DO

- ✅ Keep database on **local fast storage** (SSD)
- ✅ Use local media when possible
- ✅ Backup database regularly
- ✅ Monitor database file size
- ✅ Use fast external USB 3.0+ SSD if needed
- ✅ Place database on same drive as application for simplicity

### ❌ DON'T

- ❌ Put database on NAS/Network storage
- ❌ Put database on USB 2.0
- ❌ Put database on unreliable external drive
- ❌ Mix network and local without care
- ❌ Assume SQLite works like a network database
- ❌ Ignore warnings about network storage

---

## Backup Strategy

### Automated Daily Backup

```bash
# Cron job: backup database daily
0 2 * * * cp /opt/media-library/media.db /backup/media.db.$(date +\%Y\%m\%d)
```

### Manual Backup

```bash
# Stop application
sudo systemctl stop media-library-backend

# Backup database
cp /opt/media-library/media.db /backup/media.db.backup

# Restart
sudo systemctl start media-library-backend
```

### Restore from Backup

```bash
# Stop application
sudo systemctl stop media-library-backend

# Restore
cp /backup/media.db.backup /opt/media-library/media.db

# Restart
sudo systemctl start media-library-backend
```

---

## Migration: Moving Database to New Location

### Step 1: Prepare New Location

```bash
# Create target directory
mkdir -p /opt/media-library
chmod 755 /opt/media-library
```

### Step 2: Stop Application

```bash
sudo systemctl stop media-library-backend
# or: docker-compose down
```

### Step 3: Move Database

```bash
# Copy database to new location
cp /old/location/media.db /opt/media-library/media.db

# Verify copy succeeded
ls -la /opt/media-library/media.db

# Optional: remove old copy after verifying new works
rm /old/location/media.db
```

### Step 4: Update Configuration

```bash
# Edit backend/.env or docker-compose.yml
echo "DB_FILE=/opt/media-library/media.db" >> backend/.env
```

### Step 5: Start Application

```bash
sudo systemctl start media-library-backend
# or: docker-compose up -d
```

### Step 6: Verify

```bash
# Check if application started successfully
sudo systemctl status media-library-backend

# Check logs for errors
tail -f /var/log/media-library/backend.log

# Test media library access
# http://localhost:4200
```

---

## Docker-Specific Configuration

### Docker Volume Types for Database

**Named Volume** (RECOMMENDED):
```yaml
volumes:
  media-library-data:
    driver: local

services:
  media-library:
    volumes:
      - media-library-data:/data  # Database goes here
```

**Bind Mount** (Host path):
```yaml
services:
  media-library:
    volumes:
      - /opt/media-library-db:/data  # Direct to host SSD
```

**Why Named Volume is Better**:
- Managed by Docker
- Better performance
- Easier to backup
- Don't need host-level setup

---

## Environment Variable Summary

```bash
# Complete configuration with all three storage locations
MEDIA_DIR=/mnt/large-storage/media         # Slow, large, can be network
THUMB_DIR=/mnt/fast-external/thumbnails    # Medium speed, flexible
DB_FILE=/opt/media-library/media.db        # Fast, local, MUST be SSD
```

---

## Summary

| Aspect | Recommendation | Why |
|--------|---|---|
| **MEDIA_DIR** | External storage OK | Large files, slow access is fine |
| **THUMB_DIR** | External storage OK | Moderate files, flexible access |
| **DB_FILE** | **LOCAL FAST SSD** | **Random I/O, frequent access, data safety** |

**Golden Rule**: Keep the database on fast local storage. Everything else can be flexible.

---

*Database Configuration Guide*  
*Created: January 28, 2026*  
*Last Updated: January 28, 2026*
