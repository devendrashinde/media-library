#!/bin/bash

################################################################################
# Media Library - OSMC Quick Deployment Script
# 
# Usage: ./deploy-osmc.sh [MEDIA_DIR] [THUMB_DIR] [DB_FILE] [DEPLOYMENT_TYPE]
# Examples:
#   ./deploy-osmc.sh /home/osmc/Videos /data/thumbnails /opt/media/media.db native
#   ./deploy-osmc.sh /home/osmc/Videos "" "" docker
#   ./deploy-osmc.sh  # Interactive mode
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MEDIA_LIBRARY_DIR="/home/osmc/media-library"
MEDIA_DIR="${1:-}"
THUMB_DIR="${2:-}"
DB_FILE="${3:-}"
DEPLOYMENT_TYPE="${4:-}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Media Library - OSMC Deployment Script              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function: Print colored output
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

# Function: Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found!"
        echo "Install with: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
        exit 1
    fi
    
    # Check Node version
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_warning "Node.js v16 detected, but v18+ is required"
        read -p "Upgrade Node.js now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Upgrading Node.js to v18..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            print_success "Node.js upgraded"
        else
            print_error "Node.js v18+ is required"
            exit 1
        fi
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm not found!"
        exit 1
    fi
    
    # Check for build tools (needed for sqlite3)
    if ! command -v make &> /dev/null; then
        print_warning "Build tools not found (needed for sqlite3)"
        read -p "Install build-essential now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installing build-essential..."
            sudo apt-get update
            sudo apt-get install -y build-essential python3
            print_success "Build tools installed"
        else
            print_error "Build tools are required"
            exit 1
        fi
    fi
    
    # Check and increase inotify limits for file watching (needed for large media libraries)
    print_info "Checking inotify limits..."
    CURRENT_WATCHES=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "0")
    if [ "$CURRENT_WATCHES" -lt 262144 ]; then
        print_warning "inotify limit is low ($CURRENT_WATCHES), increasing for large media libraries..."
        sudo sysctl -w fs.inotify.max_user_watches=524288 > /dev/null 2>&1
        
        # Make permanent
        if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf 2>/dev/null; then
            echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf > /dev/null
        fi
        print_success "inotify limit increased to 524288"
    else
        print_success "inotify limit is adequate ($CURRENT_WATCHES)"
    fi
    echo ""
    
    if ! command -v ffmpeg &> /dev/null; then
        print_warning "ffmpeg not found (needed for video thumbnails)"
        read -p "Install ffmpeg now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt-get update && sudo apt-get install -y ffmpeg
        fi
    fi
    
    print_success "Prerequisites check passed"
    echo ""
}

