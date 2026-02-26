import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/features/records/presentation/widgets/record_list_tile.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  Future<void> _refresh() async {
    await ref.read(recordListNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('記録')),
      body: state.when(
        loading: () => const LoadingState(message: '記録を読み込み中...'),
        error: (message) => ErrorState(message: message, onRetry: _refresh),
        loaded: (records, hasMore, isLoadingMore) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _RecordListView(
              records: records,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
              onLoadMore: () =>
                  ref.read(recordListNotifierProvider.notifier).loadMore(),
              onDelete: (id) => ref
                  .read(recordListNotifierProvider.notifier)
                  .deleteRecord(id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('videoImport'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordListView extends StatelessWidget {
  const _RecordListView({
    required this.records,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onDelete,
  });

  final List<MeasurementRecord> records;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyState(
        icon: Icons.timer_off,
        title: '記録がありません',
        subtitle: '計測を行うと記録が表示されます',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: records.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == records.length) {
          if (!isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore();
            });
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final record = records[index];
        return Dismissible(
          key: ValueKey(record.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) =>
              DeleteConfirmationDialog.show(context, record.athleteName),
          onDismissed: (_) {
            onDelete(record.id);
          },
          child: RecordListTile(record: record),
        );
      },
    );
  }
}
