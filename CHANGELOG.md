# Changelog

## 0.1.0-dev.1 — unreleased

- `qualflare.screenshot(tester, name)`: a PNG of the screen attached to the test, from widget tests and
  from `integration_test` runs on a device (`native: true` for the platform's own capture).
- `qualflareTestWidgets`: `testWidgets` that attaches `failure.png` when the body throws.
- `qualflare.loadFonts()`: opt-in real fonts for readable widget-test screenshots.
- Names, values, URLs and step names are capped at 8192 characters without splitting surrogate pairs;
  an empty step name becomes `step`; U+2028, U+2029 and U+0085 are escaped in marker lines.
- `qualflare.label`, `link`, `tag`/`tags`, `priority`, `step` and `attachment`, recorded as
  `##qualflare[v1]` markers in the test's output.
- Package skeleton.
