import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/features/records/presentation/widgets/record_filter_sheet.dart';
import 'package:physi_log/features/records/presentation/widgets/record_list_tile.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class RecordListScreen extends ConsumerWidget {
  const RecordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhysiLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => RecordFilterSheet.show(context),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingState(message: '記録を読み込み中...'),
        error: (message) => ErrorState(
          message: message,
          onRetry: () => ref.read(recordListNotifierProvider.notifier).refresh(),
        ),
        loaded: (records, hasMore, isLoadingMore) {
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.timer_off,
              title: '記録がありません',
              subtitle: '動画から計測を始めましょう',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(recordListNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: records.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == records.length) {
                  // 追加読み込みトリガー
                  if (!isLoadingMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(recordListNotifierProvider.notifier).loadMore();
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
                  confirmDismiss: (_) async {
                    return await DeleteConfirmationDialog.show(
                      context,
                      record.athleteName,
                    );
                  },
                  onDismissed: (_) {
                    ref.read(recordListNotifierProvider.notifier).deleteRecord(record.id);
                  },
                  child: RecordListTile(record: record),
                );
              },
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
