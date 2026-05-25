const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

function trTodayKey() {
  const now = new Date();
  const tr = new Date(now.getTime() + 3 * 60 * 60 * 1000);
  const y = tr.getUTCFullYear();
  const m = String(tr.getUTCMonth() + 1).padStart(2, "0");
  const d = String(tr.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

async function sendToToken({ token, title, body, data = {} }) {
  if (!token) return false;

  const cleanData = {};
  for (const [key, value] of Object.entries(data)) {
    cleanData[key] = value == null ? "" : String(value);
  }

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: cleanData,
      android: {
        priority: "high",
        notification: {
          channelId: "falix_chat",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
    return true;
  } catch (error) {
    logger.error("FCM send error", error);
    return false;
  }
}

async function sendUserPush(uid, title, body, data = {}) {
  if (!uid) return false;
  const snap = await db.collection("users").doc(uid).get();
  const user = snap.data() || {};
  const token = user.fcmToken || user.fcm_token;
  return sendToToken({ token, title, body, data });
}

async function sendExpertPush(uid, title, body, data = {}) {
  if (!uid) return false;
  const snap = await db.collection("experts").doc(uid).get();
  const expert = snap.data() || {};
  const token = expert.fcmToken || expert.fcm_token;
  return sendToToken({ token, title, body, data });
}

// 1) Yeni chat oluşunca seçili uzmana bildirim.
exports.notifyOnNewChat = onDocumentCreated("chats/{chatId}", async (event) => {
  const chatId = event.params.chatId;
  const chat = event.data?.data() || {};

  const expertId = (chat.expertId || "").toString();
  if (!expertId) return;

  const serviceTitle = (chat.serviceTitle || chat.serviceType || "Uzman yorumu").toString();
  const userName = (chat.userName || chat.userEmail || "Yeni danışan").toString();

  await sendExpertPush(
    expertId,
    "Yeni uzman talebi 🔮",
    `${userName}, ${serviceTitle} için seni seçti.`,
    { type: "new_chat", chatId, serviceTitle }
  );
});

// 2) Chat mesaj bildirimi: user -> expert, expert -> user.
exports.notifyOnNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const message = event.data?.data() || {};

    const senderRole = (message.senderRole || "").toString();
    if (senderRole === "system") return;

    const chatSnap = await db.collection("chats").doc(chatId).get();
    if (!chatSnap.exists) return;

    const chat = chatSnap.data() || {};
    const text = (message.text || "").toString();
    const messageType = (message.type || "").toString();
    const serviceTitle = (chat.serviceTitle || chat.serviceType || "Uzman sohbeti").toString();

    if (senderRole === "user") {
      const expertId = (chat.expertId || "").toString();
      const userName = (chat.userName || chat.userEmail || "Danışan").toString();

      await sendExpertPush(
        expertId,
        "Yeni danışan mesajı ✨",
        messageType === "image"
          ? `${userName} bir fotoğraf gönderdi.`
          : `${userName}: ${text.substring(0, 90)}`,
        { type: "chat_message", chatId, messageId, senderRole, serviceTitle }
      );
      return;
    }

    if (senderRole === "expert") {
      const userId = (chat.userId || chat.uid || "").toString();
      const expertName = (chat.expertName || message.senderName || "Uzmanın").toString();

      await sendUserPush(
        userId,
        `${expertName} cevap verdi ✨`,
        messageType === "image" ? "Uzmanın bir fotoğraf gönderdi." : text.substring(0, 90),
        { type: "chat_message", chatId, messageId, senderRole, serviceTitle }
      );
    }
  }
);

// 3) Uzman online olunca son 24 saatte expert hizmeti görüntüleyen kullanıcılara hafif push.
// Not: Bu çalışması için kullanıcı tarafında users/{uid}.interestedInExperts = true gibi alan tutulursa daha iyi hedeflenir.
exports.notifyWhenExpertGoesOnline = onDocumentUpdated("experts/{expertId}", async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};

  if (before.online === true || after.online !== true || after.active === false) return;

  const expertName = (after.name || "Bir uzman").toString();
  const expertId = event.params.expertId;

  const usersSnap = await db
    .collection("users")
    .where("pushEnabled", "!=", false)
    .limit(200)
    .get();

  const sends = [];
  usersSnap.forEach((doc) => {
    const user = doc.data() || {};
    if (!user.fcmToken && !user.fcm_token) return;

    sends.push(sendToToken({
      token: user.fcmToken || user.fcm_token,
      title: `${expertName} şu an online ✨`,
      body: "Canlı uzman yorumu almak için şimdi bağlanabilirsin.",
      data: { type: "expert_online", expertId },
    }));
  });

  await Promise.allSettled(sends);
});

