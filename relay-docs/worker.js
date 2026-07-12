const DOCS = {"privacy": "# FormCheck Privacy Policy\n\n**Last updated: July 12, 2026**\n\nFormCheck is built so that your data never leaves your device. This policy is short because there is very little to disclose.\n\n## What we collect\n\n**One anonymous install signal \u2014 and nothing else.** The first time the app is opened, it sends a single message that says, in effect, \"someone installed the app.\" It contains no identifiers, no device information, no location, and nothing about you or your workouts \u2014 we can count installs, and that is all. It is sent once per install and is not linked to you in any way.\n\nBeyond that: FormCheck has no accounts, no analytics SDKs, and no advertising or tracking of any kind. We do not collect, store, sell, or share any personal data. Your workouts, your video, and your history never leave your phone (see below).\n\n## Camera and video\n\nFormCheck uses your camera to analyze your lifting form. All video processing (pose detection, rep counting, form scoring) happens **entirely on your device** using Apple's on-device frameworks. Video frames are never uploaded anywhere.\n\nSet recordings are stored temporarily on your device so you can export replay clips, and are automatically deleted by iOS. Replay clips you export are saved or shared only where you choose to send them.\n\n## Workout history\n\nYour set history (dates, exercises, scores) is stored locally on your device in the app's private storage. It never leaves your phone. Deleting the app deletes it.\n\n## Purchases\n\nSubscriptions are processed by Apple through the App Store. We never see your payment details. Purchase receipts are validated on-device by Apple's StoreKit framework.\n\n## Subscription events\n\nWhen you subscribe, Apple notifies us of subscription lifecycle events (for example, \"a trial started\" or \"a subscription renewed\") through Apple's own App Store Server Notifications. These come from Apple's servers, not from your device, and identify the transaction \u2014 not you.\n\n## Tracking\n\nFormCheck does not track you, does not use advertising identifiers, and contains no advertising.\n\n## Children\n\nFormCheck does not knowingly collect personal data from anyone, including children.\n\n## Changes\n\nIf this policy ever changes, the update will appear on this page with a new date.\n\n## Contact\n\nQuestions: email afia.med.aymen@gmail.com\n", "terms": "# FormCheck Terms of Use\n\n**Last updated: July 12, 2026**\n\nBy using FormCheck you agree to these terms. FormCheck is licensed to you under [Apple's Standard End User License Agreement](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), supplemented by the terms below. Where they differ, these supplemental terms apply.\n\n## 1. Not medical or professional advice\n\nFormCheck provides **automated, informational feedback about exercise form**. It is not medical advice, physical-therapy advice, or professional coaching, and it is not a substitute for any of those. Its analysis is an estimate produced by on-device computer vision and can be wrong.\n\nConsult a qualified professional before starting or changing an exercise program, especially if you have any injury or medical condition.\n\n## 2. Assumption of risk\n\nWeightlifting carries inherent risk of injury. **You lift at your own risk.** You are solely responsible for choosing appropriate weights, using safety equipment (racks, spotters, collars), and stopping if something hurts. Do not rely on FormCheck to prevent injury \u2014 no app can do that.\n\nTo the maximum extent permitted by law, FormCheck and its developer are not liable for any injury, loss, or damage arising from your use of the app or reliance on its feedback.\n\n## 3. Subscriptions\n\nFormCheck Pro is an auto-renewable subscription purchased through Apple:\n\n- **Weekly** ($6.99/week, after a 3-day free trial) or **Yearly** ($39.99/year).\n- Payment is charged to your Apple Account at purchase confirmation (or after the free trial, if not cancelled at least 24 hours before it ends).\n- Subscriptions **renew automatically** unless auto-renew is turned off at least 24 hours before the end of the current period.\n- Manage or cancel anytime in your device Settings \u2192 Apple Account \u2192 Subscriptions. Deleting the app does not cancel a subscription.\n- Prices may vary by region and may change; you'll be notified as required before any change affects you.\n\n## 4. Acceptable use\n\nDon't use FormCheck to record people without their consent, and comply with your gym's filming rules. You are responsible for any content you export and share.\n\n## 5. Privacy\n\nFormCheck collects no personal data \u2014 only an anonymous install count. See the [Privacy Policy](https://formcheck.aymenafia.workers.dev/privacy).\n\n## 6. Changes\n\nWe may update these terms; changes appear on this page with a new date. Continued use after a change means you accept it.\n\n## 7. Contact\n\nQuestions: email afia.med.aymen@gmail.com\n", "support": "# FormCheck Support\n\n## Quick fixes\n\n**\"Step into the frame\" won't go away / placement guide never passes**\nProp the phone at knee height (chest height for bench), make sure your *whole* body is in frame \u2014 head to feet \u2014 and stand about 2.5 m (8 ft) away. Good, even lighting helps a lot; strong backlight (a window behind you) confuses tracking.\n\n**Reps aren't being counted**\nStand still for a second after the guide passes \u2014 the app calibrates your standing height before it can count. If someone walks between you and the phone, tracking re-locks onto you within a moment.\n\n**The skeleton is jittery or misaligned**\nUsually lighting or distance. Move away from mirrors (they can duplicate you), avoid very baggy clothing if possible, and re-check the placement guide's distance hint.\n\n**Depth / form calls seem wrong**\nThe side view judges depth; the front view judges knee tracking. Make sure you picked the view that matches where the phone is. Camera height matters: knee height, not on the floor and not on a tall shelf.\n\n**Restore my subscription on a new phone**\nPaywall \u2192 \"Restore Purchases\" (make sure you're signed into the same Apple Account).\n\n**Cancel my subscription**\niPhone Settings \u2192 your name \u2192 Subscriptions \u2192 FormCheck. Deleting the app does **not** cancel a subscription.\n\n**Refunds**\nPurchases are handled by Apple. Request a refund at https://reportaproblem.apple.com\n\n**Where is my data?**\nOn your phone, and nowhere else. FormCheck has no servers and collects only an anonymous install count \u2014 see the [Privacy Policy](https://formcheck.aymenafia.workers.dev/privacy).\n\n## Still stuck?\n\n- **Email support:** afia.med.aymen@gmail.com\n\nPlease include your iPhone model, iOS version, and which exercise/camera view you were using \u2014 it makes fixes much faster.\n"};

