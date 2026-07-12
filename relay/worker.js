/**
 * FormCheck notification relay — Cloudflare Worker.
 *
 * Apple App Store Server Notifications (V2) → Discord / Telegram pings.
 * Real-time "someone started a trial / paid / cancelled" messages with zero
 * SDK inside the app, so the app's "Data Not Collected" privacy label holds.
 *
 * Security model: the URL contains a secret path segment and the relay only
 * SENDS pings — it grants nothing. Apple's JWS payload is decoded but not
 * cryptographically chain-verified; if the URL ever leaks, rotate
 * RELAY_SECRET and update the URL in App Store Connect.
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Manual wiring check: open /test/<secret> in a browser.
    if (request.method === "GET" && url.pathname === `/test/${env.RELAY_SECRET}`) {
      await notify(env, "🔔 FormCheck relay is wired up and can reach you.");
      return new Response("test sent");
    }

    if (request.method !== "POST" || url.pathname !== `/apple/${env.RELAY_SECRET}`) {
      return new Response("not found", { status: 404 });
    }

    let message;
    try {
      const body = await request.json();
      const payload = decodeJWS(body.signedPayload);

      // Ignore anything that isn't our app (shared Apple endpoint hygiene).
      const bundleId = payload?.data?.bundleId;
      if (bundleId && bundleId !== "com.formcheck.app") {
        return new Response("ignored");
      }

      message = formatEvent(payload);
    } catch (err) {
      // Always 2xx-range for Apple retries we can't use; 400 makes Apple retry,
      // which is what we want for transient parse issues.
      return new Response("bad payload", { status: 400 });
    }

    if (message) {
      await notify(env, message);
    }
    return new Response("ok");
  },
};

// --- Apple payload handling -------------------------------------------------

function decodeJWS(jws) {
  const parts = String(jws).split(".");
  if (parts.length !== 3) throw new Error("not a JWS");
  return JSON.parse(b64urlDecodeUTF8(parts[1]));
}

function b64urlDecodeUTF8(segment) {
  let s = segment.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const binary = atob(s);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new TextDecoder("utf-8").decode(bytes);
}

function formatEvent(payload) {
  const type = payload.notificationType;
  const subtype = payload.subtype;
  const data = payload.data || {};

  const tx = safeDecode(data.signedTransactionInfo);
  const product = tx.productId || "unknown product";
  // price is in milliunits of the currency (e.g. 6990 = 6.99).
  const price =
    tx.price != null && tx.currency
      ? ` — ${(tx.price / 1000).toFixed(2)} ${tx.currency}`
      : "";
  const tag = data.environment === "Sandbox" ? "  [SANDBOX]" : "";

  switch (type) {
    case "SUBSCRIBED":
      if (subtype === "INITIAL_BUY") {
        // offerType 1 = introductory offer (our 3-day free trial).
        return tx.offerType === 1
          ? `🎁 Free trial started: ${product}${tag}`
          : `🎉 New subscriber: ${product}${price}${tag}`;
      }
      return `🔄 Resubscribed: ${product}${price}${tag}`;

    case "DID_RENEW":
      // The first DID_RENEW after a trial is the trial converting to paid.
      return `💰 Renewal: ${product}${price}${tag}`;

    case "DID_CHANGE_RENEWAL_STATUS":
      return subtype === "AUTO_RENEW_DISABLED"
        ? `⚠️ Auto-renew turned OFF (may churn): ${product}${tag}`
        : `✅ Auto-renew back ON: ${product}${tag}`;

    case "DID_FAIL_TO_RENEW":
      return `💳 Billing issue: ${product}${subtype === "GRACE_PERIOD" ? " (in grace period)" : ""}${tag}`;

    case "EXPIRED":
      return `👋 Subscription expired: ${product}${tag}`;

    case "REFUND":
      return `💸 Refund issued: ${product}${price}${tag}`;

    case "TEST":
      return `🔔 Apple test notification received${tag}`;

    default:
      return `ℹ️ ${type}${subtype ? "/" + subtype : ""}: ${product}${tag}`;
  }
}

function safeDecode(jws) {
  try {
    return jws ? decodeJWS(jws) : {};
  } catch {
    return {};
  }
}

// --- Delivery ----------------------------------------------------------------

async function notify(env, text) {
  const jobs = [];

  if (env.DISCORD_WEBHOOK_URL) {
    jobs.push(
      fetch(env.DISCORD_WEBHOOK_URL, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ content: text }),
      })
    );
  }

  if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID) {
    jobs.push(
      fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ chat_id: env.TELEGRAM_CHAT_ID, text }),
      })
    );
  }

  await Promise.allSettled(jobs);
}
