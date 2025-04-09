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
app.post("/register", async (req, res) => {
  const { firebaseUserId, email, username, gender, phone } = req.body;

  try {
    // Check if user exists (original code)
    const existingUser = await pool.query(
      "SELECT * FROM users WHERE id = $1", 
      [firebaseUserId]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: "User already exists" });
    }

    // Insert with simple_id (NEW)
    const result = await pool.query(
      `INSERT INTO users (id, email, username, gender, phone, simple_id)
       VALUES ($1, $2, $3, $4, $5, 'user_' || LPAD(NEXTVAL('user_serial')::TEXT, 3, '0'))
       RETURNING *`,
      [firebaseUserId, email, username, gender, phone]
    );

    res.status(201).json({ 
      message: "User registered successfully",
      user: result.rows[0] // Now includes simple_id
    });
  } catch (error) {
    console.error("PostgreSQL Error:", error);
    res.status(500).json({ error: "Database error" });
  }
});

// ✅ Keep your original /users/:id endpoint
app.get("/users/:id", async (req, res) => {
  const userId = req.params.id;
  
  try {
    const result = await pool.query(
      "SELECT * FROM users WHERE id = $1", 
      [userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    
    res.json(result.rows[0]); // Now includes simple_id
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
  try {
    const result = await pool.query(
      `INSERT INTO bookings (user_id, plan_id, paypal_transaction_id, amount) 
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.mappedUserId, req.body.plan_id, req.body.paypal_transaction_id, req.body.amount]
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
    mode: "sandbox", // "sandbox" or "live"
    client_id: process.env.PAYPAL_CLIENT_ID || "Afdl9APk-_BzjeuuqnpRChOE1oOs06piZVeMtk_ZpVOc8vc8mbgQbIo65_odiCiD75EHXoxXNZXwo65A",
    client_secret: process.env.PAYPAL_CLIENT_SECRET || "ENGYjrtpbKfP9U0a3QVrtKjKP8NWSn06rz5mkyeAPlWSkDJNsK7uK2e4NoIHUeD4gPmM2drc8itH9Itm"
});

// ✅ Route to Create Payment
app.post("/pay", (req, res) => {
  const { amount } = req.body;

  const paymentJson = {
    intent: "sale",
    payer: { payment_method: "paypal" },
    redirect_urls: {
      return_url: `http://${req.headers.host}/success?mappedUserId=${req.mappedUserId}`,
      cancel_url: `http://${req.headers.host}/cancel`
    },
    transactions: [{
      amount: {
        currency: "USD",
        total: amount
      },
      description: "Trip Booking",
      custom: req.mappedUserId // Store the mapped ID
    }]
  };

  paypal.payment.create(paymentJson, (error, payment) => {
    if (error) {
      console.error("PayPal Error:", error.response || error); // Log full error
      res.status(500).json({ 
        error: "Payment failed", 
        details: error.response?.details || error.message 
      });
    } else {
      const approvalUrl = payment.links.find(link => link.rel === "approval_url").href;
      res.json({ approval_url: approvalUrl });
    }
  });
});

// ✅ Payment Success Endpoint
app.get("/success", async (req, res) => {
  const { paymentId, PayerID } = req.query;
  
  // 1. Get the original payment to retrieve user_id
  paypal.payment.get(paymentId, (err, payment) => {
    const user_id = payment.transactions[0].custom; // Extract user_id

    // 2. Now insert with the correct user_id
    pool.query(
      `INSERT INTO bookings (user_id, plan_id, paypal_transaction_id, amount)
       VALUES ($1, $2, $3, $4)`,
      [user_id, "plan_123", paymentId, 99.00],
      (err, result) => {
        if (err) console.error("Booking failed:", err);
        else res.redirect("yourapp://success");
      }
    );
  });
});

// ✅ Payment Cancel Endpoint
app.get("/cancel", (req, res) => {
    res.json({ message: "Payment cancelled" });
});

// 7️⃣ ================== SERVER START ==================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});