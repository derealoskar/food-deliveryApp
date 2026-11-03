import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bar_actions.dart';
import 'components.dart';
import 'theme.dart';

final _db = FirebaseFirestore.instance;
String get _uid => FirebaseAuth.instance.currentUser!.uid;

// ================= Wallet tab =================
void _openSheet(BuildContext c, int method) => showModalBottomSheet(
    context: c, isScrollControlled: true, useSafeArea: true, builder: (_) => _AddMoneySheet(method: method));

Future<void> _copyAccount(BuildContext c) async {
  final n = ((await _db.doc('config/payment').get()).data()?['accountNumber'] ?? '') as String;
  if (n.isEmpty) return toast(c, 'Account number not available yet');
  await Clipboard.setData(ClipboardData(text: n));
  if (c.mounted) toast(c, 'Account number copied');
}

class WalletTab extends StatelessWidget {
  const WalletTab({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppTopBar(title: 'Wallet', actions: [BarActions()]),
        body: ListView(padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.lg), children: [
          const _BalanceCard(),
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: _ActionTile(Icons.add_card_rounded, 'Top up', () => _openSheet(context, 0))),
            const SizedBox(width: Sp.sm),
            Expanded(child: _ActionTile(Icons.account_balance_rounded, 'Transfer', () => _openSheet(context, 1))),
            const SizedBox(width: Sp.sm),
            Expanded(child: _ActionTile(Icons.copy_rounded, 'Copy account', () => _copyAccount(context))),
          ]),
          const _PendingRequests(),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, Sp.lg, 0, Sp.sm),
            child: Text('Transactions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const _History(),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.md),
          child: Column(children: [
            CircleAvatar(backgroundColor: AppTheme.brand.withAlpha(30), foregroundColor: AppTheme.brand, child: Icon(icon)),
            const SizedBox(height: Sp.sm),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      );
}

class _BalanceCard extends StatefulWidget {
  const _BalanceCard();
  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hide = false;
  Widget _dot(double d, int a) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(a)));
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF7F1414), AppTheme.brand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: _dot(130, 28)),
          Positioned(right: 50, bottom: -60, child: _dot(120, 20)),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.sm, Sp.lg),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _db.doc('users/$_uid').snapshots(),
              builder: (_, s) {
                final bal = ((s.data?.data()?['wallet'] ?? 0) as num).toInt();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Wallet balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: _hide ? 'Show balance' : 'Hide balance',
                      color: Colors.white70,
                      icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ]),
                  s.hasData
                      ? Text(_hide ? '₦ ••••••' : naira.format(bal), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1))
                      : const Skeleton(width: 170, height: 40),
                  const SizedBox(height: Sp.sm),
                  const Text('Use your balance to pay for orders', style: TextStyle(color: Colors.white70)),
                ]);
              },
            ),
          ),
        ]),
      );
}

class _PendingRequests extends StatelessWidget {
  const _PendingRequests();
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('walletRequests').where('userId', isEqualTo: _uid).where('status', isEqualTo: 'pending').snapshots(),
        builder: (_, s) {
          final docs = s.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: Sp.md),
            child: Column(children: [
              for (final d in docs)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm),
                  child: AppCard(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0x33FF9800), foregroundColor: Colors.orange, child: Icon(Icons.hourglass_top_rounded)),
                      title: Text('${naira.format((d.data()['amount'] ?? 0) as num)} transfer pending', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('We will credit your wallet once we confirm it.'),
                    ),
                  ),
                ),
            ]),
          );
        },
      );
}

// ================= Add money sheet =================
class _AddMoneySheet extends StatefulWidget {
  final int method;
  const _AddMoneySheet({this.method = 0});
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amt = TextEditingController();
  late int _method = widget.method; // 0 card, 1 bank transfer
  bool _busy = false;

  int? get _amount => int.tryParse(_amt.text.replaceAll(',', '').trim());

