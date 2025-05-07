const express = require("express");
const router = express.Router();
const { Pool } = require("pg");
require("dotenv").config();
const multer = require("multer");
const path = require("path");
const paypal = require("paypal-rest-sdk");

const app = express();
const PORT = process.env.PORT || 3000;

const axios = require('axios');

async function sendWhatsAppMessage(date) {
  const payload = {
    messaging_product: "whatsapp",
    to: "60163277918",
    type: "template",
    template: {
      name: "tripadvisor", // Ensure this matches your template name
      language: { code: "en_US" },
      components: [
        {
          type: "body",
          parameters: [
            {
              type: "text",
              text: date // Ensure the value passed here matches the expected parameter in your template
            }
          ]
        }
      ]
    }
  };

  const headers = {
    Authorization: `Bearer EAAHtOSTuia8BO9ok7y1ZCBjZAOblLhKvkklg1qofZCGSmphG1AsU5U53ws1TQ2VLzzKavZB54SL58ZCZBalICZA6DlulYanhdrMZCG6gikB0yZCeIm5q0yQd2niLufzmoAn7M9f9T3pHAKwqZAWCJ7LyhUZBDndiuuxZBuonHydBLfjDTZCVGHO6sAAaew2AZAJApUlXGyZBiRlIuaROQwPFTge9HVwZBGRq5bjTgeD4e5EhueZCJcXMZD`,
    'Content-Type': 'application/json',
  };

  try {
    const url = 'https://graph.facebook.com/v22.0/576026228934824/messages';
    const response = await axios.post(url, payload, { headers });
    console.log("✅ WhatsApp API success:", response.data);
  } catch (error) {
    console.error("❌ WhatsApp API error:", error.response?.data || error.message);
  }
}

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
  console.log("📦 Full request body:", JSON.stringify(req.body, null, 2));
  
  const { firebaseUserId, email, username, gender, phone } = req.body;

  // Validation
  if (!firebaseUserId?.trim()) {
    console.error("❌ Missing firebaseUserId");
    return res.status(400).json({ error: "Firebase UID required" });
  }

  try {
    // Test database connection first
    await pool.query("SELECT 1");
    console.log("✔️ Database connection OK");

    const existingUser = await pool.query(
      "SELECT id FROM users WHERE id = $1", 
      [firebaseUserId]
    );

    if (existingUser.rows.length > 0) {
      console.warn("⚠️ Conflict - User exists:", existingUser.rows[0]);
      return res.status(409).json({ error: "User already registered" });
    }

    console.log("ℹ️ Attempting insert with:", {
      id: firebaseUserId,
      email,
      username,
      gender,
      phone
    });

    const result = await pool.query(
      `INSERT INTO users 
       (id, email, username, gender, phone) 
       VALUES ($1, $2, $3, $4, $5) 
       RETURNING id, email`,
      [firebaseUserId, email, username, gender, phone]
    );

    console.log("✅ Insert result:", result.rows[0]);
    return res.status(201).json(result.rows[0]);

  } catch (error) {
    console.error("💥 Full error:", {
      message: error.message,
      stack: error.stack,
      code: error.code, // PostgreSQL error code
      detail: error.detail
    });
    return res.status(500).json({ 
      error: "Registration failed",
      details: error.message,
      hint: error.hint || null 
    });
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

// ⿢ ================== PROFILE ==================
app.put('/users/:userId', async (req, res) => {
  const { userId } = req.params;
  const { username, gender, phone, biography } = req.body;

  console.log("Received data:", req.body);  // Log the request body

  try {
    // Update the user profile in the database
    const result = await pool.query(
      `UPDATE users SET username = $1, gender = $2, phone = $3, biography = $4 WHERE id = $5 RETURNING *`,
      [username, gender, phone, biography, userId]
    );

    if (result.rows.length > 0) {
      res.status(200).send({ message: "Profile updated successfully" });
    } else {
      res.status(404).send({ message: "User not found" });
    }
  } catch (error) {
    console.error("Error updating profile:", error);  // Log the error
    res.status(500).send({ message: "Failed to update profile", error: error.message });
  }
});

// ⿢ ================== REVIEW ==================
app.post('/reviews', async (req, res) => {
  const { userId, bookingId, rating, comment } = req.body;

  try {
    // Insert the review into the database
    const result = await pool.query(
      `INSERT INTO reviews (user_id, booking_id, rating, comment)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [userId, bookingId, rating, comment]
    );

    res.status(201).send({ message: 'Review submitted successfully', review: result.rows[0] });
  } catch (error) {
    res.status(500).send({ message: 'Failed to submit review', error: error.message });
  }
});

app.get('/reviews/user/:userId', async (req, res) => {
  const userId = req.params.userId;

  try {
    const result = await pool.query(
      `SELECT reviews.*, bookings.place_name
       FROM reviews
       JOIN bookings ON reviews.booking_id = bookings.id
       WHERE reviews.user_id = $1
       ORDER BY reviews.created_at DESC`,
      [userId]
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Error retrieving user reviews:', error);
    res.status(500).json({ message: 'Failed to retrieve reviews' });
  }
});

// ⿢ ================== SAVED PLACES ==================
// Save a place
app.post('/api/saved_places', async (req, res) => {
  const { userId, placeId, name, type, destination, imageUrl, rating, reviewCount, lat, lng } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO saved_places (user_id, place_id, name, type, destination, image_url, rating, review_count, lat, lng)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (user_id, place_id) DO NOTHING
       RETURNING *`,
      [userId, placeId, name, type, destination, imageUrl, rating, reviewCount, lat, lng]
    );
    if (result.rowCount === 0) {
      return res.status(409).json({ error: 'Place already saved' });
    }
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error saving place:', error);
    res.status(500).json({ error: 'Failed to save place' });
  }
});

//remove a place
app.delete('/api/saved_places/:userId/:placeId', async (req, res) => {
  const { userId, placeId } = req.params;
  try {
    const result = await pool.query(
      'DELETE FROM saved_places WHERE user_id = $1 AND place_id = $2',
      [userId, placeId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Place not found' });
    }
    res.status(204).send();
  } catch (error) {
    console.error('Error removing place:', error);
    res.status(500).json({ error: 'Failed to remove place' });
  }
});

// Get saved places
app.get('/api/saved_places/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await pool.query(
      'SELECT * FROM saved_places WHERE user_id = $1',
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching saved places:', error);
    res.status(500).json({ error: 'Failed to fetch saved places' });
  }
});