# Function: Interactive input
interactive_mode() {
    print_info "Running in interactive mode..."
    echo ""
    
    # Get media directory (only if not provided)
    if [ -z "$MEDIA_DIR" ]; then
        while true; do
            read -p "Enter media directory path [/home/osmc/Videos]: " input_media_dir
            MEDIA_DIR="${input_media_dir:-/home/osmc/Videos}"
            
            if [ ! -d "$MEDIA_DIR" ]; then
                print_warning "Directory does not exist: $MEDIA_DIR"
                read -p "Create it? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    mkdir -p "$MEDIA_DIR"
                    print_success "Created $MEDIA_DIR"
                    break
                fi
            else
                print_success "Using media directory: $MEDIA_DIR"
                break
            fi
        done
    else
        print_success "Using provided media directory: $MEDIA_DIR"
    fi
    echo ""
    
    # Get thumbnails directory (only if not provided)
    if [ -z "$THUMB_DIR" ] && [ "$THUMB_DIR" != "provided" ]; then
        read -p "Enter thumbnails directory path [leave empty to use app directory]: " input_thumb_dir
        if [ -z "$input_thumb_dir" ]; then
            THUMB_DIR=""
            print_success "Thumbnails will be stored in app directory"
        else
            THUMB_DIR="$input_thumb_dir"
            if [ ! -d "$THUMB_DIR" ]; then
                print_warning "Directory does not exist: $THUMB_DIR"
                read -p "Create it? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    mkdir -p "$THUMB_DIR"
                    print_success "Created $THUMB_DIR"
                fi
            else
                print_success "Using thumbnails directory: $THUMB_DIR"
            fi
        fi
    else
        print_success "Using provided thumbnails directory: ${THUMB_DIR:-app directory}"
    fi
    echo ""
    
    # Get database file location (only if not provided)
    if [ -z "$DB_FILE" ] && [ "$DB_FILE" != "provided" ]; then
        read -p "Enter database file path [leave empty to use app directory]: " input_db_file
        if [ -z "$input_db_file" ]; then
            DB_FILE=""
            print_success "Database will be stored in app directory (RECOMMENDED)"
        else
            DB_FILE="$input_db_file"
            # Check if path parent directory exists
            db_parent=$(dirname "$DB_FILE")
            if [ ! -d "$db_parent" ]; then
                print_warning "Parent directory does not exist: $db_parent"
                read -p "Create it? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    mkdir -p "$db_parent"
                    print_success "Created $db_parent"
                fi
            else
                print_success "Using database file: $DB_FILE"
            fi
            
            # Warn about unsafe locations
            if [[ "$DB_FILE" == *"/mnt/nas"* ]] || [[ "$DB_FILE" == *"nfs"* ]] || [[ "$DB_FILE" == *"cifs"* ]]; then
                print_warning "⚠️  WARNING: Network storage for database is NOT recommended!"
                print_warning "SQLite on network storage can cause corruption and performance issues."
                echo "     Recommended: Use local SSD or fast external drive."
                read -p "Continue with network storage? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Please enter a local path for the database."
                    read -p "Enter database file path: " input_db_file
                    DB_FILE="$input_db_file"
                fi
            fi
        fi
    else
        print_success "Using provided database file: ${DB_FILE:-app directory}"
    fi
    echo ""
    
    # Get deployment type (only if not provided)
    if [ -z "$DEPLOYMENT_TYPE" ]; then
    echo "Deployment methods:"
    echo "  1) Native (systemd services)"
    echo "  2) Docker (recommended for easy deployment)"
    echo "  3) Docker + Nginx (full stack)"
    read -p "Choose deployment method (1-3) [2]: " -n 1 deployment_choice
    echo ""
    
        case $deployment_choice in
            1) DEPLOYMENT_TYPE="native" ;;
            2) DEPLOYMENT_TYPE="docker" ;;
            3) DEPLOYMENT_TYPE="docker-full" ;;
            *) DEPLOYMENT_TYPE="docker" ;;
        esac
        
        print_success "Selected: $DEPLOYMENT_TYPE"
    else
        print_success "Using provided deployment type: $DEPLOYMENT_TYPE"
    fi
    echo ""
}

