import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/models/event.dart';

/// 計測会終了時のサマリー。種目のランキングを表示する。
///
/// CSV出力は別PR（PR#3）で「この計測会を出力」を足す予定。
class SessionSummarySheet extends StatelessWidget {
  const SessionSummarySheet({
    super.key,
    required this.event,
    required this.entries,
  });

  final Event event;
  final List<SessionEntry> entries;

  static Future<void> show(
    BuildContext context, {
    required Event event,
    required List<SessionEntry> entries,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SessionSummarySheet(event: event, entries: entries),
    );
  }

  List<SessionEntry> _ranked() {
    final sorted = [...entries];
    final lowerIsBetter = event.recordType.lowerIsBetter;
    sorted.sort((a, b) {
      return lowerIsBetter
          ? a.bestValue.compareTo(b.bestValue)
          : b.bestValue.compareTo(a.bestValue);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '${event.name} の結果',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${ranked.length}人を計測しました',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ranked.isEmpty
                    ? const Center(child: Text('まだ計測がありません'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: ranked.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = ranked[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0
                                  ? AppColors.warning
                                  : AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(entry.athleteName),
                            trailing: Text(
                              entry.formattedBest,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('計測会を終了してホームへ'),
              ),
            ],
          ),
        );
      },
    );
  }
}
