import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

Future<double> textWidth(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Qualflare')))));
  return tester.getSize(find.text('Qualflare')).width;
}

void main() {
  // Fonts loaded once stay loaded for the rest of this file's tests.
  testWidgets('loadFonts is idempotent', (tester) async {
    final testFont = await textWidth(tester);
    await tester.runAsync(() async {
      await qualflare.loadFonts();
      await qualflare.loadFonts();
    });
    final realFont = await textWidth(tester);
    expect(realFont, isNot(testFont));
    expect(realFont, greaterThan(0));
  });
}