# Function: Deploy native
deploy_native() {
    print_info "Starting native deployment..."
    echo ""
    
    # Build frontend (skip if already built on Windows)
    if [ ! -d "$MEDIA_LIBRARY_DIR/frontend-dist" ] || [ -z "$(ls -A $MEDIA_LIBRARY_DIR/frontend-dist 2>/dev/null)" ]; then
        print_info "Building frontend (this may take a minute)..."
        cd "$MEDIA_LIBRARY_DIR/frontend"
        # Increase Node heap size for Raspberry Pi (limited RAM)
        export NODE_OPTIONS="--max-old-space-size=512"
        npm install --silent
        npm run build --silent
        rm -rf "$MEDIA_LIBRARY_DIR/frontend-dist"
        mkdir -p "$MEDIA_LIBRARY_DIR/frontend-dist"
        # Handle both possible build output structures
        if [ -d "dist/media-frontend" ]; then
            cp -r dist/media-frontend/* "$MEDIA_LIBRARY_DIR/frontend-dist/"
        elif [ -d "dist" ]; then
            cp -r dist/* "$MEDIA_LIBRARY_DIR/frontend-dist/"
        else
            print_error "Frontend build output not found"
            exit 1
        fi
        cd "$MEDIA_LIBRARY_DIR"
        print_success "Frontend built and deployed"
    else
        print_info "Using pre-built frontend from Windows deployment..."
        print_success "Frontend ready"
    fi
    echo ""
    
    # Install backend dependencies
    export NODE_OPTIONS="--max-old-space-size=512"
    print_info "Installing backend dependencies..."
    cd "$MEDIA_LIBRARY_DIR/backend"
    
    # Remove node_modules if exists to ensure clean install for ARM architecture
    if [ -d "node_modules" ]; then
        print_info "Removing existing node_modules (Windows binaries)..."
        rm -rf node_modules
    fi
    
    # Clean install on fresh OSMC
    npm install --production
    if [ $? -ne 0 ]; then
        print_error "Failed to install backend dependencies"
        exit 1
    fi
    
    # Create .env
    cat > .env << EOF
PORT=3000
NODE_ENV=production
MEDIA_DIR=$MEDIA_DIR
THUMB_DIR=${THUMB_DIR:-$MEDIA_LIBRARY_DIR/thumbnails}
DB_FILE=$MEDIA_LIBRARY_DIR/media.db
EOF
    print_success "Backend configured"
    echo ""
    
    # Create logs directory with proper permissions
    mkdir -p "$MEDIA_LIBRARY_DIR/logs"
    chmod 755 "$MEDIA_LIBRARY_DIR/logs"
    
    # Install http-server for frontend (lightweight static file server)
    print_info "Installing frontend server (http-server)..."
    cd "$MEDIA_LIBRARY_DIR"
    sudo npm install -g http-server
    if [ $? -ne 0 ]; then
        print_error "Failed to install http-server"
        exit 1
    fi
    print_success "Frontend server installed"
    echo ""
    
    # Find http-server path
    HTTP_SERVER_PATH=$(which http-server)
    if [ -z "$HTTP_SERVER_PATH" ]; then
        # Try common locations
        if [ -f "/usr/local/bin/http-server" ]; then
            HTTP_SERVER_PATH="/usr/local/bin/http-server"
        elif [ -f "/usr/bin/http-server" ]; then
            HTTP_SERVER_PATH="/usr/bin/http-server"
        else
            print_error "Cannot find http-server executable after installation"
            exit 1
        fi
    fi
    print_success "Found http-server at: $HTTP_SERVER_PATH"
    echo ""
    
    # Create systemd service
    print_info "Creating systemd service..."
    
    # Source NVM if it exists to get the correct node path
    if [ -f "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh"
    fi
    
    NODE_PATH=$(which node)
    if [ -z "$NODE_PATH" ]; then
        # Fallback to common locations
        if [ -f "$HOME/.nvm/versions/node/v18*/bin/node" ]; then
            NODE_PATH=$(ls -d $HOME/.nvm/versions/node/v18*/bin/node 2>/dev/null | head -1)
        elif [ -f "/usr/bin/node" ]; then
            NODE_PATH="/usr/bin/node"
        else
            print_error "Cannot find node executable"
            exit 1
        fi
    fi
    
    sudo tee /etc/systemd/system/media-library-backend.service > /dev/null << EOFSERVICE
[Unit]
Description=Media Library Backend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$MEDIA_LIBRARY_DIR/backend
ExecStart=$NODE_PATH $MEDIA_LIBRARY_DIR/backend/app.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment="NODE_ENV=production"
Environment="NODE_OPTIONS=--max-old-space-size=512"

[Install]
WantedBy=multi-user.target
EOFSERVICE
    sudo systemctl daemon-reload
    print_success "Systemd service created (Node: $NODE_PATH)"
    
    # Create systemd service for frontend
    print_info "Creating frontend systemd service..."
    sudo tee /etc/systemd/system/media-library-frontend.service > /dev/null << EOFFRONTEND
[Unit]
Description=Media Library Frontend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$MEDIA_LIBRARY_DIR
ExecStart=$HTTP_SERVER_PATH frontend-dist -p 4200 -c-1 --gzip
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFFRONTEND
    sudo systemctl daemon-reload
    print_success "Frontend systemd service created (http-server: $HTTP_SERVER_PATH)"
    
    # Start service
    print_info "Starting service..."
    sudo systemctl enable media-library-backend
    sudo systemctl start media-library-backend
    
    print_info "Starting frontend service..."
    sudo systemctl enable media-library-frontend
    sudo systemctl start media-library-frontend
    
    sleep 2
    if sudo systemctl is-active --quiet media-library-backend; then
        print_success "Backend service started successfully"
    else
        print_error "Backend service failed to start"
        echo "Check logs: sudo journalctl -u media-library-backend -f"
        exit 1
    fi
    
    if sudo systemctl is-active --quiet media-library-frontend; then
        print_success "Frontend service started successfully"
    else
        print_error "Frontend service failed to start"
        echo "Check logs: sudo journalctl -u media-library-frontend -f"
        exit 1
    fi
    echo ""
}

