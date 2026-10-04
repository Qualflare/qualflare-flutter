import 'dart:async';

import 'package:flutter_test/flutter_test.dart' show TestFailure, WidgetTester;
import 'package:test_api/hooks.dart' show OutsideTestException, TestHandle;

import 'fonts.dart';
import 'marker.dart';
import 'screenshot.dart';

/// Largest single attachment, in decoded bytes; at the cap is allowed.
const maxAttachmentBytes = 5 * 1024 * 1024;

/// Largest total of attachment bytes for one test (all attempts together).
const maxTestAttachmentBytes = 20 * 1024 * 1024;

/// Longest name, value, URL or step error message kept, in UTF-16 code
/// units; longer ones are cut, never inside a surrogate pair.
const maxTextLength = 8192;

const _linkTypes = {'issue', 'tms', 'custom'};
const _priorities = {'low', 'medium', 'high', 'critical'};

/// The zone key holding the id of the step whose body is running. An object
/// no other code can name, so no other zone value can pass for a step.
final _stepZoneKey = Object();

/// The Qualflare runtime API for Flutter tests.
///
/// Each call prints one `##qualflare[v1]` marker line from inside the running
/// test, which Dart's JSON reporter records as that test's output and
/// `qf collect` turns into the case's labels, links, tags, priority, steps and
/// attachments. Outside a running test every call does nothing.
final qualflare = Qualflare._();

/// See [qualflare].
class Qualflare {
  Qualflare._();

  int _nextStepId = 0;
  int _nextAttachmentId = 0;
  final Map<String, int> _bytesPerTest = {};

  /// Arbitrary name/value metadata (owner, epic, feature, story …).
  void label(String name, String value) {
    final n = _text(name), v = _text(value);
    if (n.isEmpty || v.isEmpty || !_inTest) return;
    _emit({'k': 'label', 'name': n, 'value': v});
  }

  /// A link to an issue, a test-management case or any other URL. [type] is
  /// `issue`, `tms` or `custom`.
  void link(String url, {String type = 'custom', String? name}) {
    final u = _text(url);
    if (u.isEmpty || !_inTest) return;
    if (!_linkTypes.contains(type)) {
      _warn(
          'link type "$type" is not one of issue, tms, custom; link $u ignored');
      return;
    }
    final n = name == null ? null : _text(name);
    _emit({
      'k': 'link',
      'type': type,
      'url': u,
      'name': (n == null || n.isEmpty) ? null : n
    });
  }

  /// One case tag.
  void tag(String tag) => tags([tag]);

  /// Several case tags at once.
  void tags(List<String> tags) {
    final kept = [
      for (final t in tags)
        if (_text(t).isNotEmpty) _text(t),
    ];
    if (kept.isEmpty || !_inTest) return;
    _emit({'k': 'tag', 'tags': kept});
  }

  /// The case priority: `low`, `medium`, `high` or `critical`.
  void priority(String value) {
    if (!_inTest) return;
    final v = value.trim();
    if (!_priorities.contains(v)) {
      _warn(
          'priority "$value" is not one of low, medium, high, critical; ignored');
      return;
    }
    _emit({'k': 'priority', 'value': v});
  }

  /// Runs [body] as a named step and returns its result. Steps nest: a step
  /// started inside another's body is its child, across `await`s too. If
  /// [body] throws, the step ends `failed` (a [TestFailure]) or `error`
  /// (anything else) and the same object is rethrown with its stack trace.
  Future<T> step<T>(String name, FutureOr<T> Function() body) async {
    if (!_inTest) return body();
    final id = ++_nextStepId;
    _emit({
      'k': 'step+',
      'id': id,
      'parent': Zone.current[_stepZoneKey] as int?,
      'name': _text(name).isEmpty ? 'step' : _text(name),
      't': _now(),
    });
    try {
      final result =
          await runZoned(() async => body(), zoneValues: {_stepZoneKey: id});
      _emit({'k': 'step-', 'id': id, 'status': 'passed', 't': _now()});
      return result;
    } catch (e) {
      _emit({
        'k': 'step-',
        'id': id,
        'status': e is TestFailure ? 'failed' : 'error',
        't': _now(),
        'error': _cap('$e'),
      });
      rethrow;
    }
  }

