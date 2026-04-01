import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_station_pay/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: GasStationPayApp()),
    );
    // App should build without throwing
    expect(find.byType(GasStationPayApp), findsOneWidget);
  });
}
