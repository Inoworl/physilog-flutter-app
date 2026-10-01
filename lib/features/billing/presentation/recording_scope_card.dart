import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../manage/application/athlete_list_notifier.dart';
import '../../manage/application/event_list_notifier.dart';
import '../application/recording_access_providers.dart';
import '../application/recording_access_service.dart';
import '../domain/recording_scope.dart';
import '../domain/plan_access_state.dart';

class RecordingScopeCard extends ConsumerWidget {
  const RecordingScopeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planAccessStateProvider);
    if (plan is! PlanAccessReady) return const SizedBox.shrink();
    final athleteCount = ref
        .watch(athleteListNotifierProvider)
        .maybeWhen<int?>(
          loaded: (athletes) => athletes.length,
          orElse: () => null,
        );
    final eventCount = ref
        .watch(eventListNotifierProvider)
        .maybeWhen<int?>(loaded: (events) => events.length, orElse: () => null);
    if (athleteCount == null || eventCount == null) {
      return const SizedBox.shrink();
    }
    final capabilities = plan.capabilities;
    if ((capabilities.maxAthleteCount == null ||
            athleteCount <= capabilities.maxAthleteCount!) &&
        (capabilities.maxEventCount == null ||
            eventCount <= capabilities.maxEventCount!)) {
      return const SizedBox.shrink();
    }
    final value = ref.watch(recordingAccessProvider);
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => ListTile(
        title: const Text('計測対象を確認できません'),
        subtitle: const Text('過去の記録は引き続き閲覧できます。'),
        trailing: IconButton(
          tooltip: '計測対象を再確認',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(recordingAccessProvider),
        ),
      ),
      data: (access) {
        if (!access.scope.hasExtraAthletes && !access.scope.hasExtraEvents) {
          return const SizedBox.shrink();
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '現在のプランの計測対象',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '過去の記録は削除されません。新しい計測・記録の編集は、上限内で選んだ選手と種目が対象です。選択はこの端末に保存されます。',
                ),
                Text(
                  '選手 ${access.scope.athleteIds.length}人 / 種目 ${access.scope.eventIds.length}つを選択中',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.checklist),
                  label: const Text('計測対象を選ぶ'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => _RecordingScopeDialog(access: access),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecordingScopeDialog extends ConsumerStatefulWidget {
  const _RecordingScopeDialog({required this.access});
  final RecordingAccess access;

  @override
  ConsumerState<_RecordingScopeDialog> createState() =>
      _RecordingScopeDialogState();
}

class _RecordingScopeDialogState extends ConsumerState<_RecordingScopeDialog> {
  late final _athletes = {...widget.access.scope.athleteIds};
  late final _events = {...widget.access.scope.eventIds};
  var _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || ref.read(currentUserIdProvider) != widget.access.userId) {
      return;
    }
    if ((widget.access.scope.hasExtraAthletes && _athletes.isEmpty) ||
        (widget.access.scope.hasExtraEvents && _events.isEmpty)) {
      setState(() => _error = '選手と種目を少なくとも1つずつ選んでください。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(recordingAccessServiceProvider)
          .select(RecordingSelection(athleteIds: _athletes, eventIds: _events));
      if (!mounted) return;
      ref.invalidate(recordingAccessProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlanAccessException
              ? error.message
              : '選択を保存できませんでした。再度お試しください。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final changedOwner = ref.watch(currentUserIdProvider) != access.userId;
    if (changedOwner) {
      return AlertDialog(
        title: const Text('計測対象を選択'),
        content: const Text('アカウントが変わりました。画面を開き直してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    }
    Widget choice(String id, String name, Set<String> selected, int? limit) =>
        CheckboxListTile(
          title: Text(name),
          value: selected.contains(id),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged:
              _saving ||
                  (!selected.contains(id) &&
                      limit != null &&
                      selected.length >= limit)
              ? null
              : (checked) => setState(() {
                  if (checked == true) {
                    selected.add(id);
                  } else {
                    selected.remove(id);
                  }
                }),
        );
    return AlertDialog(
      title: const Text('計測対象を選択'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (access.scope.hasExtraAthletes) ...[
                  Text('選手（最大${access.capabilities.maxAthleteCount}人）'),
                  for (final athlete in access.athletes)
                    choice(
                      athlete.id,
                      athlete.name,
                      _athletes,
                      access.capabilities.maxAthleteCount,
                    ),
                ],
                if (access.scope.hasExtraEvents) ...[
                  Text('種目（最大${access.capabilities.maxEventCount}つ）'),
                  for (final event in access.events)
                    choice(
                      event.id,
                      event.name,
                      _events,
                      access.capabilities.maxEventCount,
                    ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '選択を保存'),
        ),
      ],
    );
  }
}
