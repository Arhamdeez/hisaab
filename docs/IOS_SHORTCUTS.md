# iOS — Apple Shortcuts & Back Tap

On iPhone, HISAAB cannot read other apps’ notifications or the SMS inbox.
Use Apple’s free **Shortcuts** app (and optional **Back Tap**) so payment text opens HISAAB.

In the app: **Settings → Apple Shortcuts → Guide**.

## Part 1 — Prove it works (no automation)

1. Open **Messages**
2. Find a JazzCash / EasyPaisa / bank payment SMS
3. Touch and hold → **Copy**
4. In HISAAB open the Shortcuts guide → tap **Import the SMS I just copied**
5. Check Home / Transactions

## Part 2 — Message automation (hands-free SMS)

1. **Shortcuts** → **Automation** → **+** → **Create Personal Automation**
2. Tap **Message**
3. Optionally set Sender (3737, 8558, JazzCash…). Beginners can leave Sender empty. Tap **Next**
4. **Add Action** → **URL Encode** → input = **Shortcut Input**
5. **Add Action** → **URL** → `hisaab://import?text=`
6. After `text=` insert **Encoded Text**
7. **Add Action** → **Open URLs**
8. **Next** → turn **Ask Before Running** OFF → **Done**

## Part 3 — Back Tap (double-tap the back of the iPhone)

Apple only lets Back Tap run system actions or Shortcuts — apps cannot register a private “Back Tap API.”

HISAAB ships an App Intent: **Log payment from clipboard**.

1. **Settings → Accessibility → Touch → Back Tap → Double Tap**
2. Choose **Log payment from clipboard** / **Log from clipboard** (under Shortcuts)
3. Daily use: **copy** a payment SMS → **double-tap** the back of the phone → HISAAB logs it

If the action is missing: open HISAAB once, or create a Shortcut whose only action is “Log payment from clipboard”, then assign that Shortcut to Back Tap.

## Deep link (advanced)

```
hisaab://import?text=URL_ENCODED_SMS_BODY
hisaab://import?text=...&title=JazzCash&source=sms
```

## Privacy

Parsing stays on-device. Nothing is uploaded.
