import express from "express";
import cors from "cors";
import morgan from "morgan";
import sqlite3 from "sqlite3";
import { open } from "sqlite";
import chokidar from "chokidar";
import path from "path";
import fs from "fs";
import sharp from "sharp";
import ffmpeg from "fluent-ffmpeg";
import { parseFile } from "music-metadata";
import mime from "mime-types";
import pdf from "pdf-poppler";
import { fromPath } from 'pdf2pic';
import dotenv from "dotenv";

dotenv.config();

const MEDIA_DIR = process.env.MEDIA_DIR || "./media";
const THUMB_DIR = process.env.THUMB_DIR || "./thumbnails";
const MEDIA_DIR_ABS = path.resolve(MEDIA_DIR);
const THUMB_DIR_ABS = path.resolve(THUMB_DIR);
const DB_FILE = process.env.DB_FILE || "media.db";
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || "development";

if (!fs.existsSync(THUMB_DIR_ABS)) fs.mkdirSync(THUMB_DIR_ABS, { recursive: true });

const app = express();
app.use(express.json());
app.use(cors());
app.use(morgan(NODE_ENV === "production" ? "combined" : "dev"));

// Serve thumbnails statically
app.use("/thumbnails", express.static(THUMB_DIR_ABS));

let db;

// --- DB INIT ---
async function initDB() {
  db = await open({
    filename: DB_FILE,
    driver: sqlite3.Database,
  });

  await db.exec(`
    CREATE TABLE IF NOT EXISTS media (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filePath TEXT UNIQUE,
      album TEXT,
      type TEXT,
      thumbnailPath TEXT,
      duration INTEGER,
      resolution TEXT,
      fileSize INTEGER,
      createdAt TEXT,
      lastModified INTEGER,
      isFavorite INTEGER DEFAULT 0
    )
  `);

  // Add isFavorite column if it doesn't exist (for existing databases)
  try {
    await db.exec(`ALTER TABLE media ADD COLUMN isFavorite INTEGER DEFAULT 0`);
  } catch (e) {
    // Column already exists, ignore
  }

  await db.exec(`CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE
  )`);

  await db.exec(`CREATE TABLE IF NOT EXISTS media_tags (
    media_id INTEGER,
    tag_id INTEGER,
    PRIMARY KEY (media_id, tag_id),
    FOREIGN KEY (media_id) REFERENCES media(id),
    FOREIGN KEY (tag_id) REFERENCES tags(id)
  )`);

  await db.exec(`CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE
  )`);

  await db.exec(`CREATE TABLE IF NOT EXISTS playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER,
    media_id INTEGER,
    FOREIGN KEY (playlist_id) REFERENCES playlists(id),
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);

  // Create indexes for better performance
  await db.exec(`CREATE INDEX IF NOT EXISTS idx_media_album ON media(album)`);
  await db.exec(`CREATE INDEX IF NOT EXISTS idx_media_type ON media(type)`);
  await db.exec(`CREATE INDEX IF NOT EXISTS idx_media_tags_media_id ON media_tags(media_id)`);
}

// --- METADATA EXTRACTION ---
async function extractMetadata(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  let type = "other";
  let duration = null;

  if ([".jpg", ".jpeg", ".png", ".gif", ".webp"].includes(ext)) {
    type = "image";
  } else if ([".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg"].includes(ext)) {
    type = "music";
    try {
      const metadata = await parseFile(filePath);
      duration = metadata.format.duration || null;
    } catch {}
  } else if ([".mp4", ".mkv", ".avi", ".mov", ".webm"].includes(ext)) {
    type = "video";
  } else if ([".pdf",".txt"].includes(ext)) {
    type = "pdf";
  }

  return { type, duration };
}

// --- THUMBNAIL GENERATION ---
async function generateThumbnail(filePath, type) {
  const hashName = Buffer.from(filePath).toString("base64") + ".jpg";
  const thumbPath = path.join(THUMB_DIR_ABS, hashName);

  if (fs.existsSync(thumbPath)) return hashName;
  
  try {
    if (type === "image") {
      await sharp(filePath).resize(200, 200, { fit: 'cover' }).toFile(thumbPath);
    } else if (type === "video") {
      await new Promise((resolve, reject) => {
        ffmpeg(filePath)
          .screenshots({
            timestamps: ["50%"],
            filename: hashName,
            folder: THUMB_DIR_ABS,
            size: "200x?",
          })
          .on("end", resolve)
          .on("error", reject);
      });
    } else if (type === "pdf") {
      console.log("generating thumbnail for ", hashName, filePath);
      const pdf2pic = fromPath(filePath, {
        density: 100,
        saveFilename: hashName,
        savePath: THUMB_DIR_ABS,
        format: 'jpg',
        width: 200,
        height: 200,
      });
      await pdf2pic(1); // first page
    } else {
      return null;
    }
    return hashName;
  } catch {
    return null;
  }
}

// --- INDEX FILE ---
async function indexFile(filePath) {
  try {
    const absolutePath = path.resolve(filePath);
    if (absolutePath.startsWith(THUMB_DIR_ABS)) return; // Skip generated thumbnails

    const stats = fs.statSync(absolutePath);
    if (stats.isDirectory()) return;

    const album = path.basename(path.dirname(absolutePath));
    const { type, duration } = await extractMetadata(absolutePath);
    const thumbName = await generateThumbnail(absolutePath, type);

    const resultMedia = await db.run(
      `INSERT OR REPLACE INTO media 
        (filePath, album, type, thumbnailPath, duration, fileSize, createdAt, lastModified) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [absolutePath, album, type, thumbName, duration, stats.size, new Date(stats.birthtime).toISOString(), stats.mtimeMs]
    );

  } catch (err) {
    console.error("Indexing error:", err.message);
  }
}