// Check if place is saved
app.get('/api/saved_places/:userId/:placeId', async (req, res) => {
  const { userId, placeId } = req.params;
  try {
    const result = await pool.query(
      'SELECT EXISTS (SELECT 1 FROM saved_places WHERE user_id = $1 AND place_id = $2) AS is_saved',
      [userId, placeId]
    );
    res.json({ isSaved: result.rows[0].is_saved });
  } catch (error) {
    console.error('Error checking saved place:', error);
    res.status(500).json({ error: 'Failed to check saved place' });
  }
});

// ⿣ ================== TRIPS ==================
app.post('/api/trips', async (req, res) => {
  const { userId, name, itinerary, pictureType } = req.body;
  try {
    // Ensure itinerary is an array
    const validatedItinerary = Array.isArray(itinerary)
      ? itinerary
      : itinerary && itinerary.items
        ? itinerary.items
        : [];

    const result = await pool.query(
      `INSERT INTO trips (user_id, name, itinerary, picture_type, created_at)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
       RETURNING *`,
      [userId, name, validatedItinerary, pictureType]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error saving trip:', error);
    res.status(500).json({ error: 'Failed to save trip' });
  }
});

// Get user trips
app.get('/api/trips/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await pool.query(
      'SELECT * FROM trips WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching trips:', error);
    res.status(500).json({ error: 'Failed to fetch trips' });
  }
});

