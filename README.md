# FormCheck

Real-time squat form coaching. 100% on-device (Apple Vision body-pose) — zero API costs, no backend, video never leaves the phone.

## Run it

```sh
brew install xcodegen   # if not installed
cd FormCheck
xcodegen generate
open FormCheck.xcodeproj
```

Select your iPhone as the run destination and hit ⌘R. **The camera doesn't exist in the simulator** — pose detection only works on a real device. You'll need to set your development team in Signing & Capabilities (or `DEVELOPMENT_TEAM` in `project.yml`) the first time.

Usage: prop the phone at knee height, side-on, stand ~2.5 m away, stand still for a second (calibration), then squat.

**Camera choice:** front camera is the default — the screen faces you, so the live skeleton, rep counter, and fault banners are visible mid-set (and a screen recording of a live session is TikTok-ready). Back camera gives the best video quality when someone else films; coaching is voice-only in that setup. Front-camera video is mirrored end-to-end (preview, overlay, recording, replays), selfie-style. Rotation (portrait/landscape) is free while positioning and locks when the set starts.

## Architecture

```
Camera (AVFoundation, portrait-rotated buffers)
  └─> VisionPoseProvider  (VNDetectHumanBodyPoseRequest, on-device)
       └─> PoseSmoother   (One Euro filter per joint)
            ├─> SkeletonOverlayView  (Canvas, aspect-fill mapped over preview)
            └─> RepStateMachine      (hip-height state machine → RepMetrics)
                 └─> FormRuleEngine  (per-exercise geometry heuristics → RepScore)
                      └─> FeedbackManager (voice + haptics)
```

`PoseProvider` is a protocol — swap in MediaPipe BlazePose for the Android port or when you need heel/toe landmarks.

## Where to tune

| What | File | Knobs |
|---|---|---|
| Rep detection sensitivity | `Engine/RepStateMachine.swift` | `descentThreshold`, `lockoutThreshold`, `turnaroundThreshold` |
| Depth judgment | `Engine/RepStateMachine.swift` | tolerance in `RepMetrics.depthAchieved` |
| Fault thresholds & scoring | `Engine/FormRuleEngine.swift` | squat: `leanLimitDegrees`, `valgusRatioLimit`, `lateralShiftLimit`, `minEccentricSeconds` · deadlift: `earlyHipRiseRatioLimit`, `barDriftLimit`, `lockoutLeanLimit` · bench: `benchTouchGapLimit`, `benchMinEccentricSeconds`, `benchLockoutAngleLimit` · score weights |
| Live valgus banner trigger | `Session/SessionViewModel.swift` | ratio `< 0.8` in `updateLiveWarning` |
| Placement guide strictness | `Engine/PlacementChecker.swift` | `spanRange` (distance), `centerBand`, shoulder-ratio bands |
| Skeleton jitter vs lag | `Pose/OneEuroFilter.swift` | `minCutoff` (lower = smoother), `beta` (higher = more responsive) |

Tune by filming yourself and friends — thresholds are starting points, not truth.

## Monetization (v1.1, Nov 2026)

Onboarding (Bones intro → how it works → 4-question quiz → plan) → **soft paywall** (close X / "Not now").
Free users get **one fully scored set per day** (`FreePass` in `Store/TrialReminder.swift`); right after it the paywall
shows their grade (`PaywallContext.afterFreeSet`). Rationale: the v1.0 hard paywall before any camera experience lost
most installs, and the 3-day trial was too short for a gym app (RevenueCat 2026: <4-day trials convert ~25% vs ~42% for longer).

- Subscriptions via **RevenueCat** (project `FormCheck`, entitlement `pro`, offering `default` = `$rc_annual` + `$rc_weekly`).
  `EntitlementStore` also checks StoreKit 2 `currentEntitlements` so pre-RevenueCat subscribers stay unlocked, and runs a one-time `syncPurchases()`.
