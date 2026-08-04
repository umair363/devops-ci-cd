const express = require('express');
const mysql = require('mysql2/promise');
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const { S3Client, ListObjectsV2Command, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const multer = require('multer');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Multer — store file in memory, send straight to S3 (no local disk)
const upload = multer({ storage: multer.memoryStorage() });

const REGION     = process.env.AWS_REGION   || "eu-north-1";
const SECRET_NAME = process.env.SECRET_NAME || "assessment-db-secret";
const S3_BUCKET   = process.env.S3_BUCKET   || "laravel-app-storage-umair63";

const secretsClient = new SecretsManagerClient({ region: REGION });
const s3Client      = new S3Client({ region: REGION });

// ── DB Init ──────────────────────────────────────────────────────────────────
let dbPool;

async function getDbCredentials() {
    try {
        const response = await secretsClient.send(
            new GetSecretValueCommand({ SecretId: SECRET_NAME })
        );
        return JSON.parse(response.SecretString);
    } catch (err) {
        console.warn("Secrets Manager unavailable, falling back to env vars:", err.message);
        return {
            host:     process.env.DB_HOST     || "localhost",
            username: process.env.DB_USER     || "root",
            password: process.env.DB_PASSWORD || "",
            dbname:   process.env.DB_NAME     || "assessment_db"
        };
    }
}

async function initDb() {
    try {
        const creds = await getDbCredentials();
        dbPool = mysql.createPool({
            host:             creds.host,
            user:             creds.username,
            password:         creds.password,
            database:         creds.dbname,
            waitForConnections: true,
            connectionLimit:  10,
            queueLimit:       0
        });
        await dbPool.query(`
            CREATE TABLE IF NOT EXISTS records (
                id          INT AUTO_INCREMENT PRIMARY KEY,
                title       VARCHAR(255) NOT NULL,
                description TEXT,
                created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("Database initialized successfully.");
    } catch (err) {
        console.error("Failed to initialize database:", err.message);
    }
}

initDb();

// ── Routes ───────────────────────────────────────────────────────────────────

// Add a record
app.post('/api/add', async (req, res) => {
    const { title, description } = req.body;
    if (!title || !description) return res.status(400).json({ error: "Missing fields" });
    try {
        if (!dbPool) throw new Error("Database not initialized");
        const [result] = await dbPool.query(
            'INSERT INTO records (title, description) VALUES (?, ?)', [title, description]
        );
        res.json({ success: true, id: result.insertId, title, description });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List records
app.get('/api/list', async (req, res) => {
    try {
        if (!dbPool) throw new Error("Database not initialized");
        const [rows] = await dbPool.query('SELECT * FROM records ORDER BY created_at DESC');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upload image → S3
app.post('/api/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: "No file provided" });

    const key = `uploads/${Date.now()}-${req.file.originalname}`;

    try {
        await s3Client.send(new PutObjectCommand({
            Bucket:      S3_BUCKET,
            Key:         key,
            Body:        req.file.buffer,
            ContentType: req.file.mimetype,
        }));
        res.json({ success: true, key });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List images from S3 with presigned URLs (valid 1 hour)
app.get('/api/images', async (req, res) => {
    try {
        const { Contents } = await s3Client.send(
            new ListObjectsV2Command({ Bucket: S3_BUCKET })
        );
        if (!Contents || Contents.length === 0) return res.json([]);

        const imageKeys = Contents.filter(item =>
            item.Key.match(/\.(jpg|jpeg|png|gif|webp)$/i)
        );

        const images = await Promise.all(imageKeys.map(async (item) => {
            const url = await getSignedUrl(
                s3Client,
                new GetObjectCommand({ Bucket: S3_BUCKET, Key: item.Key }),
                { expiresIn: 3600 }
            );
            return { key: item.Key, url };
        }));

        res.json(images);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
