const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

// Manually parse .env file
const envPath = path.join(__dirname, ".env");
if (fs.existsSync(envPath)) {
  const envConfig = fs.readFileSync(envPath, "utf8");
  for (const line of envConfig.split("\n")) {
    const parts = line.split("=");
    if (parts.length >= 2) {
      const key = parts[0].trim();
      const val = parts.slice(1).join("=").trim().replace(/^['"]|['"]$/g, "");
      process.env[key] = val;
    }
  }
}

const { createWallet } = require("./circle/wallets");

admin.initializeApp({
  projectId: "propflow-aeem-26"
});

const db = admin.firestore();
const userId = "TOqTjI9ZAahbYz5ZgOHOvZHetoB2";

async function run() {
  console.log(`Creating Circle wallet for user ID: ${userId}...`);
  const result = await createWallet(userId);
  console.log("Wallet created successfully:", result);

  // Save to Firestore
  await db.collection("users").doc(userId).update({
    walletId: result.walletId,
    walletAddress: result.walletAddress,
  });
  console.log("Firestore updated successfully!");
}

run().catch(error => {
  if (error.response) {
    console.error("Circle API Error:", error.response.status, JSON.stringify(error.response.data, null, 2));
  } else {
    console.error("Error:", error.message);
  }
});