  /// Attaches [bytes] to the current test under [name]. Over
  /// [maxAttachmentBytes], or past [maxTestAttachmentBytes] for the test, the
  /// attachment is dropped and a warning is recorded instead.
  void attachment(String name, List<int> bytes,
      {String mimeType = 'application/octet-stream'}) {
    final test = _testName;
    if (test == null) return;
    final n = _text(name).isEmpty ? 'attachment' : _text(name);
    if (bytes.length > maxAttachmentBytes) {
      _warn(
          'attachment "$n" is ${bytes.length} bytes, over the $maxAttachmentBytes-byte cap; dropped');
      return;
    }
    final total = (_bytesPerTest[test] ?? 0) + bytes.length;
    if (total > maxTestAttachmentBytes) {
      _warn(
          'attachment "$n" would take this test past $maxTestAttachmentBytes bytes of attachments; dropped');
      return;
    }
    _bytesPerTest[test] = total;
    final lines = attachmentMarkers(
        id: 'a${++_nextAttachmentId}', name: n, type: mimeType, bytes: bytes);
    for (final line in lines) {
      print(line); // ignore: avoid_print
    }
  }

  /// Attaches a PNG of the screen to the current test as `<name>.png`.
  ///
  /// Never settles, so it works mid-animation. Only while the screen has
  /// changes not yet painted it pumps a frame (a few at most), so the capture
  /// shows them. By default Flutter's root
  /// layer is rendered. With [native] in an `integration_test` run on Android
  /// or iOS the platform captures the screen instead, which includes platform
  /// views (maps, web views) and, on Android, the status bar; elsewhere
  /// (widget tests, desktop, web) [native] is ignored. The first native capture on Android converts the
  /// Flutter surface to an image and pumps one frame, as `integration_test`
  /// requires.
  ///
  /// A failed capture records a warning instead; it never fails the test.
  /// Attachment caps apply.
  Future<void> screenshot(WidgetTester tester, String name,
      {bool native = false}) async {
    if (!_inTest) return;
    final n = _text(name).isEmpty ? 'screenshot' : _text(name);
    final List<int> png;
    try {
      png = await captureScreenshot(tester, n, native: native);
    } catch (e) {
      _warn(_cap('screenshot "$n" failed: $e'));
      return;
    }
    attachment('$n.png', png, mimeType: 'image/png');
  }

  /// Loads the app's fonts (from its `FontManifest.json`) and Roboto, so
  /// screenshots in host widget tests show words instead of the test font's
  /// boxes.
  ///
  /// Opt-in, because it changes text metrics for the rest of the test file:
  /// call it in `setUpAll` or, inside a `testWidgets` body, through
  /// `tester.runAsync`. Calling it again does nothing; on a device, where
  /// real fonts are already used, it does nothing.
  ///
  /// It never installs a test binding, so an `integration_test` binding can
  /// still be initialised after it. Called before any binding exists (from
  /// `main` or `flutter_test_config.dart`), it throws a [StateError].
  Future<void> loadFonts() => loadTestFonts();

  /// The running test's full name, or null outside a test.
  ///
  /// `setUpAll` and `tearDownAll` run as hidden pseudo-tests named
  /// `… (setUpAll)` / `… (tearDownAll)`. Results tools drop hidden tests, so
  /// anything recorded there would vanish; they count as outside a test.
  /// `setUp` and `tearDown` run inside each test and apply to it.
  String? get _testName {
    final String name;
    try {
      name = TestHandle.current.name;
    } on OutsideTestException {
      return null;
    }
    if (name.endsWith('(setUpAll)') || name.endsWith('(tearDownAll)')) {
      return null;
    }
    return name;
  }

  bool get _inTest => _testName != null;

  void _warn(String msg) => _emit({'k': 'warn', 'msg': msg});

  // Markers are printed from the caller's zone, which is the running test's:
  // Dart's JSON reporter records the line as that test's output.
  void _emit(Map<String, Object?> fields) =>
      print(encodeMarker(fields)); // ignore: avoid_print

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// [s] trimmed and capped at [maxTextLength].
  static String _text(String s) => _cap(s.trim());

  /// [s] cut to at most [maxTextLength] code units, keeping surrogate pairs
  /// whole.
  static String _cap(String s) {
    if (s.length <= maxTextLength) return s;
    var end = maxTextLength;
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--; // a pair's first half
    return s.substring(0, end);
  }
}
