const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const PAYSTACK_SECRET = defineSecret('PAYSTACK_SECRET');
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

// ---------- helpers ----------
const need = (cond, code, msg) => { if (!cond) throw new HttpsError(code, msg); };
const uidOf = (req) => { need(req.auth, 'unauthenticated', 'Please log in.'); return req.auth.uid; };
const addTx = (t, uid, d) =>
  t.set(db.collection(`users/${uid}/transactions`).doc(), { status: 'success', ...d, createdAt: FieldValue.serverTimestamp() });
const notify = (t, uid, title, body) =>
  t.set(db.collection(`users/${uid}/notifications`).doc(), { title, body, read: false, createdAt: FieldValue.serverTimestamp() });

async function paystackInit({ email, amountNaira, reference, metadata }) {
  const res = await fetch('https://api.paystack.co/transaction/initialize', {
    method: 'POST',
    headers: { Authorization: `Bearer ${PAYSTACK_SECRET.value()}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, amount: Math.round(amountNaira * 100), currency: 'NGN', reference, metadata }),
  });
  const json = await res.json();
  if (!res.ok || !json.status) throw new HttpsError('internal', 'Could not start payment. Please try again.');
  return json.data.authorization_url;
}

// ---------- 1. create an order (prices always come from the database, never from the app) ----------
exports.createOrder = onCall(async (req) => {
  const uid = uidOf(req);
  const { lines, address } = req.data || {};
  need(Array.isArray(lines) && lines.length > 0 && lines.length <= 40, 'invalid-argument', 'Your cart is empty.');
  need(typeof address === 'string' && address.trim().length >= 5, 'invalid-argument', 'Enter a delivery address.');
  let subtotal = 0;
  const out = [];
  for (const l of lines) {
    const qty = Math.floor(Number(l.qty));
    need(qty >= 1 && qty <= 50, 'invalid-argument', 'Invalid quantity.');
    const ms = await db.doc(`menu/${l.itemId}`).get();
    const m = ms.data();
    need(ms.exists && m.visible !== false && m.available !== false, 'failed-precondition', `${m ? m.name : 'An item'} is not available.`);
    const base = m.offerPrice && m.offerPrice < m.price ? m.offerPrice : m.price;
    const extras = [];
    for (const id of (Array.isArray(l.extras) ? l.extras : []).slice(0, 12)) {
      const sid = String(id);
      const isDrink = sid.startsWith('menu:');
      const s = await db.doc(isDrink ? `menu/${sid.slice(5)}` : `extras/${sid}`).get();
      const x = s.data();
      need(s.exists && x.available !== false && (!isDrink || x.category === 'Drinks'), 'failed-precondition', 'An extra is no longer available.');
      extras.push({ id: sid, name: x.name, price: x.offerPrice && x.offerPrice < x.price ? x.offerPrice : x.price });
    }
    const unit = base + extras.reduce((a, e) => a + e.price, 0);
    subtotal += unit * qty;
    out.push({ itemId: ms.id, name: m.name, price: unit, qty, extras });
  }
  const cfg = (await db.doc('config/delivery').get()).data() || {}; // optional: { fee: 500, freeAbove: 10000 }
  const fee = cfg.freeAbove && subtotal >= cfg.freeAbove ? 0 : cfg.fee || 0;
  const ref = await db.collection('orders').add({
    userId: uid, items: out, subtotal, deliveryFee: fee, total: subtotal + fee,
    address: address.trim(), note: String(req.data.note || '').slice(0, 200), status: 'pending_payment', createdAt: FieldValue.serverTimestamp(),
  });
  return { orderId: ref.id };
});

// ---------- 2. start a card payment for an order ----------
exports.initPayment = onCall({ secrets: [PAYSTACK_SECRET] }, async (req) => {
  const uid = uidOf(req);
  const snap = await db.doc(`orders/${req.data?.orderId}`).get();
  need(snap.exists && snap.data().userId === uid, 'not-found', 'Order not found.');
  const o = snap.data();
  need(o.status === 'pending_payment', 'failed-precondition', 'This order is not awaiting payment.');
  const reference = crypto.randomUUID().replace(/-/g, '');
  await db.doc(`payments/${reference}`).set({ userId: uid, type: 'order', orderId: snap.id, amount: o.total, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  const url = await paystackInit({ email: req.auth.token.email, amountNaira: o.total, reference, metadata: { type: 'order', orderId: snap.id } });
  return { authorizationUrl: url };
});

// ---------- 3. start a card top-up for the wallet ----------
exports.initWalletTopup = onCall({ secrets: [PAYSTACK_SECRET] }, async (req) => {
  const uid = uidOf(req);
  const amount = Number(req.data?.amount);
  need(Number.isInteger(amount) && amount >= 100 && amount <= 500000, 'invalid-argument', 'Enter an amount between ₦100 and ₦500,000.');
  const reference = crypto.randomUUID().replace(/-/g, '');
  await db.doc(`payments/${reference}`).set({ userId: uid, type: 'topup', amount, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  const url = await paystackInit({ email: req.auth.token.email, amountNaira: amount, reference, metadata: { type: 'topup' } });
  return { authorizationUrl: url };
});

// ---------- 4. Paystack webhook: the ONLY place card payments are confirmed ----------
exports.paystackWebhook = onRequest({ secrets: [PAYSTACK_SECRET] }, async (req, res) => {
  const sig = req.get('x-paystack-signature');
  const hash = crypto.createHmac('sha512', PAYSTACK_SECRET.value()).update(req.rawBody).digest('hex');
  if (!sig || sig !== hash) return res.status(401).send('bad signature');
  if (req.body.event !== 'charge.success') return res.status(200).send('ignored');
  const d = req.body.data;
  const pRef = db.doc(`payments/${d.reference}`);
  try {
    await db.runTransaction(async (t) => {
      const p = await t.get(pRef);
      if (!p.exists || p.data().status === 'success') return; // unknown reference, or already processed
      const pay = p.data();
      const oRef = pay.type === 'order' ? db.doc(`orders/${pay.orderId}`) : null;
      const o = oRef ? await t.get(oRef) : null;
      if (d.currency !== 'NGN' || d.amount !== Math.round(pay.amount * 100)) { t.update(pRef, { status: 'amount_mismatch' }); return; }
      t.update(pRef, { status: 'success', paidAt: FieldValue.serverTimestamp() });
      if (o && o.exists && o.data().status === 'pending_payment') {
        t.update(oRef, { status: 'paid', paymentMethod: 'Card (Paystack)', paidAt: FieldValue.serverTimestamp() });
      } else {
        // wallet top-up, or an order that can no longer be paid (e.g. cancelled): credit the wallet instead
        t.update(db.doc(`users/${pay.userId}`), { wallet: FieldValue.increment(pay.amount) });
        addTx(t, pay.userId, { type: 'credit', amount: pay.amount, title: pay.type === 'topup' ? 'Wallet top-up (card)' : 'Refund (order not payable)' });
        notify(t, pay.userId, 'Wallet credited', `₦${pay.amount} was added to your wallet.`);
      }
    });
  } catch (e) {
    console.error(e);
    return res.status(500).send('error'); // Paystack will retry
  }
  res.status(200).send('ok');
});

// ---------- 5. pay an order from the wallet ----------
exports.payWithWallet = onCall(async (req) => {
  const uid = uidOf(req);
  const oRef = db.doc(`orders/${req.data?.orderId}`);
  const uRef = db.doc(`users/${uid}`);
  await db.runTransaction(async (t) => {
    const [o, u] = await Promise.all([t.get(oRef), t.get(uRef)]);
    need(o.exists && o.data().userId === uid, 'not-found', 'Order not found.');
    need(o.data().status === 'pending_payment', 'failed-precondition', 'This order is not awaiting payment.');
    const total = o.data().total;
    need(((u.data() || {}).wallet || 0) >= total, 'failed-precondition', 'Not enough wallet balance.');
    t.update(uRef, { wallet: FieldValue.increment(-total) });
    t.update(oRef, { status: 'paid', paymentMethod: 'Wallet', paidAt: FieldValue.serverTimestamp() });
    addTx(t, uid, { type: 'debit', amount: total, title: `Order #${o.id.slice(0, 6).toUpperCase()}` });
  });
  return { ok: true };
});

