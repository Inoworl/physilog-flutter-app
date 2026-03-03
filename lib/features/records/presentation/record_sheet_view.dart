import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class RecordSheetView extends ConsumerStatefulWidget {
  const RecordSheetView({super.key});

  @override
  ConsumerState<RecordSheetView> createState() => _RecordSheetViewState();
}

class _RecordSheetViewState extends ConsumerState<RecordSheetView> {
  String? _selectedAthleteId;

  List<MeasurementRecord> _recordsForAthlete({
    required List<MeasurementRecord> records,
    required Athlete athlete,
  }) {
    return records.where((record) {
      if (record.athleteId != null && record.athleteId!.isNotEmpty) {
        return record.athleteId == athlete.id;
      }
      return record.athleteName == athlete.name;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recordState = ref.watch(recordListNotifierProvider);
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
            !athletes.any((athlete) => athlete.id == _selectedAthleteId)) {
          _selectedAthleteId = athletes.first.id;
        }

        final selectedAthlete = athletes.firstWhere(
          (athlete) => athlete.id == _selectedAthleteId,
        );

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
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
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemCount: athletes.length,
              ),
            ),
            Expanded(
              child: recordState.when(
                loading: () => const LoadingState(message: '記録を読み込み中...'),
                error: (message) => ErrorState(
                  message: message,
                  onRetry: () =>
                      ref.read(recordListNotifierProvider.notifier).refresh(),
                ),
                loaded: (records, hasMore, isLoadingMore) {
                  final targetRecords = _recordsForAthlete(
                    records: records,
                    athlete: selectedAthlete,
                  );
                  if (targetRecords.isEmpty) {
                    return EmptyState(
                      icon: Icons.table_chart_outlined,
                      title: '${selectedAthlete.name}の記録はまだありません',
                      subtitle: '計測を行うとこのシートに記録されます',
                    );
                  }

                  final dateFormat = DateFormat('MM/dd');
                  final theme = Theme.of(context);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.tableHeader,
                        ),
                        dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                          states,
                        ) {
                          final index = states.contains(WidgetState.selected)
                              ? 0
                              : -1;
                          return index >= 0 ? AppColors.tableStripe : null;
                        }),
                        columns: const [
                          DataColumn(
                            label: Text('日付', style: AppTextStyles.caption),
                          ),
                          DataColumn(
                            label: Text('選手名', style: AppTextStyles.caption),
                          ),
                          DataColumn(
                            label: Text('種目', style: AppTextStyles.caption),
                          ),
                          DataColumn(
                            label: Text('タイム', style: AppTextStyles.caption),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('精度', style: AppTextStyles.caption),
                          ),
                        ],
                        rows: List.generate(targetRecords.length, (index) {
                          final record = targetRecords[index];
                          return DataRow(
                            color: WidgetStateProperty.all(
                              index.isOdd
                                  ? AppColors.tableStripe
                                  : Colors.transparent,
                            ),
                            cells: [
                              DataCell(
                                Text(
                                  dateFormat.format(record.measuredAt),
                                  style: AppTextStyles.caption,
                                ),
                              ),
                              DataCell(
                                Text(
                                  record.athleteName.isEmpty
                                      ? '未登録'
                                      : record.athleteName,
                                  style: AppTextStyles.body,
                                ),
                              ),
                              DataCell(
                                Text(
                                  record.eventType.isEmpty
                                      ? '未設定'
                                      : record.eventType,
                                  style: AppTextStyles.caption,
                                ),
                              ),
                              DataCell(
                                Text(
                                  record.formattedDuration,
                                  style: AppTextStyles.timeDisplaySmall
                                      .copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  record.accuracyInfo ?? '-',
                                  style: AppTextStyles.accuracy,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
