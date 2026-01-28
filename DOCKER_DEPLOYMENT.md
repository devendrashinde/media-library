# Docker Deployment Guide for OSMC

## Quick Start (Easiest Method)

If you have Docker and Docker Compose installed on OSMC:

```bash
# 1. Build frontend first
cd frontend
npm install
npm run build

# 2. Copy dist to root
cp -r dist/media-frontend ../frontend-dist

# 3. Go to root directory
cd ..

# 4. Start with Docker Compose
docker-compose up -d

# Access at http://osmc-ip:4200 or http://osmc-ip:3000
```

---

## Installation on OSMC

### Prerequisites

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get install -y python3-pip
sudo pip3 install docker-compose

# Add OSMC user to docker group
sudo usermod -aG docker osmc
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

### Setup Media Directory

```bash
# Create directories for volumes
mkdir -p ~/media-library/media
mkdir -p ~/media-library/data

# If your media is in a different location, create a symbolic link
# Example: If media is on an external drive
ln -s /mnt/external/media ~/media-library/media
```

### Build and Run

```bash
# Clone/copy project
cd ~/media-library
git clone <your-repo> .
# Or copy files manually

# Build frontend
cd frontend
npm install
npm run build
cp -r dist/media-frontend ..

# Return to root
cd ..

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f media-library
```

### Stop and Restart

```bash
# Stop
docker-compose down

# Restart
docker-compose up -d

# Restart with fresh build
docker-compose up -d --build
```

---

## Custom Docker Compose Configuration

Save as `docker-compose.osmc.yml`:

```yaml
version: '3.8'

services:
  media-library:
    build: .
    container_name: media-library
    hostname: media-library
    restart: always
    
    ports:
      - "3000:3000"  # Backend
      - "4200:4200"  # Frontend
    
    volumes:
      # Mount your actual media directory
      - /home/osmc/Videos:/data/media           # Videos
      - /home/osmc/Music:/data/music            # Music (if separate)
      # - /mnt/nas/media:/data/external        # NAS mount
      
      # Persistent data (database, thumbnails)
      - media-library-data:/data
    
    environment:
      - NODE_ENV=production
      - PORT=3000
      - MEDIA_DIR=/data/media
      - THUMB_DIR=/data/thumbnails
      - DB_FILE=/data/media.db
    
    # Memory limits (adjust for your hardware)
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 512M
        reservations:
          cpus: '1'
          memory: 256M
    
    # Wait for health
    depends_on:
      - media-library
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/albums"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    
    networks:
      - media-network

volumes:
  media-library-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/media-library/data

networks:
  media-network:
    driver: bridge
```

Run with custom config:
```bash
docker-compose -f docker-compose.osmc.yml up -d
```

---

## Nginx Reverse Proxy (with Docker)

Create `docker-compose.full.yml`:

```yaml
version: '3.8'

services:
  media-library:
    build: .
    container_name: media-library
    networks:
      - media-network
    
    volumes:
      - /home/osmc/Videos:/data/media
      - media-library-data:/data
    
    environment:
      - NODE_ENV=production
      - PORT=3000
      - MEDIA_DIR=/data/media
      - THUMB_DIR=/data/thumbnails
      - DB_FILE=/data/media.db
    
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/albums"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: media-library-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    networks:
      - media-network
    restart: always
    depends_on:
      - media-library

volumes:
  media-library-data:

networks:
  media-network:
    driver: bridge
```

Create `nginx.conf`:

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream media-library {
        server media-library:3000;
    }

    server {
        listen 80;
        server_name _;

        client_max_body_size 0;  # Unlimited for large files

        # Frontend
        location / {
            proxy_pass http://media-library;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }

        # API and streaming
        location ~ ^/(api|media|thumbnails|search|albums|files) {
            proxy_pass http://media-library;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # For media streaming
            proxy_request_buffering off;
            proxy_buffering off;
        }
    }
}
```

Run with Nginx:
```bash
docker-compose -f docker-compose.full.yml up -d
# Access at http://osmc-ip:80
```

---

## Monitoring and Logs

```bash
# View real-time logs
docker-compose logs -f media-library

# View specific service logs
docker logs media-library

# Check container stats
docker stats media-library

# Access container shell
docker exec -it media-library sh

# Check disk usage
docker system df
```

---

## Troubleshooting Docker

### Container won't start
```bash
# Check logs
docker-compose logs media-library

# Try without daemon mode to see errors
docker-compose up media-library
```

### Port already in use
```bash
# Change ports in docker-compose.yml
ports:
  - "3001:3000"  # Use 3001 instead
  - "4201:4200"

# Or stop the conflicting service
sudo systemctl stop media-library-backend
```

### No media showing
```bash
# Verify volume mount
docker inspect media-library | grep -A 5 Mounts

# Verify MEDIA_DIR env var
docker exec media-library printenv | grep MEDIA_DIR

# Check file permissions
docker exec media-library ls -la /data/media
```

### Database errors
```bash
# Delete and recreate database
docker-compose down
docker volume rm media-library_media-library-data
docker-compose up -d
```

---

## Production Hardening

### 1. Resource Limits

In `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 256M
```

### 2. Security

```yaml
security_opt:
  - no-new-privileges:true

read_only: true

tmpfs:
  - /tmp
  - /run

user: 1000:1000
```

### 3. Auto-restart

```yaml
restart: unless-stopped
```

### 4. Logging

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

## Backup with Docker

```bash
# Backup database
docker cp media-library:/data/media.db ~/backups/media-$(date +%Y%m%d).db

# Backup entire data directory
docker exec media-library tar czf - /data | gzip > ~/backups/media-library-$(date +%Y%m%d).tar.gz

# Restore
docker exec media-library tar xzf ~/backups/media-library-latest.tar.gz
```

---

## Comparison: Native vs Docker

| Feature | Native | Docker |
|---------|--------|--------|
| Setup Time | 30 mins | 5 mins |
| Storage | System-wide | Isolated |
| Updates | Manual | Easy rebuild |
| Troubleshooting | Complex | Simple (logs) |
| Performance | Slightly faster | 5-10% overhead |
| Portability | OSMC-specific | Universal |
| Backups | Manual scripts | Volume management |

**Recommendation: Use Docker for simplicity and portability!**