- `formcheck.yearly` $39.99 with **7-day free trial**; `formcheck.weekly` $6.99, **no trial**.
- Trial reminder: local notification 2 days before the trial ends (`TrialReminder`).
- Mascot art: `art/` (Gemini renders → `tools/cutout.swift` → `tools/trim.swift`), assets `bones-*`.
- Store screenshots: `tools/shots.swift` (Vision pose on Gemini gym photos + app HUD; device frames). Raw sim captures in `AppStore/raw/`.
- Legal pages: `relay-docs/worker.js` → `npx wrangler deploy` from `relay-docs/`.
- Build into `~/Library/Developer/Xcode/DerivedData/FormCheck-cc` — never inside this iCloud-synced Desktop folder.

## Roadmap (from the spec)

1. ~~Replay export~~ ✅ — slow-mo skeleton replays with watermark, per rep, via share sheet.
2. ~~Onboarding quiz + hard paywall~~ ✅ — StoreKit 2, simulator-testable.
3. ~~Front-view mode~~ ✅ — knee valgus (knee/ankle separation ratio) + lateral shift, with a live "knees caving" banner and voice cue mid-rep.
4. ~~Camera placement ghost-guide overlay~~ ✅ — live corrections (distance, centering, orientation), green ghost + auto-dismiss; hip calibration waits for good placement.
5. ~~Deadlift mode~~ ✅ — side view; hips-rising-early (shoulder/hip rise ratio), bar drift (wrist-vs-ankle bar proxy), incomplete lockout.
6. ~~Bench mode~~ ✅ — rep detector tracks wrist (bar) height instead of hips; calibration only samples while elbows are extended (holding lockout). Faults: didn't touch chest, bouncing, soft lockout (elbow angle). Lying-body placement guide.

The MVP spec is fully built. What's left is tuning on real footage — every threshold in the table above is an educated guess until it has survived a real gym.

## Ship checklist

**Done in the repo** (nothing to do):
- ✅ Privacy policy: [PRIVACY.md](PRIVACY.md), linked from the paywall and Settings
- ✅ Privacy manifest (`PrivacyInfo.xcprivacy`): no tracking, no data collection, UserDefaults declared (reason CA92.1)
- ✅ Export compliance: `ITSAppUsesNonExemptEncryption = false` in Info.plist
- ✅ Signing: automatic, team `64BD3MXBAX`; version 1.0.0; app icon; launch screen

**To do in App Store Connect** (only the account holder can):
1. Create the app (bundle ID `com.aymenafia.formcheck`).
2. Subscriptions → group "FormCheck Pro" → two auto-renewables matching `Products.storekit` exactly:
   - `formcheck.weekly` — $6.99/week, **3-day free trial** introductory offer
   - `formcheck.yearly` — $39.99/year
3. App Privacy questionnaire: **Usage Data → Product Interaction — collected, NOT linked to identity, NOT used for tracking** (the anonymous install ping); everything else "not collected". Matches PRIVACY.md. (If you ever disable `InstallPing.endpoint`, this reverts to "Data Not Collected".)
4. Privacy Policy URL: `https://formcheck.aymenafia.workers.dev/privacy` (hosted on Cloudflare — repo can be private).
   Support URL: `https://formcheck.aymenafia.workers.dev/support`
   Also paste the Terms link into the **App Description** (required for subscription apps): `https://formcheck.aymenafia.workers.dev/terms`
5. Age rating questionnaire (all "None" → 4+), category: Health & Fitness.
6. Screenshots: capture on device — the live skeleton + bar path is the money shot; X-ray export frames work great too.
7. Optional but great: deploy the real-time payment-ping relay ([relay/README.md](relay/README.md)), then set its URL under App Information → App Store Server Notifications (V2, Production + Sandbox).
8. Archive in Xcode (Product → Archive) → Distribute → App Store Connect. First build goes to TestFlight.

**Review notes tip:** in "Notes for Review", tell Apple the camera requirement: "Requires a camera pointed at a person exercising; all processing is on-device." Attach a short demo video link if asked.
