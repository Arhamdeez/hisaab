# iOS — log payments automatically

HISAAB cannot read other apps on iPhone. That is an Apple rule.

Use Apple’s free **Shortcuts** app so a payment SMS is handed to HISAAB.

In the app: **Settings → Apple Shortcuts**.

## 1. Try it once

1. Open **Messages**
2. Find a JazzCash / EasyPaisa / bank SMS with Rs or PKR
3. Press and hold → **Copy**
4. In HISAAB, open the guide → **Use the SMS I copied**
5. Check Home

## 2. Make it automatic (once)

1. Open **Shortcuts** → **Automation** (clock tab at the bottom) → **+**
2. **New Automation** / **Create Personal Automation** — not Create Shortcut
3. Search **Message** → tap it. If it asks who can send, tap **Anyone**. **Next**
4. **Add Action** → search **Log payment** → tap the one from HISAAB
5. Tap **Payment text** → **Shortcut Input** (or **Message**). Do not leave this empty.
6. **Next** → turn **Ask Before Running** OFF (tap **Don’t Ask** if it pops up). On newer iPhones turn **Run Immediately** ON instead → **Done**

Next payment SMS should open HISAAB and log it. If iPhone asks “Open in HISAAB?”, tap **Open**.

## 3. Optional — double-tap the back of the phone

HISAAB does **not** open. iOS asks for the amount on top of whatever app you are in.

1. **Settings → Accessibility → Touch → Back Tap → Double Tap**
2. Choose **Add amount** (or **Log payment**)
3. Stay in Safari / Messages / Home — double-tap the back
4. Type the Rs amount → Done

Do **not** bind Back Tap to Open URL (`hisaab://capture`). A URL always brings the full app forward.

### How to test

**Real iPhone:** set Back Tap as above. Stay on another app, then double-tap. You should only see the amount prompt.

**Simulator:** Back Tap does not work, and `xcrun simctl openurl` always opens the app (an iOS rule). Instead: open the **Shortcuts** app → **Add amount** or **Log payment** (leave Payment text empty). HISAAB should not fill the screen.

## If it fails

- No Shortcuts app: install **Shortcuts** from the App Store (Apple, free)
- Nothing on SMS: automation must be on; Ask Before Running off
- App opens but no row: that SMS may not be a payment — try one with Rs / PKR
- “Log payment” missing: open HISAAB once, search again

## Privacy

Parsing stays on this iPhone. Nothing is uploaded.
