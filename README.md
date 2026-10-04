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

## License

Apache-2.0
