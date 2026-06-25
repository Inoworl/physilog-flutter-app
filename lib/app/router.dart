import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/home/presentation/home_screen.dart';
import 'package:physi_log/features/manage/presentation/manage_screen.dart';
import 'package:physi_log/features/measurement/presentation/measurement_screen.dart';
import 'package:physi_log/features/records/presentation/record_detail_screen.dart';
import 'package:physi_log/features/records/presentation/record_edit_screen.dart';
import 'package:physi_log/features/records/presentation/records_tab_screen.dart';
import 'package:physi_log/features/settings/presentation/settings_screen.dart';
import 'package:physi_log/features/settings/presentation/settings_web_view_screen.dart';
import 'package:physi_log/features/video_import/presentation/video_import_screen.dart';
import 'package:physi_log/shared/widgets/app_bottom_nav_shell.dart';

const _defaultSettingsHelpUrl = String.fromEnvironment(
  'DOCS_BASE_URL',
  defaultValue: 'https://physilog-dev.web.app',
);

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 右からスライドインするトランジション
Widget _slideFromRight(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
    child: child,
  );
}

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppBottomNavShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: ホーム
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Branch 1: 記録
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/records',
              name: 'recordList',
              builder: (context, state) {
                final view = state.uri.queryParameters['view'];
                final initialViewMode = view == 'sheet'
                    ? RecordsViewMode.sheet
                    : RecordsViewMode.daily;

                return RecordsTabScreen(
                  initialViewMode: initialViewMode,
                  initialAthleteId: state.uri.queryParameters['athleteId'],
                );
              },
            ),
          ],
        ),
        // Branch 2: 管理
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/manage',
              name: 'manage',
              builder: (context, state) => const ManageScreen(),
            ),
          ],
        ),
      ],
    ),
    // タブ外のルート（フルスクリーン遷移・スライドアニメーション）
    GoRoute(
      path: '/import',
      name: 'videoImport',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const VideoImportScreen(),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/measure',
      name: 'measurement',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: MeasurementScreen(
            videoPath: extra?['videoPath'] as String?,
            existingRecordId: extra?['recordId'] as String?,
          ),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/settings/account/:mode',
      name: 'settingsAccountAuth',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final mode = accountEmailAuthModeFromRoute(
          state.pathParameters['mode'],
        );
        return CustomTransitionPage(
          key: state.pageKey,
          child: AccountEmailAuthScreen(
            mode: mode ?? AccountEmailAuthMode.register,
          ),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/settings/help',
      name: 'settingsHelp',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: SettingsWebViewScreen(
            title: state.uri.queryParameters['title'] ?? 'ヘルプ',
            url: state.uri.queryParameters['url'] ?? _defaultSettingsHelpUrl,
          ),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
    GoRoute(
      path: '/records/:id',
      name: 'recordDetail',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: RecordDetailScreen(recordId: id),
          transitionsBuilder: _slideFromRight,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
      },
      routes: [
        GoRoute(
          path: 'edit',
          name: 'recordEdit',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return CustomTransitionPage(
              key: state.pageKey,
              child: RecordEditScreen(recordId: id),
              transitionsBuilder: _slideFromRight,
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
            );
          },
        ),
      ],
    ),
  ],
);
