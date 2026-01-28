# Thumbnails Directory Configuration - Changes Summary

Date: January 28, 2026

## Overview

The media-library application now fully supports configurable thumbnails directories, allowing users to store thumbnails on external storage devices for better performance and space management.

## Changes Made

### 1. **docker-compose.yml** ✅
- Separated thumbnails volume from general data volume
- Updated volume mapping to use `./thumbnails:/data/thumbnails`
- Added clear comments for external storage configuration
- Users can now easily change the host path for external storage

**Example:**
```yaml
volumes:
  - ./media:/data/media                    # Your media files
  - media-library-data:/data               # Database
  - ./thumbnails:/data/thumbnails         # Thumbnails (change for external storage)
```

### 2. **Dockerfile** ✅
- Updated to create separate `/data/db` directory
- Database file now points to `/data/db/media.db` instead of `/data/media.db`
- Maintains clear separation between thumbnails and database

### 3. **deploy-to-pi.ps1** (Windows Deployment) ✅
- Added new `-ThumbDir` parameter for specifying thumbnails location
- Updated configuration display to show thumbnails directory
- Enhanced deployment script to pass thumbnails directory to OSMC deployment
- Maintains backward compatibility (ThumbDir is optional)

**Usage:**
```powershell
# With custom thumbnails directory
.\deploy-to-pi.ps1 -PiHost 192.168.1.100 -MediaDir /path/to/media -ThumbDir /path/to/thumbnails

# Default behavior (if ThumbDir not specified)
.\deploy-to-pi.ps1 -PiHost 192.168.1.100 -MediaDir /path/to/media
```

### 4. **deploy-osmc.sh** (OSMC Deployment) ✅
- Added interactive prompt for thumbnails directory configuration
- Updated script signature to accept `THUMB_DIR` as second parameter
- Interactive mode asks user for separate thumbnails location
- `deploy_native()` function now uses configured `THUMB_DIR`
- Proper .env file generation with correct THUMB_DIR path

**Updated usage:**
```bash
# Interactive mode (recommended)
./deploy-osmc.sh

# With specific paths
./deploy-osmc.sh /home/osmc/Videos /mnt/external/thumbnails native

# With external storage on Docker
./deploy-osmc.sh /home/osmc/Videos /mnt/external/thumbnails docker
```

### 5. **README.md** ✅
- Documented `THUMB_DIR` environment variable
- Added configuration section explaining external storage options
- Included Docker volume configuration examples
- Updated Raspberry Pi deployment examples with ThumbDir parameter
- Added note about separate thumbnails directory in Docker setup

### 6. **New: THUMBNAILS_CONFIG.md** ✅
- Comprehensive guide for thumbnails directory configuration
- Multiple setup methods:
  - Local development (.env file)
  - Docker deployment (docker-compose.yml)
  - Raspberry Pi / OSMC deployment
- External storage setup instructions:
  - USB drive mounting
  - NAS/network storage mounting
- Performance recommendations
- Troubleshooting guide
- Migration guide for existing installations
- Disk usage monitoring tips

## Benefits

### ✅ External Storage Support
Users can now easily configure thumbnails to use:
- USB drives
- External SSDs
- NAS systems
- Network-mounted storage
- Fast dedicated drives

### ✅ Better Performance
- Separate thumbnails on faster storage (SSD) while media on HDD
- Reduced I/O contention
- Better scalability for large media libraries

### ✅ Space Management
- Store thumbnails on separate drive with different capacity
- Monitor and manage thumbnail storage independently
- Easy cleanup without affecting media

### ✅ Backward Compatible
- Default behavior unchanged if not configured
- Existing installations continue to work
- Optional configuration for new deployments

## Environment Variables

| Variable | Default | Can Configure | Notes |
|----------|---------|----------------|-------|
| `MEDIA_DIR` | `./media` | ✅ Yes | Media files location |
| `THUMB_DIR` | `./thumbnails` | ✅ Yes | **NEW**: Thumbnails location (can be external) |
| `DB_FILE` | `media.db` | ✅ Yes | Database file path |
| `PORT` | `3000` | ✅ Yes | Backend port |
| `NODE_ENV` | `development` | ✅ Yes | Environment mode |

## Configuration Examples

### Example 1: External SSD on Linux
```env
MEDIA_DIR=/home/user/media
THUMB_DIR=/mnt/external-ssd/thumbnails
```

### Example 2: NAS Storage
```env
MEDIA_DIR=/mnt/nas/media
THUMB_DIR=/mnt/nas/thumbnails
```

### Example 3: Docker with USB Drive
```yaml
volumes:
  - ./media:/data/media
  - /mnt/usb-drive:/data/thumbnails
```

### Example 4: Performance-Optimized Setup
```bash
# Media on large capacity storage
MEDIA_DIR=/mnt/large-nas/media

# Thumbnails on fast SSD
THUMB_DIR=/mnt/fast-ssd/thumbnails

# Database on local storage
DB_FILE=/opt/media-library/media.db
```

## Testing

All configuration changes have been made to:
- ✅ Docker deployment files
- ✅ Windows PowerShell deployment script
- ✅ OSMC Bash deployment script
- ✅ Documentation files
- ✅ README with examples

## Backward Compatibility

- ✅ Existing installations work without changes
- ✅ Default thumbnails location remains in app directory
- ✅ ThumbDir parameter is optional in deployment scripts
- ✅ Interactive mode guides users through configuration

## Next Steps

1. **Users with large media libraries**: Review [THUMBNAILS_CONFIG.md](THUMBNAILS_CONFIG.md)
2. **Administrators**: Set up external storage following the guide
3. **Docker users**: Modify `docker-compose.yml` volume mappings as needed
4. **Performance tuning**: Consider fast storage for thumbnails

## Documentation Files

- [README.md](README.md) - Main project documentation (updated)
- [THUMBNAILS_CONFIG.md](THUMBNAILS_CONFIG.md) - **NEW** Comprehensive configuration guide
- [DEPLOY_FROM_WINDOWS.md](DEPLOY_FROM_WINDOWS.md) - Windows deployment guide
- [OSMC_DEPLOYMENT_GUIDE.md](OSMC_DEPLOYMENT_GUIDE.md) - OSMC deployment guide

---

**Summary**: Users can now easily configure where thumbnails are stored, enabling better performance and space management through external storage options.
