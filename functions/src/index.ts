import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { parseWinners } from "./winners";

initializeApp();

const db = getFirestore();
const winnersUrl = "https://prize.ird.gov.np/api/v1/public/winners";
const couponHashPattern = /^[a-f0-9]{64}$/;

export const registerInstallation = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Anonymous authentication is required.");
  const fcmToken = String(request.data?.fcmToken ?? "").trim();
  if (fcmToken.length < 32 || fcmToken.length > 4096) throw new HttpsError("invalid-argument", "Invalid FCM token.");
  await db.collection("installations").doc(request.auth.uid).set({
    fcmToken,
    platform: String(request.data?.platform ?? "mobile").slice(0, 32),
    locale: String(request.data?.locale ?? "ne-NP").slice(0, 16),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { ok: true };
});

export const registerCoupon = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Anonymous authentication is required.");
  const couponHash = String(request.data?.couponHash ?? "").toLowerCase();
  if (!couponHashPattern.test(couponHash)) throw new HttpsError("invalid-argument", "Invalid coupon hash.");
  const installation = await db.collection("installations").doc(request.auth.uid).get();
  if (!installation.exists) throw new HttpsError("failed-precondition", "Register this installation first.");
  await db.collection("couponSubscriptions").doc(couponHash).collection("devices").doc(request.auth.uid).set({
    uid: request.auth.uid,
    drawPeriod: String(request.data?.drawPeriod ?? "").slice(0, 10),
    createdAt: FieldValue.serverTimestamp(),
    notifiedAt: null,
  }, { merge: true });
  return { ok: true };
});

export const checkIrdWinners = onSchedule({ schedule: "every 30 minutes", timeZone: "Asia/Kathmandu", retryCount: 2 }, async () => {
  const limit = 6;
  const all = [];
  for (let offset = 0; offset < 600; offset += limit) {
    const response = await fetch(`${winnersUrl}?limit=${limit}&offset=${offset}`, {
      headers: { accept: "application/json", "user-agent": "KarUpaharWinnerChecker/1.0" },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`IRD winners request failed with ${response.status}`);
    const page = parseWinners(await response.json());
    all.push(...page);
    if (page.length < limit) break;
  }

  for (const winner of all) {
    const winnerRef = db.collection("processedWinners").doc(winner.sourceId.replaceAll("/", "_"));
    if ((await winnerRef.get()).exists) continue;
    const devices = await db.collection("couponSubscriptions").doc(winner.couponHash).collection("devices").get();
    let notifications = 0;
    for (const device of devices.docs) {
      if (device.data().notifiedAt) continue;
      const installation = await db.collection("installations").doc(device.id).get();
      const token = installation.data()?.fcmToken as string | undefined;
      if (!token) continue;
      try {
        await getMessaging().send({
          token,
          notification: {
            title: "Winning tax lottery coupon",
            body: `${winner.coupon}${winner.prizeAmount ? ` won NPR ${winner.prizeAmount}` : " is on the IRD winners list"}`,
          },
          data: {
            type: "winner",
            coupon: winner.coupon,
            couponHash: winner.couponHash,
            category: winner.category,
            prizeAmount: winner.prizeAmount,
            drawDate: winner.drawDate,
          },
          android: { priority: "high", notification: { channelId: "winner_alerts" } },
          apns: { payload: { aps: { sound: "default" } } },
        });
        await device.ref.update({ notifiedAt: FieldValue.serverTimestamp() });
        notifications++;
      } catch (error) {
        logger.error("FCM winner notification failed", { uid: device.id, code: (error as { code?: string }).code });
      }
    }
    await winnerRef.set({ ...winner, coupon: winner.coupon, processedAt: FieldValue.serverTimestamp(), notifications });
  }
  logger.info("IRD winner check complete", { winners: all.length });
});

export const getWinners = onCall({ enforceAppCheck: true }, async () => {
  const snapshot = await db.collection("processedWinners").orderBy("processedAt", "desc").limit(30).get();
  return { winners: snapshot.docs.map((doc) => {
    const data = doc.data();
    return { coupon: data.coupon, category: data.category, prizeAmount: data.prizeAmount, drawDate: data.drawDate };
  }) };
});
