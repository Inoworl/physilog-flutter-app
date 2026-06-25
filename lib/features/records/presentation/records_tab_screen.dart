import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/daily_sheet_view.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/features/records/presentation/record_sheet_view.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/features/records/presentation/widgets/record_filter_sheet.dart';
import 'package:physi_log/features/records/presentation/widgets/record_list_tile.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

enum RecordsViewMode { list, sheet, daily }

class RecordsTabScreen extends ConsumerStatefulWidget {
  const RecordsTabScreen({
    super.key,
    this.initialViewMode = RecordsViewMode.list,
    this.initialAthleteId,
  });

  final RecordsViewMode initialViewMode;
  final String? initialAthleteId;

  @override
  ConsumerState<RecordsTabScreen> createState() => _RecordsTabScreenState();
}

class _RecordsTabScreenState extends ConsumerState<RecordsTabScreen> {
  late RecordsViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
  }

  @override
  void didUpdateWidget(covariant RecordsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialViewMode != oldWidget.initialViewMode ||
        widget.initialAthleteId != oldWidget.initialAthleteId) {
      _viewMode = widget.initialViewMode;
    }
  }

  Future<void> _refresh() async {
    await ref.read(recordListNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('検索機能は準備中です')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => RecordFilterSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SegmentedButton<RecordsViewMode>(
              segments: const [
                ButtonSegment(
                  value: RecordsViewMode.list,
                  label: Text('一覧'),
                  icon: Icon(Icons.list_alt),
                ),
                ButtonSegment(
                  value: RecordsViewMode.daily,
                  label: Text('日別'),
                  icon: Icon(Icons.event_note),
                ),
                ButtonSegment(
                  value: RecordsViewMode.sheet,
                  label: Text('シート'),
                  icon: Icon(Icons.table_chart),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (selected) {
                setState(() => _viewMode = selected.first);
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_viewMode) {
                RecordsViewMode.list => _RecordListContent(
                  key: const ValueKey(RecordsViewMode.list),
                  onRefresh: _refresh,
                ),
                RecordsViewMode.daily => const DailySheetView(
                  key: ValueKey(RecordsViewMode.daily),
                ),
                RecordsViewMode.sheet => RecordSheetView(
                  key: ValueKey(
                    '${RecordsViewMode.sheet.name}-${widget.initialAthleteId ?? ''}',
                  ),
                  initialAthleteId: widget.initialAthleteId,
                ),
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ManualRecordForm.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordListContent extends ConsumerWidget {
  const _RecordListContent({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordListNotifierProvider);

    return state.when(
      loading: () => const LoadingState(message: '記録を読み込み中...'),
      error: (message) => ErrorState(message: message, onRetry: onRefresh),
      loaded: (records, hasMore, isLoadingMore) {
        if (records.isEmpty) {
          return const EmptyState(
            icon: Icons.timer_off,
            title: '記録がありません',
            subtitle: '計測を行うと記録が表示されます',
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 120),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: records.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == records.length) {
                if (!isLoadingMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(recordListNotifierProvider.notifier).loadMore();
                  });
                }
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final record = records[index];
              return Dismissible(
                key: ValueKey(record.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  color: Theme.of(context).colorScheme.error,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) =>
                    DeleteConfirmationDialog.show(context, record.athleteName),
                onDismissed: (_) {
                  ref
                      .read(recordListNotifierProvider.notifier)
                      .deleteRecord(record.id);
                },
                child: RecordListTile(record: record),
              );
            },
          ),
        );
      },
    );
  }
}
