const express = require("express");
const { Pool } = require("pg");
require("dotenv").config();
const multer = require("multer");
const path = require("path");

const app = express();
const PORT = 3000;

// ✅ PostgreSQL Database Connection
const pool = new Pool({
  user: process.env.DB_USER || "tripadmin",
  host: process.env.DB_HOST,
  database: process.env.DB_NAME || "trip_advisor_db",
  password: String(process.env.DB_PASSWORD || "Admin123"),
  port: process.env.DB_PORT || 5432,
  connectionString:
    process.env.DATABASE_URL ||
    "postgresql://admin:cVAvpCgiFmd6jaqCKFbq4K47ScgG6QPX@dpg-cvi6l4popnds73fqnkr0-a.singapore-postgres.render.com/trip_advisor_db",
  ssl: { rejectUnauthorized: false },
});

pool.connect((err, client, release) => {
  if (err) {
    console.error("❌ Database connection failed:", err);
  } else {
    console.log("✅ Connected to PostgreSQL Database");
    release();
  }
});

// ✅ Middleware
app.use(express.json());
app.use("/uploads", express.static("uploads"));

// ✅ Multer Storage Setup
const storage = multer.diskStorage({
  destination: "./uploads/",
  filename: (req, file, cb) => {
    cb(null, "profile_" + Date.now() + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

// ✅ Route to register user in PostgreSQL
app.post("/register", async (req, res) => {
  const { firebaseUserId, email, username, gender, phone } = req.body;

  try {
    // Check if user already exists
    const existingUser = await pool.query(
      "SELECT * FROM users WHERE id = $1",
      [firebaseUserId]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: "User already exists" });
    }

    // Insert user into PostgreSQL
    const result = await pool.query(
      "INSERT INTO users (id, email, username, gender, phone) VALUES ($1, $2, $3, $4, $5) RETURNING *",
      [firebaseUserId, email, username, gender, phone]
    );

    res.status(201).json({ message: "User registered successfully", user: result.rows[0] });
  } catch (error) {
    console.error("❌ PostgreSQL Error:", error);
    res.status(500).json({ error: "Database error" });
  }
});

// ✅ Get User Information by ID
app.get("/users/:id", async (req, res) => {
  const userId = req.params.id; // Keep as string (not `parseInt`)

  try {
    const result = await pool.query("SELECT * FROM users WHERE id = $1", [userId]);

    if (result.rows.length === 0) {
      return res.json({
        username: "Guest",
        gender: "N/A",
        phone: "N/A",
        profile_picture: "/uploads/default_profile.png",
      });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("❌ PostgreSQL Error:", err);
    res.status(500).json({ error: "Database error", details: err.message });
  }
});

// ✅ Upload User Profile Picture
app.post("/uploadProfilePic/:id", upload.single("profilePic"), async (req, res) => {
  const userId = req.params.id;

  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  const imageUrl = `/uploads/${req.file.filename}`;

  try {
    await pool.query("UPDATE users SET profile_picture = $1 WHERE id = $2", [imageUrl, userId]);
    res.json({ message: "Profile picture updated!", profile_picture: imageUrl });
  } catch (err) {
    console.error("❌ PostgreSQL Error:", err);
    res.status(500).json({ error: "Database error", details: err.message });
  }
});

// ✅ Start Server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});