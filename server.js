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
    mode: "sandbox", // "sandbox" or "live"
    client_id: process.env.PAYPAL_CLIENT_ID || "Afdl9APk-_BzjeuuqnpRChOE1oOs06piZVeMtk_ZpVOc8vc8mbgQbIo65_odiCiD75EHXoxXNZXwo65A",
    client_secret: process.env.PAYPAL_CLIENT_SECRET || "ENGYjrtpbKfP9U0a3QVrtKjKP8NWSn06rz5mkyeAPlWSkDJNsK7uK2e4NoIHUeD4gPmM2drc8itH9Itm"
});

// ✅ Route to Create Payment
app.post("/pay", (req, res) => {
    const { amount } = req.body; // Amount from request

    const paymentJson = {
        intent: "sale",
        payer: {
            payment_method: "paypal"
        },
        redirect_urls: {
            return_url: "http://${process.env.BASE_URL}/success",
            cancel_url: "http://${process.env.BASE_URL}/cancel"
        },
        transactions: [{
            amount: {
                currency: "USD",
                total: 40.00
            },
            description: "Trip Advisor Booking"
        }]
    };

    paypal.payment.create(paymentJson, (error, payment) => {
        if (error) {
            console.error(error);
            res.status(500).json({ error: "Payment failed", details: error });
        } else {
            for (let link of payment.links) {
                if (link.rel === "approval_url") {
                    return res.json({ approval_url: link.href });
                }
            }
        }
    });
});

// ✅ Payment Success Endpoint
app.get("/success", (req, res) => {
    const payerId = req.query.PayerID;
    const paymentId = req.query.paymentId;

    const executePaymentJson = {
        payer_id: payerId
    };

    paypal.payment.execute(paymentId, executePaymentJson, (error, payment) => {
        if (error) {
            console.error(error.response);
            return res.status(500).json({ error: "Payment execution failed" });
        } else {
            return res.json({ message: "Payment successful!", payment });
        }
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