import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

void main() {
  // CI runs this file with --file-reporter json: and checks that the markers
  // below are recorded as print events of this very test.
  testWidgets('works inside testWidgets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('hello')));
    qualflare.label('owner', 'mobile-team');
    await qualflare.step('find the greeting', () async {
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
