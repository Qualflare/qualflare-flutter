import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart' show WidgetTester, captureImage;
import 'package:integration_test/integration_test.dart'
    show IntegrationTestWidgetsFlutterBinding;

/// Whether the Android Flutter surface has been converted to an image view,
/// which the native capture needs; done once per process.
bool _androidSurfaceConverted = false;

/// The current screen as PNG bytes. Never pumps or settles: it captures what
/// was last painted.
///
/// By default the root layer is rendered. With [native] on an
/// `integration_test` binding the platform captures the screen instead, which
/// includes platform views; elsewhere [native] is ignored.
///
/// Throws if the capture fails.
Future<List<int>> captureScreenshot(
  WidgetTester tester,
  String name, {
  required bool native,
}) async {
  // runAsync reports an error thrown by its callback as a test failure, so
  // the callback returns its error instead of throwing it.
  final result = await tester.runAsync<(List<int>?, Object?, StackTrace?)>(
    () async {
      try {
        final binding = tester.binding;
        if (native && binding is IntegrationTestWidgetsFlutterBinding) {
          return (await _native(binding, name), null, null);
        }
        return (await _rootLayer(tester), null, null);
      } catch (e, st) {
        return (null, e, st);
      }
    },
  );
  if (result == null) throw StateError('the capture did not complete');
  final (bytes, error, stack) = result;
  if (error != null) Error.throwWithStackTrace(error, stack!);
  return bytes!;
}

Future<List<int>> _native(
    IntegrationTestWidgetsFlutterBinding binding, String name) async {
  if (!kIsWeb && Platform.isAndroid && !_androidSurfaceConverted) {
    await binding.convertFlutterSurfaceToImage();
    _androidSurfaceConverted = true;
  }
  return binding.takeScreenshot(name);
}

Future<List<int>> _rootLayer(WidgetTester tester) async {
  final root = tester.binding.rootElement;
  if (root == null) throw StateError('nothing has been pumped yet');
  final image = await captureImage(root);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('the screen could not be encoded as PNG');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    image.dispose();
  }
}
