import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_coach_app/app.dart';

void main() {
  testWidgets('App renders with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RunningCoachApp(),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('플랜'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });
}
