# FormCheck notification relay

Real-time pings when someone starts a trial, pays, cancels, or refunds —
straight from Apple's servers to your Discord/Telegram. **Nothing is added to
the app**: the data flows Apple → this Worker → you, so the app's
"Data Not Collected" privacy label stays true.

```
Apple App Store Server Notifications V2
        │  POST /apple/<secret>
        ▼
Cloudflare Worker (free tier)
        │
        ├─▶ Discord webhook   "🎁 Free trial started: formcheck.weekly"
        └─▶ Telegram bot      "💰 Renewal: formcheck.yearly — 39.99 USD"
```

## Deploy (one time, ~10 minutes)

1. **Install and log in** (free Cloudflare account):
   ```sh
   npm install -g wrangler
   cd relay
   wrangler login
   ```

2. **Set secrets:**
   ```sh
   # the URL password — generate something long:
   openssl rand -hex 24 | wrangler secret put RELAY_SECRET

   # Discord: channel → Settings → Integrations → Webhooks → New Webhook → copy URL
   wrangler secret put DISCORD_WEBHOOK_URL

   # and/or Telegram: create a bot with @BotFather, get your chat id from @userinfobot
   wrangler secret put TELEGRAM_BOT_TOKEN
   wrangler secret put TELEGRAM_CHAT_ID
   ```
   (Configure Discord, Telegram, or both — the relay sends to whatever is set.)

3. **Deploy:**
   ```sh
   wrangler deploy
   ```
   Note the URL it prints, e.g. `https://formcheck-relay.<you>.workers.dev`.

4. **Verify the wiring:** open
   `https://formcheck-relay.<you>.workers.dev/test/<RELAY_SECRET>`
   in a browser — you should get a 🔔 ping within a second.

5. **Tell Apple** (after the app record exists in App Store Connect):
   App Store Connect → Your App → **App Information** → App Store Server
   Notifications → **Version 2** → set both Production and Sandbox URLs to:
   ```
   https://formcheck-relay.<you>.workers.dev/apple/<RELAY_SECRET>
   ```
   Then use ASC's **Request Test Notification** — you should receive
   "🔔 Apple test notification received".

## Optional: install pings (📲)

Apple never emits download events, so "someone installed" can only come from
the app itself — a bare, identifier-free POST on first launch. To enable:

1. Add a second secret (deliberately separate — this URL ships inside the app
   binary and must never be able to forge purchase pings):
   ```sh
   openssl rand -hex 24 | wrangler secret put INSTALL_SECRET
   wrangler deploy
   ```
2. In the app, set `InstallPing.endpoint` (`FormCheck/App/InstallPing.swift`) to
   `https://formcheck-relay.<you>.workers.dev/install/<INSTALL_SECRET>` and rebuild.

TestFlight installs arrive tagged `[TESTFLIGHT]`, debug builds `[DEV]`.

**Privacy trade-off:** the ping carries no identifiers and no device info, but
it is still the app transmitting usage data. With it enabled, answer the App
Privacy questionnaire with **Usage Data → Product Interaction — not linked to
identity, no tracking** instead of "Data Not Collected", and add a line to
PRIVACY.md. Leave `endpoint` nil to skip all of this and keep the perfect label.

## Events you'll see

| Ping | Meaning |
|---|---|
| 🎁 Free trial started | Someone hit the paywall and committed a payment method |
| 🎉 New subscriber | Direct purchase (yearly, or weekly without trial) |
| 💰 Renewal | Renewal charge — the first one after a trial is the trial **converting** |
| ⚠️ Auto-renew turned OFF | Churn warning (they cancelled; active until period ends) |
| 💳 Billing issue | Payment failed (grace period noted) |
| 👋 Subscription expired | Gone |
| 💸 Refund issued | Apple refunded them |

Sandbox events are tagged `[SANDBOX]` so TestFlight noise is obvious.

## Security note

The secret path segment is the authentication — treat the full URL like a
password. The relay decodes Apple's signed payload but doesn't verify the
certificate chain; that's a deliberate trade-off because this relay only
*sends pings* and grants nothing. If the URL leaks, worst case is fake pings:
rotate `RELAY_SECRET` and update the URL in App Store Connect.

## What this doesn't do

Real-time *download* alerts — Apple doesn't emit download events to anyone.
Downloads appear in App Store Connect with ~a day's delay. The pings above
cover the moments that matter financially.
