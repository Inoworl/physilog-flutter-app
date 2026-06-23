import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/records/application/daily_records_notifier.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

/// 記録ページの「日別」ビュー。最新の計測会を1つだけ表示し、
/// 日付ナビで前後の計測会へ移動できる。下に種目別ランキングを出す。
class DailySheetView extends ConsumerStatefulWidget {
  const DailySheetView({super.key});

  @override
  ConsumerState<DailySheetView> createState() => _DailySheetViewState();
}

class _DailySheetViewState extends ConsumerState<DailySheetView> {
  final DateFormat _dateFormat = DateFormat('M/d');

  /// ランキングを非表示にしている種目key。
  final Set<String> _hiddenRankingKeys = {};

  Future<void> _refresh() {
    return ref.read(dailyRecordsNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyRecordsNotifierProvider);

    return state.when(
      loading: () => const LoadingState(message: '記録を読み込み中...'),
      error: (message) => ErrorState(message: message, onRetry: _refresh),
      loaded: (sessions, selectedIndex) {
        if (sessions.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note_outlined,
            title: '計測会の記録がありません',
            subtitle: '計測を行うと、その日の計測会としてまとまります',
          );
        }

        final session = sessions[selectedIndex];
        return Column(
          children: [
            _buildDateNav(sessions, selectedIndex, session),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetTable(session),
                    _buildRankingSection(session),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateNav(
    List<DailySession> sessions,
    int selectedIndex,
    DailySession session,
  ) {
    final notifier = ref.read(dailyRecordsNotifierProvider.notifier);
    final canOlder = selectedIndex < sessions.length - 1;
    final canNewer = selectedIndex > 0;
    final dateText = _dateFormat.format(session.date);
    final label = '$dateText（${session.athleteCount}人）';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canOlder ? notifier.moveToOlder : null,
            tooltip: '前の計測会',
          ),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(label),
              onPressed: () => _openSessionPicker(sessions, selectedIndex),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canNewer ? notifier.moveToNewer : null,
            tooltip: '次の計測会',
          ),
        ],
      ),
    );
  }

  Future<void> _openSessionPicker(
    List<DailySession> sessions,
    int selectedIndex,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final events = session.columns.map((c) => c.name).join('・');
              return ListTile(
                selected: index == selectedIndex,
                title: Text(_dateFormat.format(session.date)),
                subtitle: Text(
                  events,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${session.athleteCount}人'),
                onTap: () => Navigator.pop(context, index),
              );
            },
          ),
        );
      },
    );
    if (picked != null) {
      ref.read(dailyRecordsNotifierProvider.notifier).selectIndex(picked);
    }
  }

  Widget _buildSheetTable(DailySession session) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: [
          const DataColumn(label: Text('選手', style: AppTextStyles.caption)),
          for (final column in session.columns)
            DataColumn(
              label: Text(column.name, style: AppTextStyles.caption),
              numeric: true,
            ),
        ],
        rows: [
          for (final row in session.rows)
            DataRow(
              cells: [
                DataCell(Text(row.name, style: AppTextStyles.body)),
                for (final column in session.columns)
                  DataCell(_buildValueCell(theme, row.cells[column.key])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildValueCell(ThemeData theme, DailyCell? cell) {
    if (cell == null) {
      return const Text('―', style: AppTextStyles.caption);
    }
    final style = AppTextStyles.body.copyWith(
      color: cell.isPersonalBest ? AppColors.success : null,
      fontWeight: cell.isPersonalBest ? FontWeight.bold : null,
    );
    return Text(cell.displayText, style: style);
  }

  Widget _buildRankingSection(DailySession session) {
    if (session.columns.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ランキングを表示する種目', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final column in session.columns) _buildRankingChip(column),
            ],
          ),
          for (final column in session.columns)
            if (!_hiddenRankingKeys.contains(column.key))
              _buildRankingFor(session, column),
        ],
      ),
    );
  }

  Widget _buildRankingChip(DailyEventColumn column) {
    final visible = !_hiddenRankingKeys.contains(column.key);
    return FilterChip(
      label: Text(column.name),
      selected: visible,
      onSelected: (value) => _toggleRanking(column.key, value),
    );
  }

  void _toggleRanking(String key, bool selected) {
    setState(() {
      if (selected) {
        _hiddenRankingKeys.remove(key);
      } else {
        _hiddenRankingKeys.add(key);
      }
    });
  }

  Widget _buildRankingFor(DailySession session, DailyEventColumn column) {
    final ranked = <({String name, DailyCell cell})>[];
    for (final row in session.rows) {
      final cell = row.cells[column.key];
      if (cell != null) ranked.add((name: row.name, cell: cell));
    }
    ranked.sort((a, b) {
      final lowerIsBetter = column.recordType.lowerIsBetter;
      if (lowerIsBetter) return a.cell.value.compareTo(b.cell.value);
      return b.cell.value.compareTo(a.cell.value);
    });

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏅 ${column.name}', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < ranked.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: AppTextStyles.body.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(ranked[i].name, style: AppTextStyles.body),
                  ),
                  Text(
                    ranked[i].cell.displayText,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
