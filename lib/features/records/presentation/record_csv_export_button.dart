import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/athlete.dart';
import '../../../models/event.dart';
import '../../../providers/app_providers.dart';
import '../../billing/domain/plan_access_state.dart';
import '../../billing/domain/recording_scope.dart';
import '../../billing/presentation/upgrade_prompt.dart';
import '../../manage/application/athlete_list_notifier.dart';
import '../../manage/application/event_list_notifier.dart';
import '../application/record_csv_export_service.dart';
import '../application/record_csv_providers.dart';

class RecordCsvExportButton extends ConsumerWidget {
  const RecordCsvExportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planAccessStateProvider);
    return IconButton(
      tooltip: 'CSV出力',
      icon: const Icon(Icons.file_download_outlined),
      onPressed: plan is! PlanAccessReady
          ? null
          : () async {
              if (!plan.capabilities.canExportCsv) {
                final showPlans = await showUpgradePromptDialog(
                  context,
                  title: 'Teamプランの機能です',
                  message: '記録のCSV出力はTeamプランで利用できます。',
                );
                if (showPlans && context.mounted) {
                  context.push('/settings/plan');
                }
                return;
              }
              await showDialog<void>(
                context: context,
                builder: (context) => const _CsvExportDialog(),
              );
            },
    );
  }
}

class _CsvExportDialog extends ConsumerStatefulWidget {
  const _CsvExportDialog();

  @override
  ConsumerState<_CsvExportDialog> createState() => _CsvExportDialogState();
}

class _CsvExportDialogState extends ConsumerState<_CsvExportDialog> {
  late final _owner = ref.read(currentUserIdProvider);
  String? _athleteId;
  String? _eventId;
  DateTimeRange? _dates;
  CsvExportPreview? _preview;
  String? _error;
  var _busy = false;

  Future<void> _prepare() async {
    if (_busy || _owner != ref.read(currentUserIdProvider)) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await ref
          .read(recordCsvExportServiceProvider)
          .prepare(
            CsvExportQuery(
              athleteId: _athleteId,
              eventId: _eventId,
              dateFrom: _dates?.start,
              dateTo: _dates?.end,
            ),
          );
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlanAccessException
              ? error.message
              : '記録を取得できませんでした。通信状態を確認してください。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final preview = _preview;
    if (_busy || preview == null) return;
    final render = buttonContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final origin = render.localToGlobal(Offset.zero) & render.size;
    final service = ref.read(recordCsvExportServiceProvider);
    final sharer = ref.read(recordCsvSharerProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await service.share(
        preview,
        (document, authorize) => sharer.share(
          document,
          origin: origin,
          authorize: () {
            if (!mounted) throw const PlanAccessException('出力がキャンセルされました。');
            authorize();
          },
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlanAccessException
              ? error.message
              : 'CSVを共有できませんでした。保存先を確認して再度お試しください。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dates,
      helpText: '出力する測定期間',
      saveText: '期間を選択',
    );
    if (mounted && selected != null) {
      setState(() {
        _dates = selected;
        _preview = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerChanged = _owner != ref.watch(currentUserIdProvider);
    if (ownerChanged) {
      return AlertDialog(
        title: const Text('記録をCSV出力'),
        content: const Text('アカウントが変わりました。出力画面を開き直してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    }
    final plan = ref.watch(planAccessStateProvider);
    final allowed = plan is PlanAccessReady && plan.capabilities.canExportCsv;
    final athleteState = ref.watch(athleteListNotifierProvider);
    final eventState = ref.watch(eventListNotifierProvider);
    final athletes = athleteState.maybeWhen<List<Athlete>?>(
      loaded: (athletes) => athletes,
      orElse: () => null,
    );
    final events = eventState.maybeWhen<List<Event>?>(
      loaded: (events) => events,
      orElse: () => null,
    );
    final catalogsReady = athletes != null && events != null;
    final missingFilter =
        catalogsReady &&
        ((_athleteId != null &&
                !athletes.any((athlete) => athlete.id == _athleteId)) ||
            (_eventId != null && !events.any((event) => event.id == _eventId)));
    if (!catalogsReady || missingFilter) {
      return AlertDialog(
        title: const Text('記録をCSV出力'),
        content: Text(
          missingFilter
              ? '選択した選手・種目が変更されました。条件を選び直してください。'
              : '選手・種目を確認しています。読み込めない場合は再確認してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              if (missingFilter) {
                setState(() {
                  _athleteId = null;
                  _eventId = null;
                  _preview = null;
                  _error = null;
                });
              } else {
                ref.invalidate(athleteListNotifierProvider);
                ref.invalidate(eventListNotifierProvider);
              }
            },
            child: Text(missingFilter ? '条件をリセット' : '再確認'),
          ),
        ],
      );
    }
    final enabled = allowed && !_busy;
    final preview = _preview;
    String formatDate(DateTime date) =>
        '${date.year}/${date.month}/${date.day}';
    return AlertDialog(
      title: const Text('記録をCSV出力'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!allowed) const Text('プランまたはアカウントが変わりました。画面を開き直してください。'),
              DropdownButtonFormField<String>(
                initialValue: _athleteId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '選手'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('すべての選手')),
                  for (final athlete in athletes)
                    DropdownMenuItem(
                      value: athlete.id,
                      child: Text(athlete.name),
                    ),
                ],
                onChanged: enabled
                    ? (value) => setState(() {
                        _athleteId = value == '' ? null : value;
                        _preview = null;
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _eventId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '種目'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('すべての種目')),
                  for (final event in events)
                    DropdownMenuItem(value: event.id, child: Text(event.name)),
                ],
                onChanged: enabled
                    ? (value) => setState(() {
                        _eventId = value == '' ? null : value;
                        _preview = null;
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: enabled ? _pickDates : null,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _dates == null
                      ? '期間を指定（現在は全期間）'
                      : '${formatDate(_dates!.start)} 〜 ${formatDate(_dates!.end)}',
                ),
              ),
              if (_dates != null)
                TextButton(
                  onPressed: enabled
                      ? () => setState(() {
                          _dates = null;
                          _preview = null;
                        })
                      : null,
                  child: const Text('全期間に戻す'),
                ),
              const SizedBox(height: 12),
              const Text(
                '選手名・種目・測定日時・記録値・単位・セットを含むファイルです。共有先を確認してください。保存済みのファイルはアプリから回収できません。',
              ),
              const SizedBox(height: 8),
              const Text('日時はUTC（末尾Z）、文字コードはUTF-8です。1回10,000件まで出力できます。'),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${preview.document.count}件の記録を出力します',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        if (preview == null)
          FilledButton(
            onPressed: enabled ? _prepare : null,
            child: const Text('対象を確認'),
          )
        else
          Builder(
            builder: (buttonContext) => FilledButton(
              onPressed: enabled && preview.document.count > 0
                  ? () => _share(buttonContext)
                  : null,
              child: const Text('CSVを保存・共有'),
            ),
          ),
      ],
    );
  }
}
