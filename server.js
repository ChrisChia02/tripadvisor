const express = require("express");
const { Pool } = require("pg");
require("dotenv").config(); // Load environment variables
const multer = require("multer");
const path = require("path");

const app = express();
const PORT = 3000;

const pool = new Pool({
  user: process.env.DB_USER || "tripadmin",  // Change to your actual username
  host: process.env.DB_HOST || "localhost",
  database: process.env.DB_NAME || "trip_advisor_db",
  password: String(process.env.DB_PASSWORD || "Admin123"),  // 🔹 Convert password to string
  port: process.env.DB_PORT || 5432,
  connectionString: process.env.DATABASE_URL || "postgresql://admin:cVAvpCgiFmd6jaqCKFbq4K47ScgG6QPX@dpg-cvi6l4popnds73fqnkr0-a/trip_advisor_db",
  ssl: false,  // 🔹 Ensure SSL is disabled if not supported
});

pool.connect((err, client, release) => {
  if (err) {
    console.error("❌ Database connection failed:", err);
  } else {
    console.log("✅ Connected to PostgreSQL Database");
    release();
  }
});

module.exports = pool;

// Middleware to parse JSON
app.use(express.json());
app.use("/uploads", express.static("uploads")); // Serve uploaded images

// ✅ Define `storage` for Multer
const storage = multer.diskStorage({
    destination: "./uploads/",
    filename: (req, file, cb) => {
        cb(null, "profile_" + Date.now() + path.extname(file.originalname));
    }
});

// ✅ Define `upload` before using it
const upload = multer({ storage });

// ✅ Connect to PostgreSQL
const db = new Pool({
    user: "tripadmin",        // Your PostgreSQL username
    host: "localhost",        // Change to your cloud host if using Render
    database: "trip_advisor_db", // Your database name
    password: "Admin123", // Your PostgreSQL password
    port: 5432,              // Default PostgreSQL port
});

db.connect()
    .then(() => console.log("✅ Connected to PostgreSQL Database"))
    .catch(err => console.error("❌ Database connection error:", err));

// ✅ API to Register a New User
app.post("/register", async (req, res) => {
    const { email, username, gender, phone } = req.body;

    if (!email || !username || !gender || !phone) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    try {
        const result = await db.query(
            "INSERT INTO users (email, username, gender, phone) VALUES ($1, $2, $3, $4) RETURNING id",
            [email, username, gender, phone]
        );
        res.status(200).json({ message: "User registered successfully!", userId: result.rows[0].id });
    } catch (err) {
        console.error("❌ PostgreSQL Error:", err);
        res.status(500).json({ error: "Database error", details: err.message });
    }
});

// ✅ API to Get User Data
app.get("/user/:id", async (req, res) => {
    const userId = parseInt(req.params.id, 10); // Convert id to integer

    if (isNaN(userId)) {
        return res.status(400).json({ error: "Invalid user ID" });
    }

    try {
        const result = await db.query("SELECT * FROM users WHERE id = $1", [userId]);

        if (result.rows.length === 0) {
            return res.json({
                username: "Guest",
                gender: "N/A",
                phone: "N/A",
                profile_picture: "/uploads/default_profile.png"
            });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error("❌ PostgreSQL Error:", err);
        res.status(500).json({ error: "Database error", details: err.message });
    }
});

// ✅ API to Upload user profile picture
app.post("/uploadProfilePic/:id", upload.single("profilePic"), async (req, res) => {
    const userId = req.params.id;
    if (!req.file) {
        return res.status(400).json({ error: "No file uploaded" });
    }

    const imageUrl = `/uploads/${req.file.filename}`;

    try {
        await db.query("UPDATE users SET profile_picture = $1 WHERE id = $2", [imageUrl, userId]);
        res.json({ message: "Profile picture updated!", profile_picture: imageUrl });
    } catch (err) {
        console.error("❌ PostgreSQL Error:", err);
        res.status(500).json({ error: "Database error", details: err.message });
    }
});

// ✅ Start the Server
app.listen(PORT, () => {
    console.log(`🚀 Server running on http://localhost:${PORT}`);
});
