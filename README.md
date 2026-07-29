# HISAAB

**Cash-flow tracker for Pakistan** — logs spends and money-in from bank/wallet alerts, on-device only. No account, no backend, no cloud sync of your history.

Flutter app · Android (auto-capture) · iOS (Shortcuts + manual)

| | |
|---|---|
| **Package (Android)** | `com.arham.hisaab` |
| **Repo** | [Arhamdeez/hisaab](https://github.com/Arhamdeez/hisaab) |
| **Version** | See `pubspec.yaml` (`1.0.1+9` at time of writing) |

---

## What it does

- Parses **JazzCash, EasyPaisa, Raast, NayaPay, HBL, UBL, Meezan**, Google Wallet, Gmail payment alerts, and more
- Categories spends (food, transport, shopping, …), inbox for self-transfer review
- Month-end reports, charts, CSV / backup export
- Everything stored in **local SQLite** — SMS and notification text never leave the phone

---

## Platforms

### Android (primary)

| Capture | How |
|---------|-----|
| App notifications | `NotificationListenerService` — bank/wallet pushes |
| SMS | `READ_SMS` / `RECEIVE_SMS` — short codes like 3737, 8558 |
| Email alerts | Via **Gmail app notifications** (not Gmail OAuth) |

Also: boot receiver, lightweight foreground keep-alive for reliable background capture, Accept/Reject local notifications for own-account transfers.

Play Store permission notes: [`docs/PLAY_STORE_PERMISSIONS.md`](docs/PLAY_STORE_PERMISSIONS.md)

### iOS

Apple does **not** allow reading other apps’ notifications or the SMS inbox.

| Capture | How |
|---------|-----|
| SMS | **Apple Shortcuts** Message automation → `hisaab://import?text=…` |
| Manual | Add transaction in-app |
| App push | Not available (OS restriction) |

Deep link + Shortcut setup: [`docs/IOS_SHORTCUTS.md`](docs/IOS_SHORTCUTS.md)

```text
hisaab://import?text=URL_ENCODED_SMS_BODY
hisaab://import?text=...&title=JazzCash&source=sms
```

In the app: **Settings → Apple Shortcuts**, or the iOS onboarding step.

**Simulator test** (app must be installed first via `flutter run`):

```bash
xcrun simctl openurl booted 'hisaab://import?text=Rs.500%20sent%20to%20Ali%20via%20JazzCash'
```

---

## Privacy

- No backend server; no upload of spending history, SMS, or notifications
- Optional export/share is user-initiated only
- Google Fonts may fetch font files (no personal data)

See `lib/core/privacy/local_data_policy.dart`.

---

## Architecture (high level)

```text
Android:  NotificationListener / SMS  ─┐
iOS:      Shortcuts deep link           ─┼─► IngestEvent
Manual:   Add transaction               ─┘
                                              │
                                              ▼
                                    TransactionParser
                                              │
                                              ▼
                                         Deduplicator
                                              │
                                              ▼
                                      SQLite (Drift)  →  UI / local alerts
```

| Area | Path |
|------|------|
| Parser | `lib/features/parser/` |
| Dedup | `lib/features/dedup/` |
| Android bridge | `lib/features/ingest/` + `android/.../kotlin/com/arham/hisaab/` |
| iOS Shortcuts | `lib/features/ingest/shortcuts_ingest.dart` |
| Local notifications | `lib/features/notifications/` |
| DB | `lib/core/database/` (Drift) |

---

## Setup

**Requirements:** Flutter SDK (see `pubspec.yaml` SDK constraint), Xcode for iOS, Android Studio / SDK for Android.

```bash
git clone https://github.com/Arhamdeez/hisaab.git
cd hisaab   # or spend_tracker
flutter pub get
flutter run -d android   # or your device / emulator
flutter run -d ios       # Mac + simulator / device
```

```bash
flutter test
flutter analyze
```

---

## Project layout

```text
lib/
  features/ingest/      # Capture bridges (Android + iOS Shortcuts)
  features/parser/      # Alert → transaction
  features/dedup/       # Cross-source / burst / payment-alert dedup
  features/notifications/
  features/backup/
  screens/              # Home, inbox, settings, onboarding, …
  core/database/        # Drift / SQLite
android/                # Notification listener, SMS receiver, keep-alive
ios/                    # Runner + hisaab:// URL scheme
docs/                   # Store + iOS Shortcuts notes
test/                   # Parser, dedup, Shortcuts URL tests
```

---

## Contributing / commits

Keep Android and iOS capture paths separate: gate Android-only native calls with `Platform.isAndroid`; iOS Shortcuts must not change notification-listener behavior.

Prefer small commits with clear *why* messages (e.g. `fix: …`, `feat: …`) rather than vague ones.

---

## License / contact

Private / unpublished unless stated otherwise in the repo.

Support: see in-app About (`AppBrand.supportEmail`).
