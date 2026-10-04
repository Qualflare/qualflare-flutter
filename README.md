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
});
```

The names match the `qualflare.*` API of Qualflare's JavaScript reporters. Calls in `setUp` and
`tearDown` apply to each test; outside a running test, and in `setUpAll`/`tearDownAll`, every call does
nothing. Attachments are capped at 5 MiB each and 20 MiB per test; anything over a cap
is dropped with a warning in the test's output.

## License

Apache-2.0
