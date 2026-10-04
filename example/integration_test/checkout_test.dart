import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';
import 'package:qualflare_flutter_example/main.dart';

/// Attempts of the retried test, counted across retries.
int _attempts = 0;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  // Tagged so the dogfood upload can leave it out: it fails by design, to prove
  // failure screenshots work, and would otherwise keep the public badge red.
  qualflareTestWidgets('shows a receipt (fails on purpose)',
      tags: ['demo-failure'], (tester) async {
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

  // Last: the first native capture on Android converts the Flutter surface to
  // an image, which changes rendering for the rest of the process.
  testWidgets('captures the native screen', (tester) async {
    await tester.pumpWidget(const CheckoutApp());
    await qualflare.screenshot(tester, 'native', native: true);
  });
}
