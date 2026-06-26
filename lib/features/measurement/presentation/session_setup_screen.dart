import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

/// 計測会モードの最初の画面。日付と種目を選んで計測ループへ入る。
///
/// 計測会は「日付＋種目」で自動グルーピングするため、計測会そのものは
/// 永続化しない。日付は既定で今日だが、過去の計測会への追記もできるよう
/// カレンダーから変更できる。
class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _startSession(Event event) {
    context.pushNamed(
      'measurementSession',
      extra: SessionArgs(event: event, date: _selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(eventListNotifierProvider);
    final dateText = DateFormat('M月d日').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('計測会を始める')),
      body: eventState.when(
        loading: () => const LoadingState(message: '種目を読み込み中...'),
        error: (message) => ErrorState(
          message: message,
          onRetry: () => ref.read(eventListNotifierProvider.notifier).refresh(),
        ),
        loaded: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_outlined,
              title: '種目がありません',
              subtitle: '管理タブで種目を登録してください',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '$dateText の計測会',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '計測する種目を選んでください',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final event in events) ...[
                _EventTile(event: event, onTap: () => _startSession(event)),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = event.measurementMethod == EventMeasurementMethod.video;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          child: Icon(isVideo ? Icons.videocam : Icons.edit_note),
        ),
        title: Text(event.name),
        subtitle: Text(
          '${event.recordType.label}・${event.measurementMethod.label}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
