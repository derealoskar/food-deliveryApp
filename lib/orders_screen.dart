import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bar_actions.dart';
import 'components.dart';
import 'cart_screen.dart' show CartScreen, TransferPaymentScreen;
import 'services.dart';

const _activeStatuses = {'pending_payment', 'paid', 'preparing', 'on_the_way'};

double? _progress(String? st) {
  const order = ['pending_payment', 'paid', 'preparing', 'on_the_way', 'delivered'];
  final i = order.indexOf(st ?? '');
  return i < 0 || st == 'delivered' ? null : (i + 1) / order.length;
}

String _summary(Map<String, dynamic> o) =>
    (o['items'] as List? ?? []).map((i) => '${i['qty']}× ${i['name']}').join(', ');

// ================= Orders list (Active / Past) =================
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  late var _orders = Repo.myOrders();

  Widget _list(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String title, String msg) {
    if (docs.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: title, message: msg);
    return ListView.separated(
      padding: const EdgeInsets.all(Sp.md),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: Sp.sm),
      itemBuilder: (_, i) {
        final d = docs[i], o = d.data();
        return OrderCard(
          id: d.id,
          status: '${o['status']}',
          total: ((o['total'] ?? 0) as num).toInt(),
          date: (o['createdAt'] as Timestamp?)?.toDate(),
          summary: _summary(o),
          progress: _progress(o['status'] as String?),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(orderId: d.id))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            actions: const [BarActions()],
            title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
            bottom: const TabBar(
              dividerColor: Colors.transparent,
              tabs: [Tab(text: 'Active'), Tab(text: 'Completed')],
            ),
          ),
          body: StreamBuilder(
            stream: _orders,
            builder: (_, s) {
              if (s.hasError) return ErrorState(onRetry: () => setState(() => _orders = Repo.myOrders()));
              if (!s.hasData) {
                return ListView(padding: const EdgeInsets.all(Sp.md), children: [
                  for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: Sp.sm), child: Skeleton(height: 110, radius: 20)),
                ]);
              }
              final docs = s.data!;
              final active = docs.where((d) => _activeStatuses.contains(d.data()['status'])).toList();
              final past = docs.where((d) => !_activeStatuses.contains(d.data()['status'])).toList();
              return TabBarView(children: [
                _list(active, 'No active orders', 'Your current orders will show here.'),
                _list(past, 'No completed orders', 'Delivered and cancelled orders will show here.'),
              ]);
            },
          ),
        ),
      );
}

// ================= Order details + tracking =================
class TrackScreen extends StatelessWidget {
  final String orderId;
  const TrackScreen({super.key, required this.orderId});
  static const _steps = {
    'pending_payment': 'Awaiting payment',
    'paid': 'Order confirmed',
    'preparing': 'Being prepared',
    'on_the_way': 'On the way',
    'delivered': 'Delivered',
  };

  Future<void> _cancel(BuildContext context) async {
    if (!await confirmDialog(context, title: 'Cancel this order?', message: 'Any money paid will be returned to your wallet.', confirmLabel: 'Cancel order', destructive: true)) return;
    try {
      await Repo.cancelOrder(orderId);
    } catch (_) {
      if (context.mounted) toast(context, 'Could not cancel. The kitchen may already be preparing it.');
    }
  }

