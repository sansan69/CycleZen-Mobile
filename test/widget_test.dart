import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/main.dart';

void main() {
  testWidgets('CycleZen app smoke test', (WidgetTester tester) async {
    // Verify the app widget can be constructed
    SharedPreferences.setMockInitialValues({});
    expect(CycleZenApp(themeNotifier: ThemeModeNotifier()), isNotNull);
  });
}
