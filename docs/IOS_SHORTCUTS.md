# iOS Phase 2 — Manual Entry and SMS Workaround

Apple does not allow third-party apps to read other apps' notifications or the SMS inbox. On iOS, Spend Tracker supports:

- **Manual transaction entry** — Activity tab → Add button
- **SMS via Shortcuts** — forward bank SMS text into the app

> Gmail OAuth sync was removed — on Android, bank email alerts are captured
> from Gmail app notifications via notification access instead.

## SMS workaround — Apple Shortcuts

Because iOS blocks SMS reading, use a Shortcut to copy transaction SMS text into Spend Tracker via the share sheet or a deep link.

### Option A: Manual paste (simplest)

1. Copy a bank/UPI SMS.
2. Open Spend Tracker → Settings → use **Add Transaction** on the Activity tab, or paste into a future "Import text" field.

### Option B: Shortcuts automation (recommended)

1. Open the **Shortcuts** app → **Automation** → **+** → **Message**.
2. Trigger: **When I receive a message** from senders containing `HDFC`, `PAYTM`, `UPI`, etc.
3. Action: **Get Text from Input** → **Open App** (Spend Tracker).

For programmatic import, add a custom URL scheme to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>spendtracker</string>
    </array>
  </dict>
</array>
```

Then configure the Shortcut to open:

```
spendtracker://import?text=ENCODED_SMS_BODY
```

Handle this in Flutter with `app_links` or `uni_links` (phase 2 enhancement).

## What works on iOS today

| Feature | Status |
|---------|--------|
| Manual entry | Supported |
| Month-end report + CSV export | Supported |
| Notification capture | Not possible (Apple restriction) |
| SMS auto-read | Not possible — use Shortcuts |

## Privacy

All parsing and storage remain **on-device**. There is no backend server and nothing is uploaded.