# Function: Deploy docker
deploy_docker() {
    print_info "Starting docker deployment..."
    echo ""
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        echo "Install with: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        exit 1
    fi
    
    print_success "Docker found: $(docker --version)"
    echo ""
    
    # Build frontend (skip if already built on Windows)
    if [ ! -d "$MEDIA_LIBRARY_DIR/frontend-dist" ] || [ -z "$(ls -A $MEDIA_LIBRARY_DIR/frontend-dist 2>/dev/null)" ]; then
        print_info "Building frontend..."
        cd "$MEDIA_LIBRARY_DIR/frontend"
        # Increase Node heap size for Raspberry Pi (limited RAM)
        export NODE_OPTIONS="--max-old-space-size=512"
        npm install --silent
        npm run build --silent
        mkdir -p "$MEDIA_LIBRARY_DIR/frontend-dist"
        cp -r dist/media-frontend ../frontend-dist
        cd "$MEDIA_LIBRARY_DIR"
        print_success "Frontend built"
    else
        print_info "Using pre-built frontend from Windows deployment..."
        print_success "Frontend ready"
    fi
    echo ""
    
    # Create media link
    print_info "Creating media directories..."
    mkdir -p "$MEDIA_LIBRARY_DIR/media"
    if [ ! -L "$MEDIA_LIBRARY_DIR/media" ] && [ "$MEDIA_DIR" != "$MEDIA_LIBRARY_DIR/media" ]; then
        ln -s "$MEDIA_DIR" "$MEDIA_LIBRARY_DIR/media" 2>/dev/null || true
    fi
    print_success "Directories ready"
    echo ""
    
    # Build Docker image
    print_info "Building Docker image (this may take a few minutes)..."
    cd "$MEDIA_LIBRARY_DIR"
    docker build -t media-library:latest .
    print_success "Docker image built"
    echo ""
    
    # Start container
    print_info "Starting Docker container..."
    docker-compose down 2>/dev/null || true
    docker-compose up -d
    
    sleep 3
    if docker-compose ps | grep -q "media-library.*Up"; then
        print_success "Docker container started"
    else
        print_error "Container failed to start"
        docker-compose logs media-library
        exit 1
    fi
    echo ""
}

# Function: Print access information
print_access_info() {
    local host="${HOSTNAME:-osmc}"
    local ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Deployment Complete!                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$DEPLOYMENT_TYPE" == "native" ]; then
        echo "Backend API:        http://$host:3000"
        echo "Frontend:           http://$host:4200"
        echo ""
        echo "Or from another computer:"
        echo "  Backend API:      http://$ip:3000"
        echo "  Frontend:         http://$ip:4200"
        echo ""
        echo "View logs:"
        echo "  Backend: sudo journalctl -u media-library-backend -f"
        echo "  Frontend: sudo journalctl -u media-library-frontend -f"
        echo ""
        echo "Check service status:"
        echo "  sudo systemctl status media-library-backend"
        echo "  sudo systemctl status media-library-frontend"
        echo ""
        echo "Stop services:"
        echo "  sudo systemctl stop media-library-backend media-library-frontend"
        echo ""
        echo "Restart services:"
        echo "  sudo systemctl restart media-library-backend media-library-frontend"
    else
        echo "Access at:          http://$host:4200 (or http://$ip:4200)"
        echo "Backend API:        http://$host:3000 (or http://$ip:3000)"
        echo ""
        echo "View logs:"
        echo "  docker-compose logs -f media-library"
        echo ""
        echo "Stop containers:"
        echo "  docker-compose down"
        echo ""
        echo "Restart containers:"
        echo "  docker-compose up -d"
    fi
    echo ""
    echo "Media directory:    $MEDIA_DIR"
    echo "Thumbnails dir:     ${THUMB_DIR:-$MEDIA_LIBRARY_DIR/thumbnails}"
    echo "Database file:      ${DB_FILE:-$MEDIA_LIBRARY_DIR/media.db}"
    echo "Library directory:  $MEDIA_LIBRARY_DIR"
    echo ""
    print_success "Ready to use!"
}

# Main execution
main() {
    # Check if interactive mode needed
    if [ -z "$MEDIA_DIR" ] || [ -z "$DEPLOYMENT_TYPE" ]; then
        check_prerequisites
        interactive_mode
    else
        check_prerequisites
    fi
    
    # Validate media directory
    if [ ! -d "$MEDIA_DIR" ]; then
        print_error "Media directory not found: $MEDIA_DIR"
        exit 1
    fi
    
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Media Directory:      $MEDIA_DIR"
    echo "  Thumbnails Directory: ${THUMB_DIR:-$MEDIA_LIBRARY_DIR/thumbnails}"
    echo "  Database File:        ${DB_FILE:-$MEDIA_LIBRARY_DIR/media.db}"
    echo "  Deployment Type:      $DEPLOYMENT_TYPE"
    echo "  Library Dir:          $MEDIA_LIBRARY_DIR"
    echo ""
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
    echo ""
    
    # Execute deployment
    case $DEPLOYMENT_TYPE in
        native)
            deploy_native
            ;;
        docker|docker-full)
            deploy_docker
            ;;
        *)
            print_error "Unknown deployment type: $DEPLOYMENT_TYPE"
            exit 1
            ;;
    esac
    
    # Print access information
    print_access_info
}

# Run main function
main

