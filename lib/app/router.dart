import 'package:go_router/go_router.dart';
import 'package:physi_log/features/records/presentation/record_list_screen.dart';
import 'package:physi_log/features/records/presentation/record_detail_screen.dart';
import 'package:physi_log/features/records/presentation/record_edit_screen.dart';
import 'package:physi_log/features/video_import/presentation/video_import_screen.dart';
import 'package:physi_log/features/measurement/presentation/measurement_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'recordList',
      builder: (context, state) => const RecordListScreen(),
    ),
    GoRoute(
      path: '/records/:id',
      name: 'recordDetail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RecordDetailScreen(recordId: id);
      },
      routes: [
        GoRoute(
          path: 'edit',
          name: 'recordEdit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return RecordEditScreen(recordId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/import',
      name: 'videoImport',
      builder: (context, state) => const VideoImportScreen(),
    ),
    GoRoute(
      path: '/measure',
      name: 'measurement',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MeasurementScreen(
          videoPath: extra?['videoPath'] as String?,
          existingRecordId: extra?['recordId'] as String?,
        );
      },
    ),
  ],
);
