import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:city_guide/main.dart';
import 'package:city_guide/store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('password rules and strength score', () {
    expect(passwordIssues('weak'), isNotEmpty);
    expect(passwordIssues('Good@Pass1'), isEmpty);
    expect(passwordScore('Good@Pass1'), greaterThanOrEqualTo(3));
  });

  testWidgets('shows login screen when logged out', (tester) async {
    final state = await AppState.load(connect: false);
    await tester.pumpWidget(CityGuideApp(state: state));
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
