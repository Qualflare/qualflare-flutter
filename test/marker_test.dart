import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/src/marker.dart';

Map<String, Object?> decode(String line) {
  expect(line.startsWith(markerPrefix), isTrue, reason: line);
  return jsonDecode(line.substring(markerPrefix.length))
      as Map<String, Object?>;
}

void main() {
  test('encodes a label exactly', () {
    expect(
      encodeMarker({'k': 'label', 'name': 'owner', 'value': 'mobile'}),
      '##qualflare[v1] {"k":"label","name":"owner","value":"mobile"}',
    );
  });

  test('drops null fields', () {
    final line =
        encodeMarker({'k': 'link', 'type': 'custom', 'url': 'u', 'name': null});
    expect(line, isNot(contains('"name"')));
    expect(decode(line), {'k': 'link', 'type': 'custom', 'url': 'u'});
  });

  test('encodes newlines and unicode on one line', () {
    final line = encodeMarker({'k': 'label', 'name': 'n', 'value': 'a\nb ✓'});
    expect(line, isNot(contains('\n')));
    expect(decode(line)['value'], 'a\nb ✓');
  });

  test('chunks an attachment', () {
    final bytes = List<int>.generate(100 * 1024, (i) => i % 256);
    final lines = attachmentMarkers(
      id: 'a1',
      name: 'shot.png',
      type: 'image/png',
      bytes: bytes,
      chunkSize: 48 * 1024,
    );
    expect(lines, hasLength(3));
    final parts = lines.map(decode).toList();
    for (var i = 0; i < parts.length; i++) {
      expect(parts[i]['k'], 'att');
      expect(parts[i]['id'], 'a1');
      expect(parts[i]['name'], 'shot.png');
      expect(parts[i]['type'], 'image/png');
      expect(parts[i]['n'], 3);
      expect(parts[i]['i'], i);
      expect((parts[i]['data'] as String).length, lessThanOrEqualTo(49152));
    }
    expect(base64Decode(parts.map((p) => p['data'] as String).join()), bytes);
  });

  test('empty attachment is one chunk', () {
    final lines = attachmentMarkers(
        id: 'a2', name: 'e', type: 'text/plain', bytes: const []);
    expect(lines, hasLength(1));
    expect(decode(lines.single), containsPair('n', 1));
    expect(decode(lines.single), containsPair('data', ''));
  });

  test('escapes line separators', () {
    const value = 'a\u2028b\u2029c\u0085d';
    final line = encodeMarker({'k': 'label', 'name': 'n', 'value': value});
    expect(line, isNot(contains('\u2028')));
    expect(line, isNot(contains('\u2029')));
    expect(line, isNot(contains('\u0085')));
    expect(line, contains(r'a\u2028b\u2029c\u0085d'));
    expect(decode(line)['value'], value);
  });
}