// --- FILE WATCHER ---
function watchFiles() {
  const watcher = chokidar.watch(MEDIA_DIR_ABS, {
    persistent: true,
    ignoreInitial: false,
    depth: 10,
    ignored: (watchPath) => watchPath.startsWith(THUMB_DIR_ABS),
  });

  watcher
    .on("add", indexFile)
    .on("change", indexFile)
    .on("unlink", async (filePath) => {
      await db.run("DELETE FROM media WHERE filePath = ?", filePath);
    });
}

// --- API ROUTES ---

// Helper: Validate pagination params
function validatePagination(page, limit) {
  const p = Math.max(1, parseInt(page) || 1);
  const l = Math.max(1, Math.min(100, parseInt(limit) || 50)); // Cap at 100
  return { page: p, limit: l };
}

// Helper: Format file size
function formatFileSize(bytes) {
  if (!bytes) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i];
}

app.get('/albums', async (req, res) => {
  try {
    const { page: p, limit: l } = validatePagination(req.query.page, req.query.limit);
    const offset = (p - 1) * l;

    const total = await db.get('SELECT COUNT(DISTINCT album) as count FROM media');
    const albums = await db.all(
      'SELECT DISTINCT album FROM media LIMIT ? OFFSET ?',
      [l, offset]
    );

    res.json({
      total: total.count,
      page: p,
      limit: l,
      albums: albums.map(a => a.album)
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch albums' });
  }
});

app.get('/files/:id', async (req, res) => {
  try {
    const mediaId = req.params.id;
    const file = await db.get('SELECT * FROM media WHERE id = ?', [mediaId]);

    if (!file) return res.status(404).json({ error: 'File not found' });

    const tags = await db.all(
      'SELECT t.* FROM tags t JOIN media_tags mt ON t.id = mt.tag_id WHERE mt.media_id = ?',
      [mediaId]
    );

    res.json({ ...file, tags });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch file' });
  }
});

app.get('/files', async (req, res) => {
  try {
    const album = req.query.album || '';
    const typeFilter = req.query.type || ''; // image, video, music, pdf
    const sortBy = req.query.sortBy || 'createdAt'; // createdAt, filePath, fileSize
    const sortOrder = req.query.sortOrder === 'asc' ? 'ASC' : 'DESC';
    const { page: p, limit: l } = validatePagination(req.query.page, req.query.limit);
    const offset = (p - 1) * l;

    let whereClause = '';
    const params = [];
    const whereClauses = [];
    
    if (album) {
      whereClauses.push('album = ?');
      params.push(album);
    }
    if (typeFilter) {
      whereClauses.push('type = ?');
      params.push(typeFilter);
    }
    
    if (whereClauses.length > 0) {
      whereClause = 'WHERE ' + whereClauses.join(' AND ');
    }

    const validSortFields = ['createdAt', 'filePath', 'fileSize'];
    const orderBy = validSortFields.includes(sortBy) ? sortBy : 'createdAt';

    const total = await db.get(`SELECT COUNT(*) as count FROM media ${whereClause}`, params);
    
    const filesWithTags = await db.all(`
      SELECT 
        m.*,
        GROUP_CONCAT(t.name) as tags
      FROM media m
      LEFT JOIN media_tags mt ON m.id = mt.media_id
      LEFT JOIN tags t ON mt.tag_id = t.id
      ${whereClause}
      GROUP BY m.id
      ORDER BY m.${orderBy} ${sortOrder}
      LIMIT ? OFFSET ?
    `, [...params, l, offset]);

    const files = filesWithTags.map(f => ({
      ...f,
      tags: f.tags ? f.tags.split(',') : [],
      fileSizeFormatted: formatFileSize(f.fileSize)
    }));

    res.json({
      total: total.count,
      page: p,
      limit: l,
      files
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch files' });
  }
});

app.post('/files/:id/tags', async (req, res) => {
  try {
    const mediaId = parseInt(req.params.id);
    const { name } = req.body;
    
    if (!mediaId || mediaId < 1) return res.status(400).json({ error: 'Invalid file ID' });
    if (!name || typeof name !== 'string' || !name.trim() || name.length > 50) {
      return res.status(400).json({ error: 'Tag name must be 1-50 characters' });
    }

    // Insert tag if it doesn't exist
    let tag = await db.get('SELECT * FROM tags WHERE name = ?', [name.trim()]);
    if (!tag) {
      const result = await db.run('INSERT INTO tags (name) VALUES (?)', [name.trim()]);
      tag = { id: result.lastID, name: name.trim() };
    }

    // Link tag to file
    await db.run('INSERT OR IGNORE INTO media_tags (media_id, tag_id) VALUES (?, ?)', [mediaId, tag.id]);

    res.json({ success: true, tag });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to add tag' });
  }
});

// Delete tag from file
app.delete('/files/:id/tags/:tagName', async (req, res) => {
  try {
    const mediaId = parseInt(req.params.id);
    const tagName = decodeURIComponent(req.params.tagName);
    
    if (!mediaId || mediaId < 1) return res.status(400).json({ error: 'Invalid file ID' });
    if (!tagName) return res.status(400).json({ error: 'Tag name is required' });

    const tag = await db.get('SELECT * FROM tags WHERE name = ?', [tagName]);
    if (!tag) return res.status(404).json({ error: 'Tag not found' });

    await db.run('DELETE FROM media_tags WHERE media_id = ? AND tag_id = ?', [mediaId, tag.id]);
    
    res.json({ success: true, message: 'Tag removed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to delete tag' });
  }
});

// Toggle favorite
app.post('/files/:id/favorite', async (req, res) => {
  try {
    const mediaId = parseInt(req.params.id);
    if (!mediaId || mediaId < 1) return res.status(400).json({ error: 'Invalid file ID' });

    const file = await db.get('SELECT isFavorite FROM media WHERE id = ?', [mediaId]);
    if (!file) return res.status(404).json({ error: 'File not found' });

    const newValue = file.isFavorite ? 0 : 1;
    await db.run('UPDATE media SET isFavorite = ? WHERE id = ?', [newValue, mediaId]);
    
    res.json({ success: true, isFavorite: newValue === 1 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to toggle favorite' });
  }
});

// Get all favorites
app.get('/favorites', async (req, res) => {
  try {
    const { page: p, limit: l } = validatePagination(req.query.page, req.query.limit);
    const offset = (p - 1) * l;

    const total = await db.get('SELECT COUNT(*) as count FROM media WHERE isFavorite = 1');
    
    const filesWithTags = await db.all(`
      SELECT 
        m.*,
        GROUP_CONCAT(t.name) as tags
      FROM media m
      LEFT JOIN media_tags mt ON m.id = mt.media_id
      LEFT JOIN tags t ON mt.tag_id = t.id
      WHERE m.isFavorite = 1
      GROUP BY m.id
      ORDER BY m.createdAt DESC
      LIMIT ? OFFSET ?
    `, [l, offset]);

    const files = filesWithTags.map(f => ({
      ...f,
      tags: f.tags ? f.tags.split(',') : [],
      fileSizeFormatted: formatFileSize(f.fileSize)
    }));

    res.json({ total: total.count, page: p, limit: l, files });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch favorites' });
  }
});

// Get all unique tags for autocomplete
app.get('/tags', async (req, res) => {
  try {
    const tags = await db.all('SELECT name FROM tags ORDER BY name ASC');
    res.json({ tags: tags.map(t => t.name) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch tags' });
  }
});


// --- Media streaming with Range ---
app.get("/media/:id", async (req, res) => {
  try {
    const file = await db.get("SELECT * FROM media WHERE id = ?", req.params.id);
    if (!file) return res.status(404).json({ error: "File not found" });

    const filePath = path.resolve(file.filePath);
    if (!fs.existsSync(filePath)) return res.status(404).json({ error: "File not found on disk" });
    
    const stat = fs.statSync(filePath);
    const fileSize = stat.size;
    const range = req.headers.range;
    const contentType = mime.lookup(filePath) || "application/octet-stream";

    // 🔸 If it's a PDF, serve full file (no partial streaming)
    if (contentType === "application/pdf") {
      res.writeHead(200, {
        "Content-Length": fileSize,
        "Content-Type": contentType,
        "Accept-Ranges": "none",
      });
      fs.createReadStream(filePath).pipe(res);
      return;
    }

    if (range) {
      const [startStr, endStr] = range.replace(/bytes=/, "").split("-");
      const start = parseInt(startStr, 10);
      const end = endStr ? parseInt(endStr, 10) : fileSize - 1;

      if (start >= fileSize) {
        res.status(416).json({ error: "Range Not Satisfiable" });
        return;
      }

      const chunkSize = end - start + 1;
      const stream = fs.createReadStream(filePath, { start, end });

      res.writeHead(206, {
        "Content-Range": `bytes ${start}-${end}/${fileSize}`,
        "Accept-Ranges": "bytes",
        "Content-Length": chunkSize,
        "Content-Type": contentType,
      });
      stream.pipe(res);
    } else {
      res.writeHead(200, {
        "Content-Length": fileSize,
        "Content-Type": contentType,
      });
      fs.createReadStream(filePath).pipe(res);
    }
  } catch (err) {
    console.error("Media streaming error:", err.message);
    res.status(500).json({ error: "Failed to stream media" });
  }
});

app.get("/search", async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.trim().length < 2) {
      return res.json({ files: [] });
    }
    
    const searchTerm = `%${q.trim()}%`;
    
    // Search in files and tags
    const files = await db.all(`
      SELECT DISTINCT m.* FROM media m
      LEFT JOIN media_tags mt ON m.id = mt.media_id
      LEFT JOIN tags t ON mt.tag_id = t.id
      WHERE m.filePath LIKE ? OR m.album LIKE ? OR t.name LIKE ?
    `, [searchTerm, searchTerm, searchTerm]);
    
    // Fetch tags for results
    for (const file of files) {
      const tags = await db.all(
        'SELECT name FROM tags t JOIN media_tags mt ON t.id = mt.tag_id WHERE mt.media_id = ?',
        [file.id]
      );
      file.tags = tags.map(t => t.name);
      file.fileSizeFormatted = formatFileSize(file.fileSize);
    }
    
    res.json({ files });
  } catch (err) {
    console.error("Search error:", err.message);
    res.status(500).json({ error: 'Search failed' });
  }
});

// --- STARTUP ---
(async () => {
  await initDB();
  watchFiles();
  app.listen(PORT, () => {
    console.log(`✅ Media library running at http://localhost:${PORT}`);
    console.log(`📁 Media directory: ${MEDIA_DIR}`);
    console.log(`🗄️ Database: ${DB_FILE}`);
    console.log(`🔧 Environment: ${NODE_ENV}`);
  });
})();
