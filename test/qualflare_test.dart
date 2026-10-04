import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

import 'capture.dart';

const mib = 1024 * 1024;

void main() {
  final outsideTest = <Map<String, Object?>>[];
  // Runs while the suite is being declared, outside any test's zone.
  runZoned(
    () {
      qualflare.label('owner', 'x');
      qualflare.link('https://x');
      qualflare.tag('x');
      qualflare.priority('high');
      qualflare.attachment('x', const [1]);
      qualflare.step('x', () {});
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => outsideTest.add({'raw': line}),
    ),
  );

  test('outside a test nothing is printed', () {
    expect(outsideTest, isEmpty);
  });

  test('label prints one marker', () async {
    expect(await capture(() => qualflare.label('owner', 'mobile-team')), [
      {'k': 'label', 'name': 'owner', 'value': 'mobile-team'},
    ]);
  });

  test('trims and ignores empty', () async {
    final out = await capture(() {
      qualflare.label('  owner ', ' team  ');
      qualflare.label('', 'x');
      qualflare.label('x', '   ');
      qualflare.link('   ');
      qualflare.tag(' ');
    });
    expect(out, [
      {'k': 'label', 'name': 'owner', 'value': 'team'},
    ]);
  });

  test('link defaults to custom', () async {
    expect(await capture(() => qualflare.link('https://d/1')), [
      {'k': 'link', 'type': 'custom', 'url': 'https://d/1'},
    ]);
    expect(
      await capture(
          () => qualflare.link('https://t/QF-1', type: 'issue', name: 'QF-1')),
      [
        {'k': 'link', 'type': 'issue', 'url': 'https://t/QF-1', 'name': 'QF-1'},
      ],
    );
  });

  test('rejects a bad link type with a warn', () async {
    final out = await capture(() => qualflare.link('https://x', type: 'bug'));
    expect(out, hasLength(1));
    expect(out.single['k'], 'warn');
    expect(out.single['msg'], contains('bug'));
  });

  test('rejects a bad priority with a warn', () async {
    final out = await capture(() => qualflare.priority('urgent'));
    expect(out, hasLength(1));
    expect(out.single['k'], 'warn');
    expect(out.single['msg'], contains('urgent'));
    expect(await capture(() => qualflare.priority('critical')), [
      {'k': 'priority', 'value': 'critical'},
    ]);
  });

  test('tag and tags print one marker each', () async {
    expect(await capture(() => qualflare.tag('smoke')), [
      {
        'k': 'tag',
        'tags': ['smoke']
      },
    ]);
    expect(await capture(() => qualflare.tags(['smoke', ' ', 'checkout'])), [
      {
        'k': 'tag',
        'tags': ['smoke', 'checkout']
      },
    ]);
  });

  test('step prints start and end with passed', () async {
    late int result;
    final out = await capture(() async {
      result = await qualflare.step('log in', () => 42);
    });
    expect(result, 42);
    expect(out, hasLength(2));
    expect(out[0]['k'], 'step+');
    expect(out[0]['name'], 'log in');
    expect(out[0].containsKey('parent'), isFalse);
    expect(out[1]['k'], 'step-');
    expect(out[1]['id'], out[0]['id']);
    expect(out[1]['status'], 'passed');
    expect(out[1]['t'] as int, greaterThanOrEqualTo(out[0]['t'] as int));
  });

  test('step nests across awaits', () async {
    final out = await capture(() async {
      await qualflare.step('outer', () async {
        await Future<void>.delayed(Duration.zero);
        await qualflare.step('inner', () async {
          await Future<void>.delayed(Duration.zero);
        });
      });
      await qualflare.step('after', () {});
    });
    final starts = out.where((m) => m['k'] == 'step+').toList();
    expect(starts.map((m) => m['name']), ['outer', 'inner', 'after']);
    expect(starts[1]['parent'], starts[0]['id']);
    expect(starts[2].containsKey('parent'), isFalse);
  });

  test('step ids are unique and increasing', () async {
    final out = await capture(() async {
      for (var i = 0; i < 100; i++) {
        await qualflare.step('s$i', () {});
      }
    });
    final ids =
        out.where((m) => m['k'] == 'step+').map((m) => m['id'] as int).toList();
    expect(ids, hasLength(100));
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i], greaterThan(ids[i - 1]));
    }
  });

  test('failed expect ends the step failed and rethrows TestFailure', () async {
    Object? caught;
    final out = await capture(() async {
      try {
        await qualflare.step('check', () => expect(1, 2));
      } catch (e) {
        caught = e;
      }
    });
    expect(caught, isA<TestFailure>());
    expect(out.last['k'], 'step-');
    expect(out.last['status'], 'failed');
    expect(out.last['error'], contains('Expected: <2>'));
  });

  test('step rethrows any thrown object unchanged', () async {
    Object? caught;
    StackTrace? trace;
    final out = await capture(() async {
      try {
        await qualflare.step('boom', () async {
          await Future<void>.delayed(Duration.zero);
          throw 'boom';
        });
      } catch (e, st) {
        caught = e;
        trace = st;
      }
    });
    expect(caught, same('boom'));
    expect(trace.toString(), contains('qualflare_test.dart'));
    expect(out.last['status'], 'error');
    expect(out.last['error'], 'boom');
  });

  test('attachment chunks through attachmentMarkers', () async {
    final bytes = List<int>.generate(100 * 1024, (i) => i % 251);
    final out = await capture(
      () => qualflare.attachment('data.bin', bytes,
          mimeType: 'application/octet-stream'),
    );
    expect(out, hasLength(3));
    expect(out.map((m) => m['i']), [0, 1, 2]);
    expect(out.map((m) => m['id']).toSet(), hasLength(1));
    expect(base64Decode(out.map((m) => m['data'] as String).join()), bytes);
  });

  test('caps are inclusive', () async {
    final atCap = await capture(
        () => qualflare.attachment('five', List<int>.filled(5 * mib, 0)));
    expect(atCap.every((m) => m['k'] == 'att'), isTrue);

    final over = await capture(
        () => qualflare.attachment('over', List<int>.filled(5 * mib + 1, 0)));
    expect(over, hasLength(1));
    expect(over.single['k'], 'warn');
    expect(over.single['msg'], contains('over'));
  });

  test('the per-test total is capped at 20 MiB', () async {
    final out = await capture(() {
      for (var i = 0; i < 4; i++) {
        qualflare.attachment('a$i', List<int>.filled(5 * mib, 0));
      }
      qualflare.attachment('one more', const [0]);
    });
    final warns = out.where((m) => m['k'] == 'warn').toList();
    expect(warns, hasLength(1));
    expect(warns.single['msg'], contains('one more'));
    expect(out.where((m) => m['k'] == 'att').map((m) => m['id']).toSet(),
        hasLength(4));
  });

  test('caps long names', () async {
    final long = 'x' * 10000;
    final out = await capture(() async {
      qualflare.label(long, long);
      qualflare.link('https://e/$long', name: long);
      qualflare.tag(long);
      qualflare.attachment(long, const [1]);
      await qualflare.step(long, () {});
    });
    expect(out, hasLength(6));
    expect(out[0]['name'], hasLength(8192));
    expect(out[0]['value'], hasLength(8192));
    expect(out[1]['url'], hasLength(8192));
    expect(out[1]['name'], hasLength(8192));
    expect((out[2]['tags'] as List).single, hasLength(8192));
    expect(out[3]['name'], hasLength(8192));
    expect(out[4]['name'], hasLength(8192));
  });

  test('empty step name becomes step', () async {
    final out = await capture(() => qualflare.step('  ', () {}));
    expect(out.first['k'], 'step+');
    expect(out.first['name'], 'step');
  });

  test('does not split surrogate pairs', () async {
    // 8191 'a's, then an emoji whose two UTF-16 units straddle the 8192 cap.
    final text = '${'a' * 8191}\u{1F600}b';
    final out = await capture(() async {
      qualflare.label('n', text);
      try {
        await qualflare.step('s', () => throw text);
      } catch (_) {}
    });
    expect(out[0]['value'], 'a' * 8191);
    expect(out.last['k'], 'step-');
    expect(out.last['error'], 'a' * 8191);
    // A pair that fits is kept whole.
    final fits = '${'a' * 8190}\u{1F600}b';
    final kept = await capture(() => qualflare.label('n', fits));
    expect(kept.single['value'], '${'a' * 8190}\u{1F600}');
  });

  test('step rethrows a StateError unchanged', () async {
    final error = StateError('bad state');
    Object? caught;
    final out = await capture(() async {
      try {
        await qualflare.step('s', () => throw error);
      } catch (e) {
        caught = e;
      }
    });
    expect(caught, same(error));
    expect(out.last['status'], 'error');
    expect(out.last['error'], 'Bad state: bad state');
  });

  test('step started from a Timer nests', () async {
    final out = await capture(() async {
      await qualflare.step('outer', () async {
        final done = Completer<void>();
        Timer(Duration.zero, () async {
          await qualflare.step('in timer', () {});
          done.complete();
        });
        await done.future;
      });
    });
    final starts = out.where((m) => m['k'] == 'step+').toList();
    expect(starts.map((m) => m['name']), ['outer', 'in timer']);
    expect(starts[1]['parent'], starts[0]['id']);
  });

  test('the step zone key is private', () async {
    // A zone value under any key user code can name must not look like a
    // parent step.
    final out = await capture(() => runZoned(
          () => qualflare.step('s', () {}),
          zoneValues: {#qualflareStep: 999},
        ));
    expect(out.first.containsKey('parent'), isFalse);
  });
}
