# qualflare_flutter example

A small checkout screen (cart total, promo code, pay button) with tests that use every part of
`qualflare_flutter`: labels, a link, tags, priority, nested steps, a JSON attachment, screenshots
(including a native one on a device), a retried test and a failing test.

- `test/checkout_widget_test.dart` runs on the host as a widget test.
- `integration_test/checkout_test.dart` runs on an emulator, simulator or device.

## Run it

```bash
flutter pub get

# Widget tests, on the host
flutter test test/checkout_widget_test.dart --file-reporter json:results.json

# Integration test, on a connected device or emulator
flutter test integration_test/checkout_test.dart -d <device> --file-reporter json:results.json
```

Some tests fail on purpose, so `flutter test` exits non-zero. To upload the results with the `qf` CLI
(0.3.0 or later):

```bash
qf <project> collect results.json                      # widget tests
qf <project> collect results.json --platform android   # or ios, for integration_test
```

## In CI

`.github/workflows/ci.yml` in the repository runs the example on the host, on an Android emulator and
on an iOS simulator. Each run writes a JSON results file, and `tool/assert_markers.sh` checks that the
markers of every kind landed on the right test (for the device runs, also that the native screenshot
arrived). The results files are kept as workflow artifacts.

On pushes to `main`, the Android and iOS jobs also run the example a second time with
`--exclude-tags demo-failure` and upload that run with `qf` 0.3.0 (`--platform android` or `ios`) to the
public project at
[reports.qualflare.com/p/qualflare-flutter](https://reports.qualflare.com/p/qualflare-flutter/launches).
`tool/assert-launch-landed.py` then checks that a new launch appeared. The test that fails on purpose
carries the `demo-failure` tag (declared in `dart_test.yaml`), so the uploaded launches contain only
passing and retried tests.