// 4) Günlük enerji push'u. Her gün TR saati 10:00.
exports.dailyEnergyPush = onSchedule(
  {
    schedule: "0 10 * * *",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const today = trTodayKey();

    const messages = [
      "Bugün evrenden sana özel bir mesaj var ✨",
      "Enerjin değişiyor olabilir. Günlük mesajını gör 🔮",
      "Bugünün ruhsal işaretleri seni bekliyor ✨",
      "Kalbinin cevabını bugün Falix’te bulabilirsin 💫",
    ];

    const body = messages[Math.floor(Math.random() * messages.length)];

    const usersSnap = await db
      .collection("users")
      .where("pushEnabled", "!=", false)
      .limit(1000)
      .get();

    const sends = [];
    usersSnap.forEach((doc) => {
      const user = doc.data() || {};
      const token = user.fcmToken || user.fcm_token;
      if (!token) return;
      if (user.lastDailyEnergyPushDate === today) return;

      sends.push(sendToToken({
        token,
        title: "Günlük enerjin hazır ✨",
        body,
        data: { type: "daily_energy", date: today },
      }));

      sends.push(doc.ref.set({
        lastDailyEnergyPushDate: today,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }));
    });

    await Promise.allSettled(sends);
  }
);

// 5) Akıllı push: 2 gün girmeyen kullanıcı. Her gün TR saati 18:30.
exports.inactiveUserSmartPush = onSchedule(
  {
    schedule: "30 18 * * *",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const today = trTodayKey();
    const now = Date.now();
    const twoDaysMs = 2 * 24 * 60 * 60 * 1000;

    const usersSnap = await db
      .collection("users")
      .where("pushEnabled", "!=", false)
      .limit(1000)
      .get();

    const sends = [];
    usersSnap.forEach((doc) => {
      const user = doc.data() || {};
      const token = user.fcmToken || user.fcm_token;
      if (!token) return;
      if (user.lastInactivePushDate === today) return;

      const lastActiveDate = toDate(user.lastActiveAt || user.updatedAt || user.lastSeenAt);
      if (!lastActiveDate) return;
      if (now - lastActiveDate.getTime() < twoDaysMs) return;

      sends.push(sendToToken({
        token,
        title: "Enerjin değişiyor olabilir ✨",
        body: "Günlük mesajını gör ve bugünün işaretlerini kaçırma.",
        data: { type: "inactive_daily_energy" },
      }));

      sends.push(doc.ref.set({
        lastInactivePushDate: today,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }));
    });

    await Promise.allSettled(sends);
  }
);

// 6) Coin indirimi / kampanya push'u. Her cuma TR saati 20:00.
// İstersen bunu sonra kapatmak için app_config/campaigns document ile kontrol edebiliriz.
exports.weeklyCoinOfferPush = onSchedule(
  {
    schedule: "0 20 * * 5",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const today = trTodayKey();

    const configSnap = await db.collection("app_config").doc("campaigns").get();
    const config = configSnap.data() || {};
    if (config.weeklyCoinOfferEnabled === false) return;

    const title = (config.weeklyCoinOfferTitle || "Haftalık enerji fırsatı ✨").toString();
    const body = (config.weeklyCoinOfferBody || "Premium Coin paketlerini kontrol et, uzman yorumunu kaçırma.").toString();

    const usersSnap = await db
      .collection("users")
      .where("pushEnabled", "!=", false)
      .limit(1000)
      .get();

    const sends = [];
    usersSnap.forEach((doc) => {
      const user = doc.data() || {};
      const token = user.fcmToken || user.fcm_token;
      if (!token) return;
      if (user.lastCoinOfferPushDate === today) return;

      sends.push(sendToToken({
        token,
        title,
        body,
        data: { type: "coin_offer" },
      }));

      sends.push(doc.ref.set({
        lastCoinOfferPushDate: today,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }));
    });

    await Promise.allSettled(sends);
  }
);
