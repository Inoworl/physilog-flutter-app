import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/application/athlete_sheet.dart';
import 'package:physi_log/features/records/application/daily_records_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

/// 選手シート用に全記録を取得する。日別ビューと同じく全件を読む。
final _allRecordsProvider = FutureProvider.autoDispose<List<MeasurementRecord>>(
  (ref) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const <MeasurementRecord>[];
    return ref.watch(recordRepositoryProvider).getAllRecords(userId: userId);
  },
);

/// 記録ページの「シート」ビュー。選手を1人選ぶと、その選手の記録を
/// 行=計測日・列=種目 の表で表示する。セルをタップで編集・削除。
class RecordSheetView extends ConsumerStatefulWidget {
  const RecordSheetView({super.key, this.initialAthleteId});

  final String? initialAthleteId;

  @override
  ConsumerState<RecordSheetView> createState() => _RecordSheetViewState();
}

class _RecordSheetViewState extends ConsumerState<RecordSheetView> {
  late String? _selectedAthleteId;

  @override
  void initState() {
    super.initState();
    _selectedAthleteId = widget.initialAthleteId;
  }

  @override
  void didUpdateWidget(covariant RecordSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAthleteId != oldWidget.initialAthleteId) {
      _selectedAthleteId = widget.initialAthleteId;
    }
  }

  List<MeasurementRecord> _recordsForAthlete(
    List<MeasurementRecord> records,
    Athlete athlete,
  ) {
    return records.where((record) {
      if (record.athleteId != null && record.athleteId!.isNotEmpty) {
        return record.athleteId == athlete.id;
      }
      return record.athleteName == athlete.name;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final athleteState = ref.watch(athleteListNotifierProvider);

    return athleteState.when(
      loading: () => const LoadingState(message: '選手データを読み込み中...'),
      error: (message) => ErrorState(
        message: message,
        onRetry: () => ref.read(athleteListNotifierProvider.notifier).refresh(),
      ),
      loaded: (athletes) {
        if (athletes.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_2_outlined,
            title: '選手が登録されていません',
            subtitle: '管理タブから選手を追加すると記録シートが作成されます',
          );
        }

        if (_selectedAthleteId == null ||
            !athletes.any((a) => a.id == _selectedAthleteId)) {
          _selectedAthleteId = athletes.first.id;
        }
        final selectedAthlete = athletes.firstWhere(
          (a) => a.id == _selectedAthleteId,
        );

        return Column(
          children: [
            _buildAthleteChips(athletes),
            Expanded(child: _buildSheet(selectedAthlete)),
          ],
        );
      },
    );
  }

  Widget _buildAthleteChips(List<Athlete> athletes) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: athletes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final athlete = athletes[index];
          return ChoiceChip(
            label: Text(athlete.name),
            selected: athlete.id == _selectedAthleteId,
            onSelected: (_) {
              setState(() => _selectedAthleteId = athlete.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildSheet(Athlete athlete) {
    final recordsAsync = ref.watch(_allRecordsProvider);
    final events = ref
        .watch(eventListNotifierProvider)
        .maybeWhen(loaded: (events) => events, orElse: () => const <Event>[]);

    return recordsAsync.when(
      loading: () => const LoadingState(message: '記録を読み込み中...'),
      error: (error, _) => ErrorState(
        message: '記録の読み込みに失敗しました',
        onRetry: () => ref.invalidate(_allRecordsProvider),
      ),
      data: (allRecords) {
        final records = _recordsForAthlete(allRecords, athlete);
        if (records.isEmpty) {
          return EmptyState(
            icon: Icons.table_chart_outlined,
            title: '${athlete.name}の記録はまだありません',
            subtitle: '計測を行うとこのシートに記録されます',
          );
        }

        final sheet = buildAthleteSheet(records: records, events: events);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(sheet),
          ),
        );
      },
    );
  }

  Widget _buildTable(AthleteSheet sheet) {
    final dateFormat = DateFormat('M/d');
    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
      columns: [
        const DataColumn(label: Text('日付', style: AppTextStyles.caption)),
        for (final column in sheet.columns)
          DataColumn(
            label: Text(column.name, style: AppTextStyles.caption),
            numeric: true,
          ),
      ],
      rows: [
        for (final row in sheet.rows)
          DataRow(
            cells: [
              DataCell(
                Text(dateFormat.format(row.date), style: AppTextStyles.body),
              ),
              for (final column in sheet.columns)
                _buildDataCell(row.cells[column.key], row.date, column),
            ],
          ),
      ],
    );
  }

  DataCell _buildDataCell(
    DailyCell? cell,
    DateTime date,
    DailyEventColumn column,
  ) {
    if (cell == null) {
      return const DataCell(Text('―', style: AppTextStyles.caption));
    }
    final style = AppTextStyles.body.copyWith(
      color: cell.isPersonalBest ? AppColors.success : null,
      fontWeight: cell.isPersonalBest ? FontWeight.bold : null,
    );
    return DataCell(
      Text(cell.displayText, style: style),
      onTap: () => _onCellTap(cell, date, column.name),
    );
  }

  Future<void> _onCellTap(
    DailyCell cell,
    DateTime date,
    String eventName,
  ) async {
    final dateText = DateFormat('M/d').format(date);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('$dateText ・ $eventName'),
              subtitle: Text(cell.displayText),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('削除', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'edit') {
      await context.pushNamed(
        'recordEdit',
        pathParameters: {'id': cell.recordId},
      );
      if (mounted) ref.invalidate(_allRecordsProvider);
      return;
    }
    final confirmed = await DeleteConfirmationDialog.show(context, eventName);
    if (confirmed == true && mounted) {
      await ref
          .read(recordListNotifierProvider.notifier)
          .deleteRecord(cell.recordId);
      ref.invalidate(_allRecordsProvider);
    }
  }
}
