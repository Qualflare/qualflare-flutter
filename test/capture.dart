import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:qualflare_flutter/src/marker.dart';

/// Runs [body] with `print` captured, returning the decoded marker lines in
/// order. Lines that are not markers are returned under the key `raw`.
Future<List<Map<String, Object?>>> capture(
    FutureOr<void> Function() body) async {
  final out = <Map<String, Object?>>[];
  await runZoned(
    () async => body(),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        out.add(
          line.startsWith(markerPrefix)
              ? jsonDecode(line.substring(markerPrefix.length))
                  as Map<String, Object?>
              : {'raw': line},
        );
      },
    ),
  );
  return out;
}

/// The attachments in [out], by name, each reassembled from its `att` chunks.
Map<String, Uint8List> attachments(List<Map<String, Object?>> out) {
  final chunks = <String, List<Map<String, Object?>>>{};
  final names = <String, String>{};
  for (final m in out.where((m) => m['k'] == 'att')) {
    final id = m['id'] as String;
    chunks.putIfAbsent(id, () => []).add(m);
    names[id] = m['name'] as String;
  }
  return {
    for (final id in chunks.keys)
      names[id]!: base64Decode(
        ((chunks[id]!..sort((a, b) => (a['i'] as int).compareTo(b['i'] as int)))
            .map((m) => m['data'] as String)).join(),
      ),
  };
}

/// The `warn` markers in [out].
List<Map<String, Object?>> warnings(List<Map<String, Object?>> out) =>
    out.where((m) => m['k'] == 'warn').toList();
