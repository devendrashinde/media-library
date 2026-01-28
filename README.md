# Media Library

A full-stack web application for browsing, organizing, and playing your media collection (images, videos, music, and PDFs) with automatic thumbnail generation, metadata extraction, and powerful filtering capabilities.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Node.js](https://img.shields.io/badge/node.js-18+-green.svg)
![Angular](https://img.shields.io/badge/angular-17-red.svg)

## ✨ Features

### Media Management
- 📁 **Album-based organization** - Automatically organizes media by directory structure
- 🔍 **Powerful search** - Search across albums and file names
- 🏷️ **Tagging system** - Tag and categorize your media files
- ⭐ **Favorites** - Mark and filter favorite items
- 📊 **Multiple view modes** - Grid sizes (small, medium, large)
- 🔄 **Real-time file watching** - Automatically detects new files and changes

### Media Types Support
- 🖼️ **Images** - JPEG, PNG, GIF, WebP, etc.
- 🎥 **Videos** - MP4, MKV, AVI, MOV, etc.
- 🎵 **Music** - MP3, FLAC, WAV, OGG, etc. with metadata extraction
- 📄 **PDFs** - Thumbnail generation and viewing

### Playback & Viewing
- ▶️ **Built-in media player** - Audio and video playback
- 📑 **PDF viewer** - Direct PDF rendering
- 🎬 **Playlist support** - Create and manage playlists
- ⏭️ **Sequential playback** - Navigate through media seamlessly

### UX Features
- 🎨 **Dark/Light mode** - Toggle between themes
- 📱 **Responsive design** - Works on desktop and mobile
- ⚡ **Performance optimized** - Pagination and lazy loading
- 🔝 **Smooth navigation** - Scroll-to-top and keyboard shortcuts
- 📈 **Sorting options** - Sort by date, name, or file size

## 🏗️ Architecture

### Backend
- **Node.js + Express** - REST API server
- **SQLite** - Lightweight database for metadata
- **FFmpeg** - Video thumbnail generation and metadata extraction
- **Sharp** - Image processing and thumbnail generation
- **Chokidar** - File system watching

### Frontend
- **Angular 17** - Modern web framework
- **RxJS** - Reactive programming
- **TypeScript** - Type-safe development

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ and npm
- FFmpeg (for video processing)
- GraphicsMagick (for advanced image processing)

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd media-library
   ```

2. **Install backend dependencies**
   ```bash
   cd backend
   npm install
   ```

3. **Install frontend dependencies**
   ```bash
   cd ../frontend
   npm install
   ```

4. **Configure environment** (optional)
   
   Create a `.env` file in the backend directory:
   ```env
   MEDIA_DIR=./media
   THUMB_DIR=./thumbnails
   DB_FILE=media.db
   PORT=3000
   NODE_ENV=development
   ```

5. **Start the backend**
   ```bash
   cd backend
   npm start
   ```
   Backend will run at http://localhost:3000

6. **Start the frontend** (in a new terminal)
   ```bash
   cd frontend
   npm start
   ```
   Frontend will run at http://localhost:4200

7. **Access the application**
   
   Open your browser to http://localhost:4200

### Quick Setup with Docker

The easiest way to run the application:

```bash
# Build and start
docker-compose up -d

# Access the application
# Frontend: http://localhost:4200
# Backend API: http://localhost:3000
```

Place your media files in the `./media` directory and they will be automatically indexed.

## 📦 Deployment

### Docker Deployment (Recommended)

1. **Build the frontend**
   ```bash
   cd frontend
   npm run build
   cp -r dist/media-frontend ../frontend-dist
   ```

2. **Build and run with Docker Compose**
   ```bash
   docker-compose up -d
   ```

3. **Configure volumes**
   
   Edit `docker-compose.yml` to point to your media directory:
   ```yaml
   volumes:
     - /path/to/your/media:/data/media
   ```

### Raspberry Pi / OSMC Deployment

For detailed instructions on deploying to Raspberry Pi running OSMC:

- **From Windows**: See [DEPLOY_FROM_WINDOWS.md](DEPLOY_FROM_WINDOWS.md)
- **General OSMC Setup**: See [OSMC_DEPLOYMENT_GUIDE.md](OSMC_DEPLOYMENT_GUIDE.md)
- **Docker on OSMC**: See [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)

Quick deployment from Windows:
```powershell
.\deploy-to-pi.ps1 -PiHost 192.168.1.XXX -PiUser osmc -MediaDir /path/to/media
```

### Production Deployment

For production configuration and optimizations, see [PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md)

## 📖 API Documentation

### Albums
- `GET /albums?page=1&limit=50&search=query` - Get paginated albums
- `GET /albums/:album?page=1&limit=50&type=image&sortBy=createdAt&order=desc` - Get files in album

### Search
- `GET /search?q=query&page=1&limit=50` - Search across all media

### Media Operations
- `GET /media/:id` - Stream media file
- `POST /media/:id/favorite` - Toggle favorite status
- `PUT /media/:id/tags` - Update media tags
- `DELETE /media/:id` - Delete media file

### Tags
- `GET /tags` - Get all tags
- `POST /tags` - Create new tag

### Playlists
- `GET /playlists` - Get all playlists
- `POST /playlists` - Create playlist
- `GET /playlists/:id/items` - Get playlist items
- `POST /playlists/:id/items` - Add item to playlist
- `DELETE /playlists/:id/items/:mediaId` - Remove item from playlist

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MEDIA_DIR` | `./media` | Directory containing your media files |
| `THUMB_DIR` | `./thumbnails` | Directory for generated thumbnails |
| `DB_FILE` | `media.db` | SQLite database file path |
| `PORT` | `3000` | Backend server port |
| `NODE_ENV` | `development` | Environment mode |

### Frontend Proxy Configuration

The frontend uses a proxy configuration (`proxy.conf.json`) to route API calls to the backend during development.

## 🛠️ Development

### Project Structure

```
media-library/
├── backend/              # Node.js/Express backend
│   ├── app.js           # Main application file
│   ├── package.json     # Backend dependencies
│   ├── media/           # Media files directory
│   └── thumbnails/      # Generated thumbnails
├── frontend/            # Angular frontend
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/   # UI components
│   │   │   └── services/     # Angular services
│   │   └── environments/     # Environment configs
│   └── package.json     # Frontend dependencies
├── docker-compose.yml   # Docker Compose configuration
├── Dockerfile          # Docker image definition
└── deploy-to-pi.ps1    # Windows deployment script
```

### Available Scripts

**Backend:**
- `npm start` - Start the backend server

**Frontend:**
- `npm start` - Start development server with proxy
- `npm run build` - Build for production
- `npm test` - Run tests
- `npm run lint` - Lint code

## 🐛 Troubleshooting

### Common Issues

**Thumbnails not generating:**
- Ensure FFmpeg is installed and in PATH
- Check write permissions on thumbnails directory
- Verify media files are in supported formats

**Port conflicts:**
- Change PORT in backend .env file
- Update proxy.conf.json in frontend if backend port changes

**Database locked:**
- Ensure only one instance of the backend is running
- Check file permissions on database file

**File watching not working:**
- Large directories may exceed system limits
- Increase system file watch limits (Linux/Mac)

## 📝 Recent Improvements

- ✅ Enhanced UX with favorites, tags, and advanced filtering
- ✅ Improved performance with pagination and lazy loading
- ✅ Mobile-responsive design
- ✅ Dark mode support
- ✅ Playlist functionality
- ✅ Real-time file system monitoring
- ✅ Comprehensive deployment options

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- FFmpeg for media processing
- Sharp for image processing
- Angular team for the amazing framework
- All open-source contributors

## 📧 Support

For issues and questions, please open an issue on the repository.

---

**Note:** Make sure to configure your media directory path before first use. The application will automatically scan and index all supported media files in the specified directory.
