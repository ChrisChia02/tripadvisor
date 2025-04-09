const express = require("express");
const { Pool } = require("pg");
require("dotenv").config();
const multer = require("multer");
const path = require("path");
const paypal = require("paypal-rest-sdk");

const app = express();
const PORT = process.env.PORT || 3000;

// ✅ PostgreSQL Connection (same as yours)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || "postgresql://admin:your_password@your_host/trip_advisor_db",
  ssl: { rejectUnauthorized: false }
});

// ✅ Middleware
app.use(express.json());
app.use("/uploads", express.static("uploads"));

// ✅ Multer Setup (same as yours)
const upload = multer({ 
  storage: multer.diskStorage({
    destination: "./uploads/",
    filename: (req, file, cb) => {
      cb(null, "profile_" + Date.now() + path.extname(file.originalname));
    }
  })
});

// 1️⃣ ================== USERS ================== 
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
  try {
    const result = await pool.query(
      `SELECT 
        id AS firebase_uid,
        simple_id AS display_id, 
        email,
        username
       FROM users 
       WHERE id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
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

// 2️⃣ ================== SAVED PLACES ==================
// Save a place
app.post("/api/save-place", async (req, res) => {
  const { user_id, place_id, name, type, price_per_night } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO saved_places (user_id, place_id, name, type, price_per_night) 
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [user_id, place_id, name, type, price_per_night]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to save place" });
  }
});

// Get user's saved places
app.get("/api/saved-places/:user_id", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM saved_places WHERE user_id = $1",
      [req.params.user_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// 3️⃣ ================== TRIPS ==================
// Create a trip
app.post("/api/trips", async (req, res) => {
  const { user_id, title, start_date, end_date } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO trips (user_id, title, start_date, end_date) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [user_id, title, start_date, end_date]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create trip" });
  }
});

// 4️⃣ ================== PLANS ==================
// Generate a plan (AI or manual)
app.post("/api/plans", async (req, res) => {
  const { trip_id, name, total_price } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO plans (trip_id, name, total_price) 
       VALUES ($1, $2, $3) RETURNING *`,
      [trip_id, name, total_price]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create plan" });
  }
});

// 5️⃣ ================== BOOKINGS ==================
// Create booking after PayPal success
app.post("/api/bookings", async (req, res) => {
  const { user_id, plan_id, paypal_transaction_id, amount } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO bookings (user_id, plan_id, paypal_transaction_id, amount) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [user_id, plan_id, paypal_transaction_id, amount]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create booking" });
  }
});

app.get("/api/bookings", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        b.id, 
        p.name AS plan_name, 
        b.amount, 
        b.status, 
        b.booked_at
       FROM bookings b
       LEFT JOIN plans p ON b.plan_id = p.id
       WHERE b.user_id = $1`,
      [req.query.user_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// 6️⃣ ================== PAYPAL ==================
// Fixed PayPal config (use template literals)
paypal.configure({
  mode: "sandbox",
  client_id: process.env.PAYPAL_CLIENT_ID,
  client_secret: process.env.PAYPAL_CLIENT_SECRET
});

// Create payment (updated to use dynamic amount)
app.post("/pay", async (req, res) => {
  const { amount, user_id } = req.body;
  
  // 1. Verify user exists
  const user = await pool.query("SELECT simple_id FROM users WHERE id = $1", [user_id]);
  if (!user.rows.length) return res.status(404).send("User not found");

  // 2. Create PayPal payment
  const payment = {
    intent: "sale",
    payer: { payment_method: "paypal" },
    transactions: [{
      amount: { currency: "MYR", total: amount.toFixed(2) },
      description: `User ${user.rows[0].simple_id} payment`
    }],
    redirect_urls: {
      return_url: "https://tripadvisor-hgg4.onrender.com/success",
      cancel_url: "https://tripadvisor-hgg4.onrender.com/cancel"
    }
  };

  // 3. Execute
  paypal.payment.create(payment, (err, payment) => {
    if (err) return res.status(500).send(err);
    const approvalUrl = payment.links.find(link => link.rel === "approval_url").href;
    res.json({ approval_url: approvalUrl });
  });
});

app.get("/success", async (req, res) => {
  const { paymentId, PayerID } = req.query;
  const userId = "user_001"; // Replace with actual user ID (from session/JWT)

  try {
    // 1. Check if user exists
    const userCheck = await pool.query(
      "SELECT id FROM users WHERE id = $1", 
      [userId]
    );

    if (userCheck.rows.length === 0) {
      throw new Error(`User ${userId} not found`);
    }

    // 2. Proceed with PayPal execution and booking insertion
    const payment = await new Promise((resolve, reject) => {
      paypal.payment.execute(paymentId, { payer_id: PayerID }, (err, payment) => {
        if (err) reject(err);
        else resolve(payment);
      });
    });

    // 3. Insert booking
    await pool.query(
      `INSERT INTO bookings (user_id, plan_id, paypal_transaction_id, amount)
       VALUES ($1, $2, $3, $4)`,
      [userId, "plan_123", paymentId, 99.00] // Replace with dynamic values
    );

    res.redirect("yourapp://payment-success");
  } catch (error) {
    console.error("Error:", error);
    res.status(400).json({ error: error.message });
  }
});

// ✅ Payment Cancel Endpoint
app.get("/cancel", (req, res) => {
    res.json({ message: "Payment cancelled" });
});

// 7️⃣ ================== SERVER START ==================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});