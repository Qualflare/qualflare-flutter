# Changelog

## 0.1.0

First release.

- Metadata API: `qualflare.label`, `link`, `tag`/`tags` and `priority`, recorded as `##qualflare[v1]`
  markers in the test's output and read by `qf` 0.3.0 or later.
- `qualflare.step`: named, nestable steps; a failing step fails the test as usual.
- `qualflare.attachment`: attach bytes with a MIME type to the running test.
- `qualflare.screenshot(tester, name)`: a PNG of the screen attached to the test, from widget tests and
  from `integration_test` runs on a device; `native: true` uses the platform's own capture on Android
  and iOS.
- `qualflareTestWidgets`: `testWidgets` that attaches `failure.png` when the body throws.
- `qualflare.loadFonts()`: opt-in real fonts for readable widget-test screenshots.
- Limits: attachments are capped at 5 MiB each and 20 MiB per test; names, values, URLs and step names
  are cut at 8192 characters without splitting surrogate pairs; an empty step name becomes `step`;
  U+2028, U+2029 and U+0085 are escaped in marker lines.
- Calls outside a running test, and in `setUpAll`/`tearDownAll`, do nothing.
