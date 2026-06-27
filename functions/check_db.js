const admin = require("firebase-admin");

// Initialize Admin SDK with default credentials
admin.initializeApp({
  projectId: "propflow-aeem-26"
});

const db = admin.firestore();

async function run() {
  console.log("Fetching users from Firestore...");
  const snapshot = await db.collection("users").get();
  if (snapshot.empty) {
    console.log("No users found.");
    return;
  }

  snapshot.forEach(doc => {
    console.log(`User ID: ${doc.id}`);
    console.log(JSON.stringify(doc.data(), null, 2));
    console.log("-----------------------------------");
  });
}

run().catch(console.error);
