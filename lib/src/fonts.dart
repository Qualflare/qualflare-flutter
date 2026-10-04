import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:integration_test/integration_test.dart'
    show IntegrationTestWidgetsFlutterBinding;

Future<void>? _loaded;

/// Loads the app's fonts and Roboto for host widget tests, so text renders
/// as words instead of the test font's boxes. Does nothing on a device, where
/// real fonts are already used, and only loads once per process.
Future<void> loadTestFonts() {
  if (TestWidgetsFlutterBinding.ensureInitialized()
      is IntegrationTestWidgetsFlutterBinding) {
    return Future.value();
  }
  return _loaded ??= _load().catchError((Object e, StackTrace st) {
    _loaded = null; // let a later call try again
    Error.throwWithStackTrace(e, st);
  });
}

Future<void> _load() async {
  for (final family in await _manifestFamilies()) {
    final loader = FontLoader(family.name);
    for (final asset in family.assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  // Material's default font, which apps rarely bundle themselves.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final dir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final roboto = dir.listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name.startsWith('Roboto-') && name.endsWith('.ttf');
  }).toList();
  if (roboto.isEmpty) return;
  final loader = FontLoader('Roboto');
  for (final file in roboto) {
    loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

/// The families in the app's `FontManifest.json`; none if it has none.
Future<List<({String name, List<String> assets})>> _manifestFamilies() async {
  final String manifest;
  try {
    manifest = await rootBundle.loadString('FontManifest.json');
  } catch (_) {
    return const [];
  }
  return [
    for (final family in jsonDecode(manifest) as List<Object?>)
      if (family case {'family': final String name, 'fonts': final List fonts})
        (
          name: name,
          assets: [
            for (final font in fonts)
              if (font case {'asset': final String asset}) asset,
          ],
        ),
  ];
}
