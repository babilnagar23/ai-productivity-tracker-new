// Basic smoke test for Productivity Tracker app
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productive_ai/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: ProductivityAIApp(),
    ));
    await tester.pump();
    // App should render without throwing
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
