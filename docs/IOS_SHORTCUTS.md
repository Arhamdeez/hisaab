# iOS — Apple Shortcuts ingest

Apple does not allow third-party apps to read other apps' notifications or the SMS inbox. On iOS, HISAAB supports:

- **Manual transaction entry**
- **SMS via Apple Shortcuts** — a Message automation opens the app with the SMS body; the same on-device parser as Android runs

Android notification listener + SMS inbox capture is unchanged.

## Deep link

Register scheme: `hisaab`

```
hisaab://import?text=URL_ENCODED_SMS_BODY
hisaab://import?text=...&title=JazzCash
hisaab://import?text=...&source=sms
```

| Query | Meaning |
|-------|---------|
| `text` / `body` | Required. Raw SMS / alert text |
| `title` / `sender` | Optional. Used like a notification title for merchant hints |
| `source` | Optional. `sms` (default), `notification`, `manual`, `gmail` |
| `ts` | Optional. Epoch ms for the message time |

## Shortcuts automation (recommended)

1. Open **Shortcuts** → **Automation** → **+** → **Message**
2. When I receive a message from JazzCash / EasyPaisa / bank short codes (3737, 8558, …)
3. **URL Encode** the message content
4. **Open URL**: `hisaab://import?text=` + encoded text
5. Turn off **Ask Before Running** for hands-free capture

In the app: **Settings → Apple Shortcuts → How to set up** (also shown in onboarding).

## Manual Shortcut

Share or copy an SMS → run a Shortcut that opens the same `hisaab://import?text=` URL.

## What works on iOS

| Feature | Status |
|---------|--------|
| Manual entry | Supported |
| SMS via Shortcuts deep link | Supported |
| Month-end report + CSV export | Supported |
| App push notification capture | Not possible (Apple restriction) |
| SMS inbox auto-read | Not possible — use Shortcuts |

## Privacy

All parsing and storage remain **on-device**. There is no backend server and nothing is uploaded.
