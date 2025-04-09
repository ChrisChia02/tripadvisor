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

// 1️⃣ ================== USERS ================== (your existing routes)
app.post("/register", async (req, res) => { /* ... */ });
app.get("/users/:id", async (req, res) => { /* ... */ });
app.post("/uploadProfilePic/:id", upload.single("profilePic"), async (req, res) => { /* ... */ });

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

// 6️⃣ ================== PAYPAL ==================
// Fixed PayPal config (use template literals)
paypal.configure({
  mode: "sandbox",
  client_id: process.env.PAYPAL_CLIENT_ID,
  client_secret: process.env.PAYPAL_CLIENT_SECRET
});

// Create payment (updated to use dynamic amount)
app.post("/api/pay", (req, res) => {
  const { amount } = req.body;
  const paymentJson = {
    intent: "sale",
    payer: { payment_method: "paypal" },
    redirect_urls: {
      return_url: `http://${process.env.BASE_URL}/success`,
      cancel_url: `http://${process.env.BASE_URL}/cancel`
    },
    transactions: [{
      amount: { currency: "USD", total: amount },
      description: "Trip Booking"
    }]
  };

  paypal.payment.create(paymentJson, (error, payment) => {
    if (error) {
      console.error(error);
      res.status(500).json({ error: "Payment failed" });
    } else {
      const approvalUrl = payment.links.find(link => link.rel === "approval_url").href;
      res.json({ approval_url: approvalUrl });
    }
  });
});

// 7️⃣ ================== SERVER START ==================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});