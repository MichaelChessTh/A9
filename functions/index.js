/**
 * GoogleChat — Firebase Cloud Functions
 *
 * Two Firestore-triggered functions:
 *   1. onDirectMessage  — fires when a new DM is created in
 *                         chat_rooms/{roomId}/messages/{msgId}
 *   2. onGroupMessage   — fires when a new group message is created in
 *                         group_rooms/{groupId}/messages/{msgId}
 *
 * Each function:
 *   • Reads the recipient's FCM token from Firestore
 *   • Sends a high-priority FCM notification via the Admin SDK
 *   • Works even when the recipient's app is completely closed
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * Requirements: Firebase Blaze (pay-as-you-go) plan for outbound networking.
 */

"use strict";

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const crypto = require("crypto");

initializeApp();

const db = getFirestore();

// ─── AES-128-CBC decryption matching Flutter EncryptionService ───────────────
// Key: 'my32characterslongsecretkeyA9!!!' (32 bytes = AES-256-CBC)
// IV:  'a9_iv_static_16b' (16 bytes)
const ENCRYPT_KEY = Buffer.from("my32characterslongsecretkeyA9!!!", "utf8");
const ENCRYPT_IV = Buffer.from("a9_iv_static_16b", "utf8");

function decryptMessage(text) {
  if (!text || !text.startsWith("enc:")) return text;
  try {
    const base64 = text.slice(4); // remove 'enc:' prefix
    const encrypted = Buffer.from(base64, "base64");
    // Flutter's encrypt package uses AES-CBC (not CTR)
    const decipher = crypto.createDecipheriv("aes-256-cbc", ENCRYPT_KEY, ENCRYPT_IV);
    decipher.setAutoPadding(true);
    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString("utf8");
  } catch (e) {
    console.error("Decrypt error:", e);
    return ""; // Return empty string so notification shows nothing rather than garbled text
  }
}

// ─── Helper: send FCM to a single token ─────────────────────────────────────
async function sendPush({ token, title, body, data = {} }) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v ?? "")])
      ),
      android: {
        priority: "high",
        notification: {
          channelId: "googlechat_messages",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          color: "#0084FF",
          sound: "default",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: "default",
            "content-available": 1,
          },
        },
      },
    });
  } catch (err) {
    console.error("FCM send error:", err);
  }
}

// ─── 1. Direct Message notification ─────────────────────────────────────────
exports.onDirectMessage = onDocumentCreated(
  "chat_rooms/{roomId}/messages/{msgId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const senderId = msg.senderID;
    const roomId = event.params.roomId;

    // The room ID is "<uid1>_<uid2>", alphabetically sorted.
    // Determine the recipient uid.
    const [uid1, uid2] = roomId.split("_");
    const recipientId = uid1 === senderId ? uid2 : uid1;
    if (!recipientId || recipientId === senderId) return;

    // Fetch sender profile for display name
    const [recipientDoc, senderDoc] = await Promise.all([
      db.collection("Users").doc(recipientId).get(),
      db.collection("Users").doc(senderId).get(),
    ]);

    const fcmToken = recipientDoc.data()?.fcmToken;
    if (!fcmToken) return; // recipient has no token (logged out / never set up)

    // Use nickname if recipient has set one for sender, otherwise use sender's username
    const recipientNicknames = recipientDoc.data()?.nicknames || {};
    const senderName =
      recipientNicknames[senderId] ||
      senderDoc.data()?.username ||
      senderDoc.data()?.email ||
      "Someone";

    // Determine notification body
    let body;
    switch (msg.messageType) {
      case "image":
        body = "📷 Image";
        break;
      case "file":
        body = `📎 ${msg.fileName || "File"}`;
        break;
      case "audio":
        body = "🎵 Voice message";
        break;
      default:
        body = decryptMessage(msg.message || "");
    }

    await sendPush({
      token: fcmToken,
      title: senderName,
      body,
      data: {
        type: "dm",
        chatRoomId: roomId,
        senderID: senderId,
        senderEmail: senderDoc.data()?.email || "",
        senderName,
      },
    });
  }
);

// ─── 2. Group Message notification ───────────────────────────────────────────
exports.onGroupMessage = onDocumentCreated(
  "group_rooms/{groupId}/messages/{msgId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const senderId = msg.senderID;
    const groupId = event.params.groupId;

    // Fetch group document to get all member UIDs and the group name
    const groupDoc = await db.collection("group_rooms").doc(groupId).get();
    if (!groupDoc.exists) return;
    const groupData = groupDoc.data();
    const memberUIDs = groupData?.memberUIDs || [];
    const groupName = groupData?.name || "Group";

    // Fetch sender profile
    const senderDoc = await db.collection("Users").doc(senderId).get();
    const senderName =
      senderDoc.data()?.username || senderDoc.data()?.email || "Someone";

    // Determine body
    let body;
    switch (msg.messageType) {
      case "image":
        body = `${senderName}: 📷 Image`;
        break;
      case "file":
        body = `${senderName}: 📎 ${msg.fileName || "File"}`;
        break;
      case "audio":
        body = `${senderName}: 🎵 Voice message`;
        break;
      default:
        body = `${senderName}: ${decryptMessage(msg.message || "")}`;
    }

    // Send to every member except the sender
    const recipients = memberUIDs.filter((uid) => uid !== senderId);
    if (recipients.length === 0) return;

    // Batch-fetch recipient docs
    const userDocs = await Promise.all(
      recipients.map((uid) => db.collection("Users").doc(uid).get())
    );

    const sends = userDocs
      .filter((doc) => doc.data()?.fcmToken)
      .map((doc) => {
        // Use per-recipient nickname for the sender if set
        const recipientNicknames = doc.data()?.nicknames || {};
        const displaySenderName =
          recipientNicknames[senderId] || senderName;
        const bodyWithNickname =
          body.replace(new RegExp(`^${senderName}: `), `${displaySenderName}: `);
        return sendPush({
          token: doc.data().fcmToken,
          title: groupName,
          body: bodyWithNickname,
          data: {
            type: "group",
            groupId,
            senderID: senderId,
            senderName: displaySenderName,
            groupName,
          },
        });
      });

    await Promise.all(sends);
  }
);