  Future<void> _run(Future<void> Function(int amount) job) async {
    final a = _amount;
    if (a == null || a < 100) return toast(context, 'Enter an amount of at least ₦100');
    setState(() => _busy = true);
    try {
      await job(a);
    } catch (_) {
      if (mounted) toast(context, 'Something went wrong. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _card(int a) async {
    final r = await FirebaseFunctions.instance.httpsCallable('initWalletTopup').call({'amount': a});
    await launchUrl(Uri.parse(r.data['authorizationUrl'] as String), mode: LaunchMode.externalApplication);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _transferPaid(int a) async {
    await _db.collection('walletRequests').add(
        {'userId': _uid, 'amount': a, 'status': 'pending', 'method': 'transfer', 'createdAt': FieldValue.serverTimestamp()});
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, 'Request sent. Your wallet is credited once we confirm your transfer.');
  }

  @override
  void dispose() {
    _amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, MediaQuery.of(context).viewInsets.bottom + Sp.md),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add money', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.credit_card_rounded), label: Text('Card')),
                  ButtonSegment(value: 1, icon: Icon(Icons.account_balance_rounded), label: Text('Bank transfer')),
                ],
                selected: {_method},
                onSelectionChanged: (v) => setState(() => _method = v.first),
              ),
            ),
            const SizedBox(height: Sp.md),
            Wrap(spacing: Sp.sm, children: [
              for (final v in [1000, 2000, 5000, 10000])
                ActionChip(label: Text(naira.format(v)), onPressed: () => setState(() => _amt.text = '$v')),
            ]),
            const SizedBox(height: Sp.md),
            AppTextField(controller: _amt, label: 'Amount (₦)', icon: Icons.payments_outlined, keyboard: TextInputType.number),
            if (_method == 0) ...[
              const Text('You will be taken to a secure page to pay with your debit card.'),
              const SizedBox(height: Sp.md),
              AppButton(label: 'Continue to pay', loading: _busy, onPressed: () => _run(_card)),
            ] else ...[
              const _BankDetails(),
              const SizedBox(height: Sp.md),
              AppButton(label: "I've made the transfer", loading: _busy, onPressed: () => _run(_transferPaid)),
            ],
          ]),
        ),
      );
}

class _BankDetails extends StatelessWidget {
  const _BankDetails();
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.doc('config/payment').snapshots(),
        builder: (_, s) {
          final d = s.data?.data();
          if (s.hasError || (s.hasData && d == null)) {
            return const Text('Bank details are not available yet. Please pay by card.');
          }
          if (d == null) return const Skeleton(height: 120, radius: 16);
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(Sp.sm),
              child: Column(children: [
                _CopyRow('Bank', d['bankName'] ?? ''),
                _CopyRow('Account name', d['accountName'] ?? ''),
                _CopyRow('Account number', d['accountNumber'] ?? '', bold: true),
                if ((d['note'] ?? '') != '') Padding(padding: const EdgeInsets.all(Sp.sm), child: Text(d['note'])),
              ]),
            ),
          );
        },
      );
}

class _CopyRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _CopyRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: TextStyle(fontSize: bold ? 20 : 16, fontWeight: FontWeight.w800, letterSpacing: bold ? 1 : 0)),
        trailing: IconButton(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) toast(context, '$label copied');
          },
        ),
      );
}

// ================= Transaction history =================
class _History extends StatefulWidget {
  const _History();
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  String _f = 'all';
  late final _stream = _db.collection('users/$_uid/transactions').orderBy('createdAt', descending: true).limit(50).snapshots();

  String _label(DateTime d) {
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    return diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : DateFormat('d MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final e in const {'all': 'All', 'credit': 'Money in', 'debit': 'Money out'}.entries)
            Padding(
              padding: const EdgeInsets.only(right: Sp.sm),
              child: ChoiceChip(label: Text(e.value), selected: _f == e.key, onSelected: (_) => setState(() => _f = e.key)),
            ),
        ]),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (_, s) {
            if (s.hasError) return const Padding(padding: EdgeInsets.all(Sp.lg), child: Center(child: Text('Could not load transactions')));
            if (!s.hasData) {
              return Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(top: Sp.sm), child: Skeleton(height: 64, radius: 16))]);
            }
            final docs = s.data!.docs.where((d) => _f == 'all' || d.data()['type'] == _f).toList();
            if (docs.isEmpty) {
              return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet', message: 'Money you add and spend will show here.');
            }
            final out = <Widget>[];
            String? last;
            for (final d in docs) {
              final ts = d.data()['createdAt'];
              final l = _label(ts == null ? DateTime.now() : (ts as Timestamp).toDate());
              if (l != last) {
                out.add(Padding(padding: const EdgeInsets.fromLTRB(2, Sp.md, 0, Sp.sm), child: Text(l, style: const TextStyle(fontWeight: FontWeight.w800))));
                last = l;
              }
              out.add(Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: _TxTile(d.data())));
            }
            return Column(children: out);
          },
        ),
      ]);
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> t;
  const _TxTile(this.t);
  @override
  Widget build(BuildContext context) {
    final credit = t['type'] == 'credit';
    final color = credit ? Colors.green : Colors.red;
    final ts = t['createdAt'];
    final pending = t['status'] == 'pending';
    return AppCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded, color: color),
        ),
        title: Text(t['title'] ?? (credit ? 'Wallet top-up' : 'Payment'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(ts == null ? '' : DateFormat('d MMM, h:mm a').format(ts.toDate())),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${credit ? '+' : '-'}${naira.format((t['amount'] ?? 0) as num)}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          if (pending) const Text('Pending', style: TextStyle(fontSize: 12, color: Colors.orange)),
        ]),
      ),
    );
  }
}
