import 'dart:convert';

/// Every marker line starts with this, trailing space included. `qf collect`
/// recognises plugin data in a test's output by it; `[v1]` versions the
/// protocol, so a parser can skip lines it does not understand.
const markerPrefix = '##qualflare[v1] ';

/// The default size of one attachment chunk, in base64 characters.
const defaultChunkSize = 48 * 1024;

/// One marker line: [markerPrefix] followed by [fields] as compact JSON, with
/// null-valued fields left out. JSON escapes newlines, and U+2028, U+2029 and
/// U+0085 (which some tools also treat as line breaks) are escaped here, so
/// the result is always a single line whatever the field values contain.
String encodeMarker(Map<String, Object?> fields) {
  final present = {
    for (final e in fields.entries)
      if (e.value != null) e.key: e.value,
  };
  // These characters can only occur inside JSON strings, where their \u
  // escapes mean the same thing.
  final json = jsonEncode(present)
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029')
      .replaceAll('\u0085', r'\u0085');
  return '$markerPrefix$json';
}

/// The `att` marker lines for one attachment: its bytes as base64, split into
/// chunks of at most [chunkSize] characters, numbered `i` of `n`. An empty
/// attachment is one chunk with empty data, so the parser still sees it.
List<String> attachmentMarkers({
  required String id,
  required String name,
  required String type,
  required List<int> bytes,
  int chunkSize = defaultChunkSize,
}) {
  final data = base64Encode(bytes);
  final n = data.isEmpty ? 1 : (data.length + chunkSize - 1) ~/ chunkSize;
  return [
    for (var i = 0; i < n; i++)
      encodeMarker({
        'k': 'att',
        'id': id,
        'name': name,
        'type': type,
        'n': n,
        'i': i,
        'data': data.substring(
          i * chunkSize,
          (i + 1) * chunkSize < data.length ? (i + 1) * chunkSize : data.length,
        ),
      }),
  ];
}