// ---------- 6. cancel an order (only before the kitchen starts); money goes back to the wallet ----------
exports.cancelOrder = onCall(async (req) => {
  const uid = uidOf(req);
  const oRef = db.doc(`orders/${req.data?.orderId}`);
  await db.runTransaction(async (t) => {
    const o = await t.get(oRef);
    need(o.exists && o.data().userId === uid, 'not-found', 'Order not found.');
    const { status, total } = o.data();
    need(status === 'pending_payment' || status === 'paid', 'failed-precondition', 'This order can no longer be cancelled.');
    t.update(oRef, { status: 'cancelled', cancelledAt: FieldValue.serverTimestamp() });
    if (status === 'paid') {
      t.update(db.doc(`users/${uid}`), { wallet: FieldValue.increment(total) });
      addTx(t, uid, { type: 'credit', amount: total, title: `Refund: order #${o.id.slice(0, 6).toUpperCase()}` });
    }
  });
  return { ok: true };
});

// ---------- 7. tell the customer when an order changes status (you edit `status` in the Firebase console) ----------
exports.onOrderStatusChange = onDocumentUpdated('orders/{id}', async (e) => {
  const b = e.data.before.data(), a = e.data.after.data();
  if (b.status === a.status) return;
  const msg = {
    paid: ['Order confirmed', 'We received your payment.'],
    preparing: ['Being prepared', 'The kitchen is preparing your order.'],
    on_the_way: ['On the way', 'Your rider is on the way.'],
    delivered: ['Delivered', 'Enjoy your meal!'],
    cancelled: ['Order cancelled', 'Your order was cancelled.'],
  }[a.status];
  if (!msg) return;
  await db.collection(`users/${a.userId}/notifications`).add({ title: msg[0], body: msg[1], read: false, createdAt: FieldValue.serverTimestamp() });
});

