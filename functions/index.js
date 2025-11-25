// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const firestore = admin.firestore();

// This function triggers whenever a user's status changes in the Realtime Database
exports.onUserStatusChanged = functions.database
  .ref("/status/{uid}")
  .onWrite(async (change, context) => {
    // Get the data from the event
    const eventStatus = change.after.val();
    const uid = context.params.uid;

    const userDocRef = firestore.collection("users").doc(uid);

    if (!eventStatus) {
      console.log(`User ${uid} has no status, likely deleted.`);
      return null;
    }

    // Prepare the data to be written to Firestore
    const statusData = {
      isOnline: eventStatus.state === "online",
      lastSeen: eventStatus.last_changed, // This is a timestamp from the server
    };

    // Update the user's document in Firestore
    console.log(`Updating Firestore for user ${uid} with status:`, statusData);
    return userDocRef.update(statusData);
  });