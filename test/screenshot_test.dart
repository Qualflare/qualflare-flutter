import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

import 'capture.dart';

/// Fails loudly if `screenshot` touches the tester when it should not.
class _UntouchableTester implements WidgetTester {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('tester used: ${invocation.memberName}');
}

/// Decodes [png] and returns its size and the colour of its centre pixel.
Future<(int, int, Color)> decodePng(WidgetTester tester, Uint8List png) async {
  final result = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData())!;
    final at = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
    final centre = Color.fromARGB(rgba.getUint8(at + 3), rgba.getUint8(at),
        rgba.getUint8(at + 1), rgba.getUint8(at + 2));
    final size = (image.width, image.height, centre);
    image.dispose();
    codec.dispose();
    return size;
  });
  return result!;
}

void main() {
  final outsideTest = <Map<String, Object?>>[];
  Object? outsideError;
  // Runs while the suite is being declared, outside any test.
  runZoned(
    () {
      qualflare
          .screenshot(_UntouchableTester(), 'outside')
          .catchError((Object e) => outsideError = e);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => outsideTest.add({'raw': line}),
    ),
  );

  testWidgets('screenshot attaches a decodable PNG', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ColoredBox(color: Color(0xFF009688))));
    final out = await capture(() => qualflare.screenshot(tester, 'home'));
    expect(warnings(out), isEmpty);
    expect(out.every((m) => m['type'] == 'image/png'), isTrue);
    final shots = attachments(out);
    expect(shots.keys, ['home.png']);
    final (width, height, centre) = await decodePng(tester, shots['home.png']!);
    expect(width, greaterThan(0));
    expect(height, greaterThan(0));
    expect(centre, const Color(0xFF009688));
  });

  testWidgets('screenshot does not pump or settle', (tester) async {
    // An endless animation: pumpAndSettle would never settle.
    await tester.pumpWidget(
        const MaterialApp(home: Center(child: CircularProgressIndicator())));
    var framed = false;
    tester.binding.addPostFrameCallback((_) => framed = true);
    final out = await capture(() => qualflare.screenshot(tester, 'spinning'));
    expect(framed, isFalse, reason: 'screenshot pumped a frame');
    expect(warnings(out), isEmpty);
    expect(attachments(out).keys, ['spinning.png']);
  });

  test('screenshot outside a test does nothing', () {
    expect(outsideError, isNull);
    expect(outsideTest, isEmpty);
  });

  testWidgets('native on the host falls back to the root layer',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ColoredBox(color: Color(0xFFFF0000))));
    final out = await capture(
        () => qualflare.screenshot(tester, 'native', native: true));
    expect(warnings(out), isEmpty);
    final shots = attachments(out);
    expect(shots.keys, ['native.png']);
    final (_, _, centre) = await decodePng(tester, shots['native.png']!);
    expect(centre, const Color(0xFFFF0000));
  });

  testWidgets('a capture error becomes a warn', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    late List<Map<String, Object?>> out;
    // runAsync cannot be re-entered, so capturing from inside it fails.
    await tester.runAsync(() async {
      out = await capture(() => qualflare.screenshot(tester, 'nested'));
    });
    expect(attachments(out), isEmpty);
    expect(warnings(out), hasLength(1));
    expect(warnings(out).single['msg'], contains('nested'));
  });

  testWidgets('screenshot names default and are trimmed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final out = await capture(() async {
      await qualflare.screenshot(tester, '  ');
      await qualflare.screenshot(tester, ' cart ');
    });
    expect(attachments(out).keys, ['screenshot.png', 'cart.png']);
  });
}
