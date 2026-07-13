# Google Play — permissions declaration (HISAAB)

Use this when submitting HISAAB to Google Play Console.

## App category

- **Category:** Finance
- **Type:** Personal expense / spending tracker with automatic capture

## Store listing (promote core features)

Include these prominently in the short and full description:

- Automatic expense tracking from **bank and wallet payment alerts**
- **SMS-based money management** for wallet/bank transaction texts (Easypaisa, Raast, JazzCash, UBL, etc.)
- On-device processing — **data stays on the phone**
- Bank email alerts captured from the Gmail app's notifications (no Gmail account access)

## SMS permissions declaration form

**Permissions:** `READ_SMS`, `RECEIVE_SMS`

**Declared use case:** SMS-based money management

**Core functionality:** HISAAB automatically imports payment transaction alerts sent by banks and mobile wallets via SMS so users do not have to type expenses manually. Without SMS access, users in markets where wallets send transaction texts (e.g. Easypaisa 3737, Raast 8558) cannot use the primary automation path.

**What is read:**

- Only SMS from known wallet/bank short codes and transaction-shaped messages
- Personal chat SMS, OTPs, and marketing texts are ignored in code

**What is NOT done:**

- SMS is never uploaded to a server
- SMS is never used for ads, analytics resale, or unrelated features
- HISAAB is not a default SMS handler and does not send SMS

**Video demo (required by Google):** Record ~2 minutes showing:

1. Onboarding SMS disclosure dialog
2. User granting SMS permission
3. A wallet/bank transaction SMS arriving (or inbox rescan)
4. The parsed transaction appearing in HISAAB
5. Settings showing SMS automation enabled

## Notification access

**Feature:** `NotificationListenerService` (user enables in Android Settings)

**Core functionality:** Capture payment notifications from bank/wallet apps (JazzCash, NayaPay, UBL, Google Wallet, etc.) for automatic expense logging.

**Disclosure:** Shown in onboarding before the user opens notification access settings.

## Foreground service (special use)

**Type:** `FOREGROUND_SERVICE_SPECIAL_USE`

**Subtype (manifest):** Monitor payment notifications for expense tracking

**Declaration:** Explain that a lightweight foreground service keeps notification capture reliable when the app is in the background. It does not run unrelated tasks.

## Permissions removed for Play compliance

- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — **removed**. Users are directed to the system battery settings list instead (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`), which does not require a restricted manifest permission.

## Privacy policy (required)

Your privacy policy must state:

- What data is collected (payment alerts from notifications and SMS)
- That processing is on-device
- That SMS/notification content is not sold or shared
- How users can revoke access (Android Settings / HISAAB Settings)

## Data handling (no backend)

HISAAB has **no backend server**. All transaction data lives in local SQLite on the device.

- **No cloud sync** of spending history
- **No analytics** SDKs (Firebase, Sentry, etc.)
- **Android auto-backup disabled** — data is not backed up to Google Drive by default
- **Release builds do not log** SMS/notification bodies to logcat
- **Cleartext HTTP blocked** in release builds
- **Export/share** only when the user explicitly taps Export backup

Optional network use:

- Google Fonts — downloads font files only (no personal data)

## Checklist before submit

- [ ] Privacy policy URL added in Play Console
- [ ] SMS permissions declaration form submitted (SMS-based money management)
- [ ] Foreground service declaration submitted (special use)
- [ ] Demo video uploaded for SMS declaration
- [ ] Store listing mentions automatic SMS + notification capture as core features
- [ ] Data safety form: declare SMS and notification data as collected, not shared, processed on-device