// ---------- 8. confirm a bank transfer: in the console, set walletRequests/{id}.status to "approved" ----------
exports.onWalletRequestReviewed = onDocumentUpdated('walletRequests/{id}', async (e) => {
  const b = e.data.before.data(), a = e.data.after.data();
  if (b.status !== 'pending' || a.status !== 'approved') return;
  await db.runTransaction(async (t) => {
    const r = await t.get(e.data.after.ref);
    if (r.data().credited) return;
    t.update(e.data.after.ref, { credited: true });
    t.update(db.doc(`users/${a.userId}`), { wallet: FieldValue.increment(a.amount) });
    addTx(t, a.userId, { type: 'credit', amount: a.amount, title: 'Wallet top-up (bank transfer)' });
    notify(t, a.userId, 'Wallet credited', `₦${a.amount} was added to your wallet.`);
  });
});

// ---------- 9. bank transfer for an ORDER: customer taps "I've made the transfer" (creates paymentClaims/{orderId}) ----------
exports.onPaymentClaimCreated = onDocumentCreated('paymentClaims/{id}', async (e) => {
  await db.doc(`orders/${e.data.data().orderId}`).update({ transferSubmitted: true });
});

// You check your bank, then in the console set paymentClaims/{orderId}.status to "approved".
exports.onPaymentClaimReviewed = onDocumentUpdated('paymentClaims/{id}', async (e) => {
  const b = e.data.before.data(), a = e.data.after.data();
  if (b.status !== 'pending' || a.status !== 'approved') return;
  await db.runTransaction(async (t) => {
    const cRef = e.data.after.ref, oRef = db.doc(`orders/${a.orderId}`);
    const [c, o] = await Promise.all([t.get(cRef), t.get(oRef)]);
    if (c.data().credited) return;
    t.update(cRef, { credited: true });
    if (o.exists && o.data().status === 'pending_payment' && o.data().total === a.amount) {
      t.update(oRef, { status: 'paid', paymentMethod: 'Bank transfer', paidAt: FieldValue.serverTimestamp() });
    } else {
      // order cancelled or amount differs: keep the customer's money safe in their wallet
      t.update(db.doc(`users/${a.userId}`), { wallet: FieldValue.increment(a.amount) });
      addTx(t, a.userId, { type: 'credit', amount: a.amount, title: 'Bank transfer credited to wallet' });
    }
  });
});
