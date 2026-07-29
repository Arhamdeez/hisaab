# iOS — Apple Shortcuts (simple guide)

On iPhone, HISAAB cannot read other apps’ notifications or the SMS inbox.
Use Apple’s free **Shortcuts** app so payment SMS open HISAAB with the text.

In the app: **Settings → Apple Shortcuts → Guide** (also in onboarding).

## Part 1 — Prove it works (no automation)

1. Open **Messages**
2. Find a JazzCash / EasyPaisa / bank payment SMS
3. Touch and hold → **Copy**
4. In HISAAB open the Shortcuts guide → tap **Import the SMS I just copied**
5. Check Home / Transactions

## Part 2 — Make it automatic

1. Open **Shortcuts** → **Automation** → **+** → **Create Personal Automation**
2. Tap **Message**
3. Optionally set Sender (3737, 8558, JazzCash…). Beginners can leave Sender empty. Tap **Next**
4. **Add Action** → search **URL Encode** → input = **Shortcut Input**
5. **Add Action** → search **URL** → type `hisaab://import?text=`
6. After `text=` insert variable **Encoded Text**
7. **Add Action** → **Open URLs** (use that URL)
8. **Next** → turn **Ask Before Running** OFF → **Done**

When the next payment SMS arrives, HISAAB should open and log it.

## Deep link (advanced)

```
hisaab://import?text=URL_ENCODED_SMS_BODY
hisaab://import?text=...&title=JazzCash&source=sms
```

## Privacy

Parsing stays on-device. Nothing is uploaded.
