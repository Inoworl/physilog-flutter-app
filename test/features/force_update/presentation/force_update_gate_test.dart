import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/force_update/application/force_update_providers.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings.dart';
import 'package:physi_log/features/force_update/domain/app_update_settings_repository.dart';
import 'package:physi_log/features/force_update/presentation/force_update_gate.dart';

void main() {
  testWidgets('強制アップデート中は背後のタップ操作をブロックする', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _forceUpdateApp(
        child: TextButton(
          onPressed: () => tapCount++,
          child: const Text('背後のボタン'),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(10, 10));

    expect(tapCount, 0);
  });

  testWidgets('強制アップデート中はAndroidの戻る操作をブロックする', (tester) async {
    await tester.pumpWidget(_forceUpdateApp(child: const Text('背後の画面')));
    await tester.pump();

    final popScope = tester.widget<PopScope<void>>(find.byType(PopScope<void>));
    expect(popScope.canPop, isFalse);
  });

  testWidgets('強制アップデート中はdismiss不可のModalBarrierを表示する', (tester) async {
    await tester.pumpWidget(_forceUpdateApp(child: const Text('背後の画面')));
    await tester.pump();

    final barrier = tester.widget<ModalBarrier>(
      find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color == Colors.black54,
      ),
    );
    expect(barrier.dismissible, isFalse);
  });
}

Widget _forceUpdateApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      isForceUpdateRequiredProvider.overrideWithValue(true),
      appUpdateSettingsRepositoryProvider.overrideWithValue(
        const _FakeAppUpdateSettingsRepository(),
      ),
    ],
    child: MaterialApp(
      builder: (context, routedChild) {
        return ForceUpdateGate(child: routedChild ?? const SizedBox.shrink());
      },
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

class _FakeAppUpdateSettingsRepository implements AppUpdateSettingsRepository {
  const _FakeAppUpdateSettingsRepository();

  @override
  Stream<AppUpdateSettings?> watchSettings() {
    return Stream.value(
      const AppUpdateSettings(
        title: 'アップデートが必要です',
        content: '最新版へ更新してください。',
        forceUpdate: true,
        iOSLatestVersion: '2.0.0',
        androidLatestVersion: '2.0.0',
        iOSMinRequiredVersion: '2.0.0',
        androidMinRequiredVersion: '2.0.0',
        appStoreUrl: 'https://example.com/app-store',
        googlePlayUrl: 'https://example.com/google-play',
      ),
    );
  }
}
