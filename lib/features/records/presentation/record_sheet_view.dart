import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class RecordSheetView extends ConsumerWidget {
  const RecordSheetView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordListNotifierProvider);

    return state.when(
      loading: () => const LoadingState(message: '記録を読み込み中...'),
      error: (message) => ErrorState(
        message: message,
        onRetry: () => ref.read(recordListNotifierProvider.notifier).refresh(),
      ),
      loaded: (records, hasMore, isLoadingMore) {
        if (records.isEmpty) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: '記録がありません',
            subtitle: '計測を行うとシートに表示されます',
          );
        }

        final dateFormat = DateFormat('MM/dd');
        final theme = Theme.of(context);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
              dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                final index = states.contains(WidgetState.selected) ? 0 : -1;
                return index >= 0 ? AppColors.tableStripe : null;
              }),
              columns: const [
                DataColumn(label: Text('日付', style: AppTextStyles.caption)),
                DataColumn(label: Text('選手名', style: AppTextStyles.caption)),
                DataColumn(label: Text('種目', style: AppTextStyles.caption)),
                DataColumn(
                  label: Text('タイム', style: AppTextStyles.caption),
                  numeric: true,
                ),
                DataColumn(label: Text('精度', style: AppTextStyles.caption)),
              ],
              rows: List.generate(records.length, (index) {
                final record = records[index];
                return DataRow(
                  color: WidgetStateProperty.all(
                    index.isOdd ? AppColors.tableStripe : Colors.transparent,
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
                        record.athleteName.isEmpty ? '未登録' : record.athleteName,
                        style: AppTextStyles.body,
                      ),
                    ),
                    DataCell(
                      Text(
                        record.eventType.isEmpty ? '未設定' : record.eventType,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    DataCell(
                      Text(
                        record.formattedDuration,
                        style: AppTextStyles.timeDisplaySmall.copyWith(
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
    );
  }
}