  Future<void> _reorder(BuildContext context, List items) async {
    final menu = await Repo.menu().first;
    if (!context.mounted) return;
    final cart = context.read<Cart>();
    var added = 0;
    for (final i in items) {
      final m = menu.where((x) => x.id == i['itemId'] && x.available).firstOrNull;
      if (m == null) continue;
      for (var k = 0; k < ((i['qty'] ?? 1) as num).toInt(); k++) {
        cart.add(m);
      }
      added++;
    }
    if (added == 0) return toast(context, 'Those items are not available right now.');
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _help(BuildContext c) async {
    final d = (await FirebaseFirestore.instance.doc('config/support').get()).data() ?? {};
    final url = (d['whatsapp'] ?? '') != '' ? 'https://wa.me/${d['whatsapp']}' : (d['phone'] ?? '') != '' ? 'tel:${d['phone']}' : '';
    if (url.isEmpty) {
      if (c.mounted) toast(c, 'Support details are not available yet.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Order details'),
        body: StreamBuilder(
          stream: Repo.order(orderId),
          builder: (_, s) {
            if (s.hasError) return const Center(child: Text('Could not load this order'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final o = s.data!.data() ?? {};
            final status = (o['status'] ?? 'pending_payment') as String;
            final keys = _steps.keys.toList();
            final now = keys.indexOf(status);
            final items = (o['items'] as List? ?? []);
            final phone = (o['courierPhone'] ?? '') as String;
            return ListView(padding: const EdgeInsets.all(Sp.md), children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text('Order #${orderId.substring(0, orderId.length < 6 ? orderId.length : 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      StatusBadge(status),
                    ]),
                    if (status != 'cancelled')
                      for (var i = 0; i < keys.length; i++)
                        ListTile(
                          dense: true,
                          leading: Icon(i <= now ? Icons.check_circle : Icons.radio_button_unchecked, color: i <= now ? Theme.of(context).colorScheme.primary : null),
                          title: Text(_steps[keys[i]]!, style: TextStyle(fontWeight: i == now ? FontWeight.w800 : null)),
                        ),
                  ]),
                ),
              ),
              const SizedBox(height: Sp.md),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Column(children: [
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.sm),
                        child: Row(children: [
                          Expanded(child: Text('${i['qty']}× ${i['name']}${(i['extras'] as List? ?? []).isEmpty ? '' : '\n+ ${extrasLabel((i['extras'] as List).map((x) => '${x['name']}'))}'}')),
                          Text(naira.format((((i['price'] ?? 0) as num) * ((i['qty'] ?? 1) as num)))),
                        ]),
                      ),
                    if (o['deliveryFee'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.sm),
                        child: Row(children: [const Expanded(child: Text('Delivery fee')), Text(naira.format((o['deliveryFee'] ?? 0) as num))]),
                      ),
                    const Divider(),
                    Row(children: [
                      const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                      Text(naira.format((o['total'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: Sp.md),
              AppCard(
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('Delivery address'), subtitle: Text('${o['address'] ?? '-'}')),
                  if (o['paymentMethod'] != null)
                    ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Payment'), subtitle: Text('${o['paymentMethod']}')),
                  if (o['courierName'] != null)
                    ListTile(
                      leading: const Icon(Icons.delivery_dining),
                      title: Text('${o['courierName']}'),
                      subtitle: const Text('Your rider'),
                      trailing: phone.isEmpty ? null : IconButton.filledTonal(tooltip: 'Call rider', icon: const Icon(Icons.call), onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone))),
                    ),
                ]),
              ),
              const SizedBox(height: Sp.lg),
              if (status == 'pending_payment' && o['transferSubmitted'] == true)
                const AppCard(child: ListTile(leading: Icon(Icons.hourglass_top_rounded, color: Colors.orange), title: Text('Transfer submitted', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('We are confirming your payment. This order starts once confirmed.'))),
              if (status == 'pending_payment' && o['transferSubmitted'] != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm),
                  child: AppButton(label: 'Pay by transfer', icon: Icons.account_balance_rounded, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransferPaymentScreen(orderId: orderId)))),
                ),
              if (status == 'pending_payment' || status == 'paid') AppButton(label: 'Cancel order', secondary: true, onPressed: () => _cancel(context)),
              if (status == 'delivered' || status == 'cancelled') AppButton(label: 'Order again', icon: Icons.replay_rounded, onPressed: () => _reorder(context, items)),
              const SizedBox(height: Sp.sm),
              AppButton(label: 'Need help?', secondary: true, icon: Icons.headset_mic_outlined, onPressed: () => _help(context)),
            ]);
          },
        ),
      );
}
