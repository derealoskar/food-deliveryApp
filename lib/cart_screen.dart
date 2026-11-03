import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'components.dart';
import 'home_data.dart';
import 'orders_screen.dart' show TrackScreen;
import 'services.dart';
import 'theme.dart';
import 'wallet_screen.dart' show BankDetails, CopyRow;

// ================= Cart =================
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addr = TextEditingController(), _note = TextEditingController();
  int _method = 1; // 0 wallet, 1 card, 2 bank transfer
  bool _busy = false;
  Map<String, dynamic> _cfg = {};
  num _wallet = 0;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.doc('config/delivery').get().then((d) {
      if (mounted) setState(() => _cfg = d.data() ?? {});
    }).catchError((_) {});
    Repo.user().first.then((d) {
      if (!mounted) return;
      setState(() {
        _wallet = (d.data()?['wallet'] ?? 0) as num;
        _addr.text = (d.data()?['address'] ?? '') as String;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _addr.dispose();
    _note.dispose();
    super.dispose();
  }

  int _fee(int sub) {
    final free = _cfg['freeAbove'];
    if (free != null && sub >= (free as num)) return 0;
    return ((_cfg['fee'] ?? 0) as num).toInt();
  }

  Future<void> _checkout(Cart cart) async {
    final total = cart.total + _fee(cart.total);
    if (_addr.text.trim().length < 5) return toast(context, 'Enter a delivery address');
    if (_method == 0 && _wallet < total) return toast(context, 'Not enough wallet balance. Pick another method or top up.');
    setState(() => _busy = true);
    try {
      final id = await Repo.placeOrder(cart, _addr.text.trim(), note: _note.text.trim());
      HomeRepo.setAddress(_addr.text.trim());
      if (_method == 0) {
        await Repo.payWithWallet(id);
      } else if (_method == 1) {
        await launchUrl(Uri.parse(await Repo.payUrl(id)), mode: LaunchMode.externalApplication);
      }
      cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => _method == 2 ? TransferPaymentScreen(orderId: id) : TrackScreen(orderId: id)));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        toast(context, e.code == 'not-found'
            ? 'Ordering is not switched on yet: the server functions are not deployed. Deploy them, then try again.'
            : (e.message ?? 'Checkout failed. Please try again.'));
      }
    } catch (_) {
      if (mounted) toast(context, 'Checkout failed. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _boxHeader(IconData icon, String title, {String? trailing}) => Row(children: [
        CircleAvatar(radius: 16, backgroundColor: AppTheme.brand.withAlpha(28), foregroundColor: AppTheme.brand, child: Icon(icon, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        if (trailing != null) Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : null, fontSize: bold ? 17 : null))),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 20 : null, color: color)),
        ]),
      );

  Widget _itemRow(Cart cart, CartLine l) => Dismissible(
        key: ValueKey(l.key),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: Sp.lg),
          color: Colors.red,
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) => cart.changeQty(l, -l.qty),
        child: SizedBox(
          height: 74,
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: l.item.imageUrl, width: 54, height: 54, fit: BoxFit.cover, memCacheWidth: 160,
                  errorWidget: (_, __, ___) => const SizedBox(width: 54, height: 54, child: Icon(Icons.fastfood_outlined))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (l.extras.isNotEmpty)
                  Text('+ ${extrasLabel(l.extras.map((x) => x.name))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                Text(naira.format(l.unit * l.qty), style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand)),
              ]),
            ),
            QuantitySelector(qty: l.qty, onAdd: () => cart.changeQty(l, 1), onRemove: () => cart.changeQty(l, -1)),
          ]),
        ),
      );

  Widget _field(TextEditingController c, String label, IconData icon) => TextField(
        controller: c,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, isDense: true, prefixIcon: Icon(icon, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      );

  (IconData, String, String) _info(int m, bool enough) => switch (m) {
        0 => (Icons.account_balance_wallet_outlined, 'Wallet', enough ? 'Balance ${naira.format(_wallet)}' : 'Balance ${naira.format(_wallet)} (not enough)'),
        1 => (Icons.credit_card_rounded, 'Card', 'Pay securely with your debit card'),
        _ => (Icons.account_balance_rounded, 'Bank transfer', 'Transfer to our account, we confirm it'),
      };

  void _pickMethod(bool enough) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.sm),
              child: Align(alignment: Alignment.centerLeft, child: Text('Choose payment method', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            ),
            for (var m = 0; m < 3; m++) ...[
              if (m > 0) const Divider(height: 1, indent: 72),
              _MethodRow(_info(m, enough).$1, _info(m, enough).$2, _info(m, enough).$3, _method == m, m != 0 || enough, () {
                setState(() => _method = m);
                Navigator.pop(ctx);
              }),
            ],
            const SizedBox(height: Sp.sm),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final sub = cart.total, fee = _fee(sub), total = sub + fee;
    final enough = _wallet >= total;
    final lines = cart.lines.toList();
    final freeAbove = _cfg['freeAbove'];
    final isFree = freeAbove is num && sub >= freeAbove;
    final pm = _info(_method, enough);
    return Scaffold(
      appBar: const AppTopBar(title: 'Your cart'),
      body: cart.count == 0
          ? EmptyState(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', message: 'Add something tasty from the menu.', actionLabel: 'Browse menu', onAction: () => Navigator.pop(context))
          : LayoutBuilder(builder: (context, box) {
              // The order list takes whatever room is left, so everything fits on one screen.
              // With many dishes the list scrolls inside its own box.
              final itemsH = (box.maxHeight - 430).clamp(120.0, 48.0 + lines.length * 74.0).toDouble();
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
                child: Column(children: [
                  SizedBox(
                    height: itemsH,
                    child: AppCard(
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: _boxHeader(Icons.shopping_bag_outlined, 'Your order', trailing: '${cart.count} item${cart.count == 1 ? '' : 's'}'),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: lines.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _itemRow(cart, lines[i]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        _boxHeader(Icons.delivery_dining_outlined, 'Delivery details'),
                        const SizedBox(height: 10),
                        _field(_addr, 'Delivery address', Icons.location_on_outlined),
                        const SizedBox(height: 8),
                        _field(_note, 'Note to the kitchen (optional)', Icons.edit_note_rounded),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: () => _pickMethod(enough),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: AppTheme.brand.withAlpha(28), foregroundColor: AppTheme.brand, child: Icon(pm.$1, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Payment method', style: Theme.of(context).textTheme.bodySmall),
                            Text(pm.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(pm.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        const Text('Change', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w700)),
                        const Icon(Icons.chevron_right_rounded),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        _row('Subtotal', naira.format(sub)),
                        _row('Delivery fee', isFree ? 'Free' : naira.format(fee)),
                        const Divider(height: 16),
                        _row('Total', naira.format(total), bold: true, color: AppTheme.brand),
                      ]),
                    ),
                  ),
                ]),
              );
            }),
      bottomNavigationBar: cart.count == 0
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: AppButton(
                    label: _method == 2 ? 'Continue to transfer · ${naira.format(total)}' : 'Pay ${naira.format(total)}',
                    loading: _busy,
                    onPressed: () => _checkout(cart),
                  ),
                ),
              ),
            ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected, enabled;
  final VoidCallback onTap;
  const _MethodRow(this.icon, this.title, this.subtitle, this.selected, this.enabled, this.onTap);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          color: selected ? AppTheme.brand.withAlpha(16) : null,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: cs.surfaceContainerHigh, foregroundColor: selected ? AppTheme.brand : null, child: Icon(icon, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppTheme.brand : cs.outline),
          ]),
        ),
      ),
    );
  }
}

