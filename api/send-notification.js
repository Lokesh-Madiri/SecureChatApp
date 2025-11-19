const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
// We'll initialize it in the handler to avoid issues with Vercel's serverless environment
let initialized = false;

function initializeFirebase() {
  if (!initialized) {
    try {
      // Get Firebase config from environment variables
      const serviceAccount = {
        type: process.env.FIREBASE_TYPE,
        project_id: process.env.FIREBASE_PROJECT_ID,
        private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
        private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
        client_email: process.env.FIREBASE_CLIENT_EMAIL,
        client_id: process.env.FIREBASE_CLIENT_ID,
        auth_uri: process.env.FIREBASE_AUTH_URI,
        token_uri: process.env.FIREBASE_TOKEN_URI,
        auth_provider_x509_cert_url:
          process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
        client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
      };

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });

      initialized = true;
      console.log("Firebase Admin SDK initialized successfully");
    } catch (error) {
      console.error("Error initializing Firebase Admin SDK:", error);
      throw error;
    }
  }
}

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  // Handle preflight requests
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed. Use POST." });
  }

  try {
    // Initialize Firebase if not already done
    initializeFirebase();

    const { userId, title, body, data } = req.body;

    // Validate input
    if (!userId || !title || !body) {
      return res.status(400).json({
        error: "Missing required fields: userId, title, and body are required",
      });
    }

    // Get user's FCM token from Firestore
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(userId).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      return res.status(400).json({ error: "User does not have an FCM token" });
    }

    // Send FCM notification
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
    };

    const response = await admin.messaging().send(message);
    console.log("Notification sent successfully:", response);

    res.status(200).json({
      success: true,
      message: "Notification sent successfully",
      response: response,
    });
  } catch (error) {
    console.error("Error sending notification:", error);

    // Handle specific Firebase errors
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      return res.status(400).json({
        error: "Invalid or expired FCM token",
        code: error.code,
      });
    }

    res.status(500).json({
      error: "Failed to send notification",
      message: error.message,
      code: error.code,
    });
  }
}
