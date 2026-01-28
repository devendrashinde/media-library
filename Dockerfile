FROM node:18-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    ffmpeg \
    graphicsmagick \
    python3 \
    make \
    g++

# Copy backend
COPY backend/ /app/backend/
WORKDIR /app/backend

# Install backend dependencies
RUN npm install --production

# Copy frontend (pre-built)
COPY frontend-dist/ /app/frontend-dist/

# Create frontend server
RUN echo 'const express = require("express"); \
const path = require("path"); \
const app = express(); \
app.use(express.static(path.join(__dirname, "../frontend-dist"))); \
app.get("*", (req, res) => res.sendFile(path.join(__dirname, "../frontend-dist/index.html"))); \
app.listen(4200, () => console.log("Frontend: 4200")); \
' > /app/frontend-server.js

# Create data directories
RUN mkdir -p /data/media /data/thumbnails

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV MEDIA_DIR=/data/media
ENV THUMB_DIR=/data/thumbnails
ENV DB_FILE=/data/media.db

# Expose ports
EXPOSE 3000 4200

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/search?q=test', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start both services
CMD node /app/frontend-server.js & node /app/backend/app.js

