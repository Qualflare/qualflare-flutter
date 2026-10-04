import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';
import 'package:qualflare_flutter_example/main.dart';

/// Attempts of the retried test, counted across retries.
int _attempts = 0;

void main() {
  setUpAll(() async {
    await qualflare.loadFonts();
  });

  testWidgets('pays for the cart', (tester) async {
    qualflare.label('feature', 'checkout');
    qualflare.link('https://example.com/issues/42',
        type: 'issue', name: 'QF-42');
    qualflare.tags(['smoke', 'checkout']);
    qualflare.priority('high');

    await qualflare.step('open the checkout', () async {
      await tester.pumpWidget(const CheckoutApp());
      await qualflare.step('see the total', () async {
        expect(find.text('Total: \$20'), findsOneWidget);
      });
    });
    await qualflare.step('apply a promo code', () async {
      await tester.enterText(find.byType(TextField), 'SAVE5');
      await tester.pump();
      expect(find.text('Total: \$15'), findsOneWidget);
    });
    await qualflare.step('pay', () async {
      await tester.tap(find.text('Pay'));
      await tester.pump();
      expect(find.text('Order confirmed'), findsOneWidget);
    });
    qualflare.attachment(
      'order.json',
      utf8.encode(jsonEncode({'total': 15, 'promo': 'SAVE5'})),
      mimeType: 'application/json',
    );
    await qualflare.screenshot(tester, 'confirmed');
  });

  qualflareTestWidgets('shows a receipt (fails on purpose)', (tester) async {
    await tester.pumpWidget(const CheckoutApp());
    expect(find.text('Receipt'), findsOneWidget);
  });

  qualflareTestWidgets('recovers on the second attempt', retry: 1,
      (tester) async {
    await tester.pumpWidget(const CheckoutApp());
    _attempts++;
    if (_attempts == 1) {
      expect(find.text('Not there yet'), findsOneWidget);
    }
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
