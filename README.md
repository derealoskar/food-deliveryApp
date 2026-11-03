# Bite & Sip — Food & Drinks Delivery (Flutter)

## Setup
1. `flutter create --org com.yourco --project-name food_drinks_delivery .` (generates android/ and ios/), keep these lib/ files.
2. `dart pub global activate flutterfire_cli && flutterfire configure`
3. Firebase: enable Email/Password auth, Firestore, Cloud Functions.
4. Firestore: `menu/{id}` {name, category: Food|Drinks, price (int), imageUrl, description, available}; `orders`, `users`.
5. Cloud Functions you still need to write: `createOrder` (reprice from `menu`, write order with status `pending_payment`), `initPayment` (Paystack/Flutterwave, secret key server-side), and a payment webhook that sets status `paid`.
6. Firestore rules: users read/write only their own `users/{uid}`; `orders` readable by owner, writable only by Functions; `wallet` never client-writable.

## Release checklist
- Android: set applicationId, create upload keystore, `key.properties`, then `flutter build appbundle --release`.
- iOS: set bundle ID + signing in Xcode, `flutter build ipa --release`, upload via Transporter.
- Store listings: privacy policy URL, data-safety/privacy labels, screenshots, icons (`flutter_launcher_icons`).
- Apple: in-app account deletion is included (required); physical goods use external payment, not IAP.

## Firestore schema for the Home screen (all content is backend-driven)
- `menu/{id}`: name, description, price (int), offerPrice (optional int), rating (0–5), imageUrl, category (must match a `categories.name`, e.g. "Drinks"), available (bool), popular (bool), recommended (bool), visible (false hides it).
- `categories/{id}`: name, imageUrl, order (int).
- `banners/{id}`: imageUrl, title, subtitle, category (optional; tapping filters to it), active (bool), order (int).
- `users/{uid}`: name, photoUrl, address. Subcollections: `favorites/{menuId}`, `notifications/{id}` {title, body, read, createdAt}.
- `orders/{id}`: userId, status, total, createdAt, items: [{itemId, name, qty, price}] (drives "Order again").
- Firestore rules: `menu`, `categories`, `banners` readable by signed-in users, writable by admins only; `users/{uid}/**` only by that user.

## Wallet
- `config/payment`: bankName, accountName, accountNumber, note (shown on the Bank transfer tab; edit in Firestore, never hardcode).
- `users/{uid}.wallet` (int naira) is changed ONLY by Cloud Functions. `users/{uid}/transactions/{id}`: type (credit|debit), amount, title, status (success|pending|failed), createdAt. Written only by Functions.
- `walletRequests/{id}`: userId, amount, status (pending|approved|rejected), createdAt. Created by the app when a customer says they transferred; an admin confirms and credits the wallet.
- Functions still to write: `initWalletTopup` (Paystack/Flutterwave init, returns authorizationUrl), `payWithWallet` (transaction: check balance, debit, set order paid, add a debit transaction), a payment webhook that credits the wallet and adds a credit transaction, and an admin action to approve a walletRequest.

## Orders & Profile
- `config/support`: phone, whatsapp (digits only, with country code e.g. 2348012345678), email, privacyUrl, termsUrl. Edit in Firestore.
- Orders: `items` [{itemId, name, price, qty}], `address`, `paymentMethod`, `courierName`, `courierPhone`, `status`.
- Function still to write: `cancelOrder` (allowed only for pending_payment/paid; refunds to wallet; sets status cancelled).

## Cloud Functions (Paystack) — deploy steps
1. Install Node.js 22 and run `npm install -g firebase-tools`, then `firebase login`.
2. In the project root (where `firebase.json` is): `firebase use --add` and pick your Firebase project.
3. Upgrade the Firebase project to the Blaze plan (required for Functions).
4. Save your Paystack TEST secret key (starts with `sk_test_`): `firebase functions:secrets:set PAYSTACK_SECRET`
5. `cd functions` then `npm install`, then `cd ..`
6. `firebase deploy --only functions`
7. Copy the `paystackWebhook` URL that deploy prints. In the Paystack dashboard, open Settings > API Keys & Webhooks and paste it as the Test Webhook URL.
8. Pay with a Paystack test card (see Paystack's docs) and check the order turns `paid`.
9. Optional `config/delivery` document: `fee` (number), `freeAbove` (number).
10. Rules: `firebase deploy --only firestore:rules` ONLY when your menu is final. They stop the in-app sample-data button from writing.
11. To get an admin login for editing the menu from the app later, set the custom claim `admin: true` on your user with the Admin SDK.

## Paying an order by bank transfer
- Customer picks Bank transfer in the cart > sees amount, your account (from `config/payment`) and an order code > taps "I've made the transfer" > `paymentClaims/{orderId}` is created and the order shows "Transfer submitted".
- You check your bank app, then in Firestore set `paymentClaims/{orderId}.status` to `approved`. The order becomes `paid` automatically. Redeploy functions: `firebase deploy --only functions`.

## Menu extras
- `extras/{id}`: name (e.g. Chicken), group ("Extra meat" or "Sides"), price (int), order (int), available (bool). Drinks are taken automatically from `menu` items whose category is "Drinks".
- Home "Menu" row = items in Jollof Rice / Fried Rice / Pasta whose name contains chicken or beef. To show any other dish there, add a boolean field `featured: true` to it.
- Redeploy functions after this update: `firebase deploy --only functions`.

## Welcome page (first screen, before Log in / Register)
Edit the Firestore document `config/welcome` (no app update needed). All fields optional:
- `videoUrl` (string): direct link to an .mp4 video. It plays full screen, muted, on a loop.
- `images` (array of strings): direct picture links. They float around the screen. Used when there is no videoUrl.
- `title` (string): replaces the Bite & Sip wordmark. `subtitle` (string): the line under it.
If neither video nor images are set, floating food and drink emojis are shown.
Add the rule `match /config/welcome { allow read: if true; }` so signed-out users can read it. Run `flutter pub add video_player`.
