# qualflare_flutter

Labels, links, steps and screenshots for Flutter widget and `integration_test` tests, reported to
[Qualflare](https://qualflare.com/flutter-test-reporting/).

> **Status: pre-release.** The API is being built; the first release is 0.1.0.

Flutter results already reach Qualflare without this package:

```bash
flutter test --file-reporter json:flutter-results.json
qf <project> collect flutter-results.json
```

`qf collect` reads statuses, durations, failure messages, retries and output from that file. This
package adds what only the test author knows — labels, links, tags, priority, named steps and
screenshots — for widget tests and for tests on a real device or emulator. Its data travels inside the
same results file, so the two commands stay the same. Reading it needs `qf` 0.3.0 or later (coming with
this package's 0.1.0).

## API

```dart
import 'package:qualflare_flutter/qualflare_flutter.dart';

testWidgets('pays with a card', (tester) async {
  qualflare.label('owner', 'mobile-team');            // any name/value
  qualflare.link('https://tracker/QF-1', type: 'issue', name: 'QF-1'); // issue | tms | custom
  qualflare.tags(['checkout', 'smoke']);
  qualflare.priority('high');                          // low | medium | high | critical
  await qualflare.step('fill in the card', () async {
    // … steps nest, and a failing step fails the test as usual
  });
  qualflare.attachment('response.json', bytes, mimeType: 'application/json');
  await qualflare.screenshot(tester, 'checkout');      // checkout.png on this test
});

qualflareTestWidgets('pays with a card', (tester) async {
  // testWidgets, plus a screenshot named failure.png when the body throws
});
```

The names match the `qualflare.*` API of Qualflare's JavaScript reporters. Calls in `setUp` and
`tearDown` apply to each test; outside a running test, and in `setUpAll`/`tearDownAll`, every call does
nothing. Attachments are capped at 5 MiB each and 20 MiB per test; anything over a cap
is dropped with a warning in the test's output. Names, values, URLs and step names longer than 8192
characters are cut.

## Screenshots

`qualflare.screenshot(tester, name)` attaches a PNG of the screen. It never settles, so it works
mid-animation; only while the screen has changes not yet painted does it pump a frame (a few at
most). It renders Flutter's
root layer, the same way in widget tests and in `integration_test` runs on a device or emulator. In an
`integration_test` run on Android or iOS, `native: true` lets the platform capture the screen instead, which also shows
platform views (maps, web views) and, on Android, the status bar; the first native capture on Android
switches Flutter to an image surface and pumps one frame, as `integration_test` requires. A capture
that fails records a warning; it never fails the test.

`qualflareTestWidgets` takes the same arguments as `testWidgets`. When its body throws (a failed
`expect`, a missing widget), it attaches `failure.png` and rethrows, so the test fails exactly as
before. Errors Flutter catches itself, such as an exception during build, are reported after the body
returns and get no screenshot. Plain `testWidgets` tests can call `qualflare.screenshot` themselves.

Screenshots travel as base64 lines in the test's output, so they also show up in the console output of
`flutter test`.

### Readable text in widget-test screenshots

Host widget tests draw every glyph as a box (the test font). To render real text, load fonts once per
test file:

```dart
setUpAll(() => qualflare.loadFonts());
```

`loadFonts` loads the fonts in your app's `FontManifest.json` and Roboto (Material's default) from the
Flutter SDK. It changes text sizes for the rest of the file, which can affect layout and golden tests,
so it is opt-in. Inside a `testWidgets` body, call it through `tester.runAsync`. It needs the test
binding to exist already, so call it from `setUpAll` or a test, not from `main` or
`flutter_test_config.dart`; there it throws a `StateError` rather than install a binding. It does nothing on a
device, where real fonts are used already, and nothing when called again.

## License

Apache-2.0