const TITLES = { privacy: "Privacy Policy", terms: "Terms of Use", support: "Support" };

function esc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}

// Minimal, safe Markdown -> HTML: headings, bold, links, lists, hr, paragraphs.
function mdToHtml(md){
  const lines = md.split("\n");
  let html = "", inList = false;
  const inline = t => esc(t)
    .replace(/\*\*([^*]+)\*\*/g,"<strong>$1</strong>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g,'<a href="$2">$1</a>');
  for (let raw of lines){
    const line = raw.replace(/\s+$/,"");
    if(/^---+$/.test(line)){ if(inList){html+="</ul>";inList=false;} html+="<hr>"; continue; }
    let m;
    if((m=line.match(/^(#{1,6})\s+(.*)/))){ if(inList){html+="</ul>";inList=false;} const n=m[1].length; html+=`<h${n}>${inline(m[2])}</h${n}>`; continue; }
    if((m=line.match(/^[-*]\s+(.*)/))){ if(!inList){html+="<ul>";inList=true;} html+=`<li>${inline(m[1])}</li>`; continue; }
    if(line.trim()===""){ if(inList){html+="</ul>";inList=false;} continue; }
    if(inList){html+="</ul>";inList=false;}
    html+=`<p>${inline(line)}</p>`;
  }
  if(inList) html+="</ul>";
  return html;
}

function page(slug){
  const body = mdToHtml(DOCS[slug]);
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>FormCheck — ${TITLES[slug]}</title>
<style>
:root{color-scheme:dark}
body{margin:0;background:#0d0f12;color:#e8e8e8;font:16px/1.6 -apple-system,system-ui,sans-serif}
.wrap{max-width:720px;margin:0 auto;padding:48px 24px 96px}
h1{font-size:30px;font-weight:800;color:#fff;margin:.2em 0 .6em}
h2{font-size:20px;font-weight:700;color:#fff;margin:1.8em 0 .4em}
a{color:#2ed573}
hr{border:none;border-top:1px solid #262a30;margin:2em 0}
ul{padding-left:1.2em}
li{margin:.3em 0}
.nav{margin-bottom:32px;font-size:14px}
.nav a{margin-right:18px;text-decoration:none}
.brand{font-weight:800;color:#2ed573}
</style></head><body><div class="wrap">
<div class="nav"><span class="brand">FormCheck</span> &nbsp; <a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="/support">Support</a></div>
${body}
</div></body></html>`;
}

export default {
  async fetch(request){
    const url = new URL(request.url);
    const slug = url.pathname.replace(/^\//,"").replace(/\/$/,"").toLowerCase() || "privacy";
    if(DOCS[slug]) return new Response(page(slug), {headers:{"content-type":"text/html;charset=utf-8"}});
    return new Response("Not found", {status:404});
  }
};
