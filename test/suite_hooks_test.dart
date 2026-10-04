import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

/// Calls every API method with print captured; returns what was printed.
List<String> callAll() {
  final out = <String>[];
  runZoned(
    () {
      qualflare.label('feature', 'checkout');
      qualflare.link('https://x');
      qualflare.tags(['smoke']);
      qualflare.priority('high');
      qualflare.attachment('a', const [1]);
      unawaited(qualflare.step('s', () {}));
    },
    zoneSpecification:
        ZoneSpecification(print: (s, p, z, line) => out.add(line)),
  );
  return out;
}

void main() {
  // setUpAll and tearDownAll run as hidden pseudo-tests that qf collect does
  // not upload, so the API ignores calls there instead of losing them silently.
  late List<String> fromSetUpAll;
  setUpAll(() => fromSetUpAll = callAll());
  tearDownAll(() => expect(callAll(), isEmpty, reason: 'tearDownAll'));

  final perTest = <String>[];
  setUp(() => perTest.addAll(callAll()));

  test('setUpAll calls print nothing', () {
    expect(fromSetUpAll, isEmpty);
  });

  test('setUp calls apply to each test', () {
    expect(perTest.where((l) => l.contains('"k":"label"')),
        hasLength(greaterThanOrEqualTo(1)));
  });
}
