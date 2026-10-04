import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart' show WidgetTester, captureImage;
import 'package:integration_test/integration_test.dart'
    show IntegrationTestWidgetsFlutterBinding;

/// Whether the Android Flutter surface has been converted to an image view,
/// which the native capture needs; done once per process.
bool _androidSurfaceConverted = false;

/// The most frames a capture pumps to get unpainted changes on screen.
///
/// One frame paints a normal change. On a device (live) binding the pointer
/// trail drawn after a tap repaints the screen for two more frames, each
/// marking it unpainted again, so a capture right after a `tap` needs
/// up to three. The bound keeps a screen that never stops repainting from
/// holding the capture; it then fails with a warning instead.
const _maxPaintFrames = 5;

/// Whether this runs on Android or iOS, the platforms `integration_test` can
/// capture natively.
bool get _onDevice => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// The current screen as PNG bytes. Never settles. Only while the screen has
/// changes not yet painted (on a device nothing paints between test code and
/// the capture) it pumps a frame, at most [_maxPaintFrames], so what it
/// captures is current.
///
/// By default the root layer is rendered. With [native] on an
/// `integration_test` binding on Android or iOS the platform captures the
/// screen instead, which includes platform views; elsewhere (widget tests,
/// desktop and web) [native] is ignored. On Android the
/// first native capture also converts the Flutter surface to an image view
/// and pumps one frame so the new surface has something to show, as
/// `integration_test` requires.
///
/// Throws if the capture fails.
Future<List<int>> captureScreenshot(
  WidgetTester tester,
  String name, {
  required bool native,
}) async {
  final binding = tester.binding;
  final useNative =
      native && binding is IntegrationTestWidgetsFlutterBinding && _onDevice;
  if (useNative && Platform.isAndroid && !_androidSurfaceConverted) {
    await binding.convertFlutterSurfaceToImage();
    _androidSurfaceConverted = true;
    await tester.pump();
  }
  for (var i = 0; i < _maxPaintFrames && _needsPaint(tester); i++) {
    await tester.pump();
  }
  // runAsync reports an error thrown by its callback as a test failure, so
  // the callback returns its error instead of throwing it.
  final result = await tester.runAsync<(List<int>?, Object?, StackTrace?)>(
    () async {
      try {
        if (useNative) {
          return (await binding.takeScreenshot(name), null, null);
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

/// Whether the repaint boundary that the root-layer capture renders has
/// changes not yet painted. Only known when asserts are on (debug and test
/// builds); without asserts the capture does not check it either.
bool _needsPaint(WidgetTester tester) {
  var renderObject = tester.binding.rootElement?.renderObject;
  if (renderObject == null) return false;
  while (!renderObject!.isRepaintBoundary) {
    renderObject = renderObject.parent;
    if (renderObject == null) return false;
  }
  var needsPaint = false;
  assert(() {
    needsPaint = renderObject!.debugNeedsPaint;
    return true;
  }());
  return needsPaint;
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
