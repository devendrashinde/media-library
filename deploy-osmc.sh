#!/bin/bash

################################################################################
# Media Library - OSMC Quick Deployment Script
# 
# Usage: ./deploy-osmc.sh [MEDIA_DIR] [DEPLOYMENT_TYPE]
# Examples:
#   ./deploy-osmc.sh /home/osmc/Videos native
#   ./deploy-osmc.sh /home/osmc/Videos docker
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
MEDIA_LIBRARY_DIR="/opt/media-library"
MEDIA_DIR="${1:-}"
DEPLOYMENT_TYPE="${2:-}"

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
    
    if ! command -v npm &> /dev/null; then
        print_error "npm not found!"
        exit 1
    fi
    
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
    
    # Get media directory
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
    echo ""
    
    # Get deployment type
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
    echo ""
}

# Function: Deploy native
deploy_native() {
    print_info "Starting native deployment..."
    echo ""
    
    # Create directories
    print_info "Creating directories..."
    sudo mkdir -p $MEDIA_LIBRARY_DIR/{backend,frontend-dist,thumbnails,logs}
    sudo chown -R $USER:$USER $MEDIA_LIBRARY_DIR
    print_success "Directories created"
    echo ""
    
    # Build frontend
    print_info "Building frontend (this may take a minute)..."
    cd frontend
    npm install --silent
    npm run build --silent
    cp -r dist/media-frontend/* ../$MEDIA_LIBRARY_DIR/frontend-dist/
    cd ..
    print_success "Frontend built and deployed"
    echo ""
    
    # Copy backend
    print_info "Deploying backend..."
    cp -r backend/* $MEDIA_LIBRARY_DIR/backend/
    cd $MEDIA_LIBRARY_DIR/backend
    npm install --production --silent
    
    # Create .env
    cat > .env << EOF
PORT=3000
NODE_ENV=production
MEDIA_DIR=$MEDIA_DIR
THUMB_DIR=$MEDIA_LIBRARY_DIR/thumbnails
DB_FILE=$MEDIA_LIBRARY_DIR/media.db
EOF
    print_success "Backend deployed"
    echo ""
    
    # Create systemd service
    print_info "Creating systemd service..."
    sudo tee /etc/systemd/system/media-library-backend.service > /dev/null << EOF
[Unit]
Description=Media Library Backend Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$MEDIA_LIBRARY_DIR/backend
ExecStart=/usr/bin/node $MEDIA_LIBRARY_DIR/backend/app.js
Restart=always
RestartSec=10
StandardOutput=append:$MEDIA_LIBRARY_DIR/logs/backend.log
StandardError=append:$MEDIA_LIBRARY_DIR/logs/backend.log
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    print_success "Systemd service created"
    echo ""
    
    # Start service
    print_info "Starting service..."
    sudo systemctl enable media-library-backend
    sudo systemctl start media-library-backend
    
    sleep 2
    if sudo systemctl is-active --quiet media-library-backend; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start"
        echo "Check logs: sudo journalctl -u media-library-backend -f"
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
    
    # Build frontend
    print_info "Building frontend..."
    cd frontend
    npm install --silent
    npm run build --silent
    cp -r dist/media-frontend ../frontend-dist
    cd ..
    print_success "Frontend built"
    echo ""
    
    # Create directories
    print_info "Creating media directories..."
    mkdir -p ./media
    if [ ! -L "./media" ] && [ "$MEDIA_DIR" != "./media" ]; then
        ln -s "$MEDIA_DIR" ./media 2>/dev/null || true
    fi
    print_success "Directories ready"
    echo ""
    
    # Build Docker image
    print_info "Building Docker image (this may take a few minutes)..."
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
        echo "  tail -f $MEDIA_LIBRARY_DIR/logs/backend.log"
        echo ""
        echo "Check service status:"
        echo "  sudo systemctl status media-library-backend"
        echo ""
        echo "Stop service:"
        echo "  sudo systemctl stop media-library-backend"
        echo ""
        echo "Restart service:"
        echo "  sudo systemctl restart media-library-backend"
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
    echo "  Media Directory:  $MEDIA_DIR"
    echo "  Deployment Type:  $DEPLOYMENT_TYPE"
    echo "  Library Dir:      $MEDIA_LIBRARY_DIR"
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

