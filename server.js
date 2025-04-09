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
// ✅ Register user (returns simple_id)
app.post("/register", async (req, res) => {
  const { firebaseUid, email } = req.body;

  try {
    // Check if user exists (by Firebase UID or email)
    const existingUser = await pool.query(
      "SELECT simple_id FROM users WHERE id = $1 OR email = $2",
      [firebaseUid, email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ 
        error: "User already exists",
        simple_id: existingUser.rows[0].simple_id 
      });
    }

    // Insert new user
    const result = await pool.query(
      `INSERT INTO users (id, simple_id, email)
       VALUES ($1, 'user_' || LPAD(NEXTVAL('user_id_seq')::TEXT, 3, '0'), $2)
       RETURNING simple_id`,
      [firebaseUid, email]
    );

    res.status(201).json({ 
      message: "User registered successfully",
      simple_id: result.rows[0].simple_id 
    });
  } catch (error) {
    console.error("❌ PostgreSQL Error:", error);
    res.status(500).json({ error: "Database error" });
  }
});

// ✅ Get User by simple_id
app.get("/users/:simple_id", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        simple_id,
        email,
        username,
        profile_picture
       FROM users 
       WHERE simple_id = $1`,
      [req.params.simple_id]
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

// ✅ Upload Profile Picture (using simple_id)
app.post("/uploadProfilePic/:simple_id", upload.single("profilePic"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }

  const imageUrl = `/uploads/${req.file.filename}`;

  try {
    await pool.query(
      "UPDATE users SET profile_picture = $1 WHERE simple_id = $2", 
      [imageUrl, req.params.simple_id]
    );
    res.json({ 
      message: "Profile picture updated!",
      profile_picture: imageUrl 
    });
  } catch (err) {
    console.error("❌ PostgreSQL Error:", err);
    res.status(500).json({ error: "Database error" });
  }
});

// 2️⃣ ================== SAVED PLACES ==================
// Now using simple_id consistently
app.post("/api/save-place", async (req, res) => {
  const { simple_id, place_id, name, type, price_per_night } = req.body;
  
  try {
    const result = await pool.query(
      `INSERT INTO saved_places (user_simple_id, place_id, name, type, price_per_night) 
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [simple_id, place_id, name, type, price_per_night]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to save place" });
  }
});

// Get saved places by simple_id
app.get("/api/saved-places/:simple_id", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM saved_places WHERE user_simple_id = $1",
      [req.params.simple_id]
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
app.post("/api/bookings", async (req, res) => {
  const { simple_id, plan_id, paypal_transaction_id, amount } = req.body; // Changed to simple_id
  
  try {
    // 1. Verify the simple_id exists
    const userCheck = await pool.query(
      "SELECT id FROM users WHERE simple_id = $1",
      [simple_id]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    // 2. Create booking
    const result = await pool.query(
      `INSERT INTO bookings (
        user_simple_id,  // Changed column name
        plan_id, 
        paypal_transaction_id, 
        amount,
        status
      ) VALUES ($1, $2, $3, $4, 'completed') 
      RETURNING *`,
      [simple_id, plan_id, paypal_transaction_id, amount]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("❌ Booking Error:", err);
    res.status(500).json({ 
      error: "Failed to create booking",
      details: err.message // Added error details for debugging
    });
  }
});

// Get bookings by simple_id
app.get("/api/bookings", async (req, res) => {
  const { simple_id } = req.query; // Changed parameter name
  
  try {
    if (!simple_id) {
      return res.status(400).json({ error: "simple_id parameter is required" });
    }

    const result = await pool.query(
      `SELECT 
        b.id,
        b.paypal_transaction_id,
        p.name AS plan_name, 
        b.amount, 
        b.status, 
        TO_CHAR(b.booked_at, 'YYYY-MM-DD HH24:MI') AS booked_at
       FROM bookings b
       LEFT JOIN plans p ON b.plan_id = p.id
       WHERE b.user_simple_id = $1  // Changed column name
       ORDER BY b.booked_at DESC`,
      [simple_id]
    );

    res.json(result.rows.length > 0 ? result.rows : []); // Always return array
  } catch (err) {
    console.error("❌ Bookings Fetch Error:", err);
    res.status(500).json({ 
      error: "Database error",
      details: err.message 
    });
  }
});

// 6️⃣ ================== PAYPAL ==================
// Fixed PayPal config (use template literals)
paypal.configure({
  mode: "sandbox",
  client_id: process.env.PAYPAL_CLIENT_ID,
  client_secret: process.env.PAYPAL_CLIENT_SECRET
});

// ✅ Create Payment (Uses simple_id)
app.post("/pay", async (req, res) => {
  const { simple_id, amount, plan_name } = req.body;

  try {
    const payment = {
      intent: "sale",
      payer: { payment_method: "paypal" },
      transactions: [{
        amount: { 
          currency: "MYR", 
          total: amount.toFixed(2) 
        },
        description: `Payment for ${plan_name} by ${simple_id}`
      }],
      redirect_urls: {
        return_url: `${process.env.BASE_URL}/payment/success?simple_id=${simple_id}`,
        cancel_url: `${process.env.BASE_URL}/payment/cancel`
      }
    };

    paypal.payment.create(payment, (err, payment) => {
      if (err) {
        console.error("❌ PayPal Error:", err);
        return res.status(500).json({ error: err.message });
      }
      
      // Return approval URL to frontend
      const approvalUrl = payment.links.find(link => link.rel === "approval_url").href;
      res.json({ approval_url: approvalUrl });
    });
  } catch (err) {
    console.error("❌ Payment Error:", err);
    res.status(500).json({ error: "Payment failed" });
  }
});

// ✅ Payment Success (Uses simple_id)
app.get("/payment/success", async (req, res) => {
  const { paymentId, PayerID, simple_id } = req.query;

  try {
    // 1. Verify user exists
    const user = await pool.query(
      "SELECT simple_id FROM users WHERE simple_id = $1",
      [simple_id]
    );

    if (user.rows.length === 0) {
      throw new Error("User not found");
    }

    // 2. Execute PayPal payment
    const payment = await new Promise((resolve, reject) => {
      paypal.payment.execute(paymentId, { payer_id: PayerID }, (err, payment) => {
        if (err) reject(err);
        else resolve(payment);
      });
    });

    // 3. Record transaction (example - adapt to your schema)
    await pool.query(
      `INSERT INTO payments (
        user_simple_id,
        paypal_payment_id,
        amount,
        status
      ) VALUES ($1, $2, $3, 'completed')`,
      [simple_id, paymentId, payment.transactions[0].amount.total]
    );

    // 4. Redirect to frontend (or return JSON)
    res.redirect(`${process.env.FRONTEND_URL}/payment-success`);
  } catch (error) {
    console.error("❌ Payment Execution Error:", error);
    res.redirect(`${process.env.FRONTEND_URL}/payment-failed?error=${encodeURIComponent(error.message)}`);
  }
});

// ✅ Payment Cancel
app.get("/payment/cancel", (req, res) => {
  res.redirect(`${process.env.FRONTEND_URL}/payment-cancelled`);
});

// 7️⃣ ================== SERVER START ==================
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});