// ================= Pay an order by bank transfer =================
class TransferPaymentScreen extends StatefulWidget {
  final String orderId;
  const TransferPaymentScreen({super.key, required this.orderId});
  @override
  State<TransferPaymentScreen> createState() => _TransferPaymentScreenState();
}

class _TransferPaymentScreenState extends State<TransferPaymentScreen> {
  bool _busy = false;

  Future<void> _sent(int total) async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('paymentClaims').doc(widget.orderId).set({
        'userId': FirebaseAuth.instance.currentUser!.uid, 'orderId': widget.orderId,
        'amount': total, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {} // already submitted earlier: fine
    if (!mounted) return;
    toast(context, 'Thanks! We will confirm your transfer shortly.');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackScreen(orderId: widget.orderId)));
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.orderId.substring(0, widget.orderId.length < 6 ? widget.orderId.length : 6).toUpperCase();
    return Scaffold(
      appBar: const AppTopBar(title: 'Pay by transfer'),
      body: StreamBuilder(
        stream: Repo.order(widget.orderId),
        builder: (_, s) {
          if (s.hasError) return const Center(child: Text('Could not load this order'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final total = (((s.data!.data() ?? {})['total'] ?? 0) as num).toInt();
          return ListView(padding: const EdgeInsets.all(Sp.md), children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(Sp.lg),
                child: Column(children: [
                  const Text('Amount to transfer'),
                  Text(naira.format(total), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(height: Sp.sm),
                  Text('Use $code as the narration / reference', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: Sp.md),
            const BankDetails(),
            const SizedBox(height: Sp.md),
            AppCard(child: CopyRow('Order code', code)),
            const SizedBox(height: Sp.lg),
            const Text('1. Transfer the exact amount to the account above.\n2. Put your order code as the reference.\n3. Tap the button below. We confirm and start your order.'),
            const SizedBox(height: Sp.lg),
            AppButton(label: "I've made the transfer", loading: _busy, onPressed: () => _sent(total)),
          ]);
        },
      ),
    );
  }
}
