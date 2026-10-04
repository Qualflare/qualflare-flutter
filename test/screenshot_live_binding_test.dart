import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

import 'capture.dart';

class _Pay extends StatefulWidget {
  const _Pay();

  @override
  State<_Pay> createState() => _PayState();
}

class _PayState extends State<_Pay> {
  bool _paid = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: _paid
                ? const Text('Order confirmed')
                : FilledButton(
                    onPressed: () => setState(() => _paid = true),
                    child: const Text('Pay'),
                  ),
          ),
        ),
      );
}

void main() {
  // The binding integration_test uses on a device: a live binding, which
  // paints a fading trail where the pointer went for a few frames after a tap.
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot after a tap on the device binding', (tester) async {
    expect(binding, isA<LiveTestWidgetsFlutterBinding>());
    await tester.pumpWidget(const _Pay());
    await tester.tap(find.text('Pay'));
    await tester.pump();
    expect(find.text('Order confirmed'), findsOneWidget);
    final out = await capture(() => qualflare.screenshot(tester, 'confirmed'));
    expect(warnings(out), isEmpty);
    expect(attachments(out).keys, ['confirmed.png']);
  });
  // The host running `flutter test` is neither Android nor iOS: native: true
  // must use the root layer rather than ask a platform that cannot capture.
  testWidgets(
      'native on the integration binding off-device uses the root layer',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ColoredBox(color: Color(0xFFFF0000))));
    final out = await capture(
        () => qualflare.screenshot(tester, 'native', native: true));
    expect(warnings(out), isEmpty);
    final shots = attachments(out);
    expect(shots.keys, ['native.png']);
    // PNG signature.
    expect(shots['native.png']!.take(8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });
}
