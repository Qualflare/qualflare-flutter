import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qualflare_flutter/qualflare_flutter.dart';

void main() {
  // Called before any binding exists, as from `flutter_test_config.dart`:
  // loadFonts must refuse rather than install the host test binding, which
  // would stop the integration binding below from initialising.
  Object? error;
  try {
    qualflare.loadFonts();
  } catch (e) {
    error = e;
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('loadFonts before any binding throws and installs none', () {
    expect(error, isA<StateError>());
    expect(
      (error! as StateError).message,
      'qualflare.loadFonts() must be called from setUpAll or a test, '
      'after the test binding exists',
    );
    expect(binding, isA<IntegrationTestWidgetsFlutterBinding>());
  });
}
