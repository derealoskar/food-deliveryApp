import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_drinks_delivery/components.dart';
import 'package:food_drinks_delivery/services.dart';

void main() {
  final jollof = MenuItem('1', 'Jollof Rice', 'Food', '', 'Smoky party jollof', 2500, offerPrice: 2000);
  final zobo = MenuItem('2', 'Zobo', 'Drinks', '', 'Chilled hibiscus drink', 500);

  test('offer price is used when it is lower than the normal price', () {
    expect(jollof.hasOffer, true);
    expect(jollof.effectivePrice, 2000);
    expect(zobo.hasOffer, false);
    expect(zobo.effectivePrice, 500);
  });

  test('cart adds, removes and totals correctly', () {
    final cart = Cart()
      ..add(jollof)
      ..add(jollof)
      ..add(zobo);
    expect(cart.count, 3);
    expect(cart.total, 4500);
    cart.remove(jollof);
    expect(cart.total, 2500);
    cart.clear();
    expect(cart.count, 0);
  });

  testWidgets('QuantitySelector increments and decrements', (tester) async {
    var qty = 1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (_, set) => QuantitySelector(qty: qty, onAdd: () => set(() => qty++), onRemove: () => set(() => qty--)),
        ),
      ),
    ));
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('StatusBadge shows a readable label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusBadge('on_the_way'))));
    expect(find.text('On the way'), findsOneWidget);
  });

  testWidgets('ErrorState shows a Retry button that works', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ErrorState(onRetry: () => retried = true))));
    await tester.tap(find.text('Retry'));
    expect(retried, true);
  });
}
