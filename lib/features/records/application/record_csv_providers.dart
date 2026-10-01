import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../data/record_csv_sharer.dart';
import 'record_csv_export_service.dart';

final recordCsvExportServiceProvider = Provider<RecordCsvExportService>(
  (ref) => RecordCsvExportService(
    repository: ref.watch(recordRepositoryProvider),
    currentUserId: () => ref.read(currentUserIdProvider),
    currentPlan: () => ref.read(planAccessStateProvider),
  ),
);

final recordCsvSharerProvider = Provider<RecordCsvSharer>(
  (ref) => RecordCsvSharer(),
);
