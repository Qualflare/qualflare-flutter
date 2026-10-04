import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';
import 'package:qualflare_flutter/src/test_widgets.dart'
    show runWithFailureScreenshot;

import 'capture.dart';

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => throw StateError('build failed');
}

void main() {
  testWidgets('wrapper screenshots on failure and rethrows', (tester) async {
    Object? caught;
    final out = await capture(() async {
      try {
        await runWithFailureScreenshot(tester, (tester) async {
          await tester.pumpWidget(
              const MaterialApp(home: ColoredBox(color: Color(0xFFFF0000))));
          expect(1, 2);
        });
      } catch (e) {
        caught = e;
      }
    });
    expect(caught, isA<TestFailure>());
    expect(warnings(out), isEmpty);
    expect(attachments(out).keys, ['failure.png']);
  });

  testWidgets('wrapper rethrows the same object', (tester) async {
    final error = StateError('boom');
    Object? caught;
    await capture(() async {
      try {
        await runWithFailureScreenshot(tester, (tester) async => throw error);
      } catch (e) {
        caught = e;
      }
    });
    expect(caught, same(error));
  });

  testWidgets('wrapper does not change how tests fail', (tester) async {
    // A passing body: nothing attached, nothing warned.
    final passing = await capture(() => runWithFailureScreenshot(
          tester,
          (tester) async =>
              tester.pumpWidget(const MaterialApp(home: Text('ok'))),
        ));
    expect(passing, isEmpty);

    // A build error is caught by the framework, not thrown from the body:
    // the wrapper leaves it for the test binding to report as usual.
    final framework = await capture(() => runWithFailureScreenshot(
          tester,
          (tester) async => tester.pumpWidget(const _Broken()),
        ));
    expect(framework, isEmpty);
    expect(tester.takeException(), isA<StateError>());
  });

  qualflareTestWidgets('qualflareTestWidgets runs the body as a widget test',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('hello')));
    expect(find.text('hello'), findsOneWidget);
  });
}