// Update a trip
app.put('/api/trips/:tripId', async (req, res) => {
  const { tripId } = req.params;
  const { name, itinerary, pictureType } = req.body;
  try {
    const result = await pool.query(
      `UPDATE trips
       SET name = $1, itinerary = $2, picture_type = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING *`,
      [name, itinerary, pictureType, tripId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error updating trip:', error);
    res.status(500).json({ error: 'Failed to update trip' });
  }
});

// Delete a trip
app.delete('/api/trips/:tripId', async (req, res) => {
  const { tripId } = req.params;
  try {
    const result = await pool.query(
      'DELETE FROM trips WHERE id = $1',
      [tripId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting trip:', error);
    res.status(500).json({ error: 'Failed to delete trip' });
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
app.get("/api/bookings", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT 
        b.id, 
        b.place_name, 
        b.place_lat,
        b.place_lng,
        b.amount, 
        b.status, 
        b.booked_at
       FROM bookings b
       WHERE b.user_id = $1`,
      [req.query.user_id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.get("/latest-booking/:user_id", async (req, res) => {
  const userId = req.params.user_id;
  try {
    const result = await pool.query(
      `SELECT * FROM bookings WHERE user_id = $1 ORDER BY booked_at DESC LIMIT 1`,
      [userId]
    );
    if (result.rows.length > 0) {
      res.json(result.rows[0]);
    } else {
      res.status(404).json({ message: "No bookings yet" });
    }
  } catch (err) {
    res.status(500).json({ error: "DB error", details: err });
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
      return_url: `http://${req.headers.host}/success`,
      cancel_url: `http://${req.headers.host}/cancel`
    },
    transactions: [{
      amount: {
        currency: "USD",
        total: amount
      },
      description: "Trip Booking",
      custom: JSON.stringify({ 
        user_id: req.body.user_id,
        place_name: req.body.place_name,
        place_lat: req.body.place_lat,
        place_lng: req.body.place_lng,
	booked_at: new Date().toISOString(),
      })
    }]
  };

  paypal.payment.create(paymentJson, (error, payment) => {
    if (error) {
      console.error("PayPal Error:", error.response || error);
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
const booked_at = new Date().toISOString();

  try {
    const payment = await new Promise((resolve, reject) => {
      paypal.payment.execute(paymentId, { payer_id: PayerID }, (err, payment) => {
        err ? reject(err) : resolve(payment);
      });
    });

    // Extract metadata
    const custom = JSON.parse(payment.transactions[0].custom);
    const userId = custom.user_id;

	const {
  	 user_id,
  	 place_name,
  	 place_lat,
  	 place_lng,
	booked_at
	} = custom;

    // ✅ Insert booking (no plan_id)
    const booking = await pool.query(
  `INSERT INTO bookings 
   (user_id, paypal_transaction_id, amount, status, place_name, place_lat, place_lng, booked_at)
   VALUES ($1, $2, $3, 'paid', $4, $5, $6, $7)
   RETURNING *`,
  [
    user_id,
    paymentId,
    payment.transactions[0].amount.total,
    place_name,
    place_lat,
    place_lng,
    booked_at
  ]
);

// Format and send WhatsApp message
const formattedDate = new Date(booked_at).toLocaleDateString('en-US', {
  weekday: 'long', month: 'long', day: 'numeric', year: 'numeric'
});

await sendWhatsAppMessage(formattedDate);

    res.send(`
  <html>
    <head><title>Payment Successful</title></head>
    <body style="font-family: Arial; text-align: center; margin-top: 50px;">
      <h1>🎉 Payment Successful!</h1>
      <p>Thank you for your booking!</p>
      <p>You may close this window and return to the app.</p>
    </body>
  </html>
`);


  } catch (err) {
    console.error("💥 Payment processing failed:", err);
    res.status(500).json({
      error: "Payment processing failed",
      details: err.response?.details || err.message
    });
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