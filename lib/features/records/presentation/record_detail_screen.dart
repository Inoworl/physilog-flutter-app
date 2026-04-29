import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

final _recordDetailProvider = FutureProvider.family<MeasurementRecord?, String>(
  (ref, id) async {
    final repository = ref.watch(recordRepositoryProvider);
    return repository.getRecord(id);
  },
);

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRecord = ref.watch(_recordDetailProvider(recordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('記録詳細'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _onMenuSelected(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('編集')),
              const PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: asyncRecord.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: '記録の読み込みに失敗しました',
          onRetry: () => ref.invalidate(_recordDetailProvider(recordId)),
        ),
        data: (record) {
          if (record == null) {
            return const ErrorState(message: '記録が見つかりません');
          }
          return _buildContent(context, record);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, MeasurementRecord record) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 記録表示
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    record.formattedRecordValue,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (record.accuracyInfo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      record.accuracyInfo!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 詳細情報
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('選手名'),
                  subtitle: Text(record.athleteName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sports),
                  title: const Text('種目'),
                  subtitle: Text(record.eventType),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('計測日'),
                  subtitle: Text(dateFormat.format(record.measuredAt)),
                ),
                if (record.memo.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.note),
                    title: const Text('メモ'),
                    subtitle: Text(record.memo),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ボトムアクション
          Row(
            children: [
              if (record.hasVideoReference) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed(
                      'measurement',
                      extra: {'recordId': record.id},
                    ),
                    icon: const Icon(Icons.replay),
                    label: const Text('再計測'),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.pushNamed(
                    'recordEdit',
                    pathParameters: {'id': record.id},
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('編集'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final record = ref.read(_recordDetailProvider(recordId)).valueOrNull;
    if (record == null) return;

    switch (value) {
      case 'edit':
        context.pushNamed('recordEdit', pathParameters: {'id': recordId});
      case 'delete':
        final confirmed = await DeleteConfirmationDialog.show(
          context,
          record.athleteName,
        );
        if (confirmed == true && context.mounted) {
          await ref
              .read(recordListNotifierProvider.notifier)
              .deleteRecord(recordId);
          if (context.mounted) context.pop();
        }
    }
  }
}
