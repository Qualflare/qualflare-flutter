import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart'
    show LeakTesting;
import 'package:meta/meta.dart' show isTest;

import 'qualflare.dart';

/// [testWidgets] that attaches a screenshot named `failure` when [callback]
/// throws, then fails exactly as [testWidgets] would. Takes the same
/// parameters.
///
/// The screenshot shows the screen as last painted. Errors the framework
/// catches itself (an exception during build or layout, reported after the
/// body returns) do not throw from [callback], so they get no screenshot.
@isTest
void qualflareTestWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
  LeakTesting? experimentalLeakTesting,
}) {
  testWidgets(
    description,
    (tester) => runWithFailureScreenshot(tester, callback),
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    retry: retry,
    experimentalLeakTesting: experimentalLeakTesting,
  );
}

/// Runs [callback]; if it throws, attaches a `failure` screenshot and
/// rethrows the same error with its stack trace.
Future<void> runWithFailureScreenshot(
  WidgetTester tester,
  WidgetTesterCallback callback,
) async {
  try {
    await callback(tester);
  } catch (_) {
    await qualflare.screenshot(tester, 'failure');
    rethrow;
  }
}
