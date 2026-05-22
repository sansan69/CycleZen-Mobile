import 'package:flutter_test/flutter_test.dart';
import 'package:cyclezen/main.dart';

void main() {
  testWidgets('CycleZen app smoke test', (WidgetTester tester) async {
    // Verify the app widget can be constructed
    expect(const CycleZenApp(), isNotNull);
  });
}
