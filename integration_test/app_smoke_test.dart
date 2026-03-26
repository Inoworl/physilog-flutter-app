import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/app/physi_log_root.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mock差し替えでアプリを起動できる', (tester) async {
    await tester.pumpWidget(
      PhysiLogRoot(overrides: mockAppOverrides()),
    );
    await tester.pumpAndSettle();

    expect(find.text('動画計測'), findsOneWidget);
    expect(find.text('手動記録'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget);
  });
}
