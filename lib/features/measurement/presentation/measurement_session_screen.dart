import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_keypad.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_summary_sheet.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/record_value_input.dart';

/// 計測会モードの連続入力ループ。
///
/// 選手リスト＋キーパッドを出しっぱなしにして、点呼のリズムで測っていく。
/// 「保存して次へ」で次の未計測選手へ自動フォーカスし、ベスト採用は自動判定する。
class MeasurementSessionScreen extends ConsumerStatefulWidget {
  const MeasurementSessionScreen({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<MeasurementSessionScreen> createState() =>
      _MeasurementSessionScreenState();
}

class _MeasurementSessionScreenState
    extends ConsumerState<MeasurementSessionScreen> {
  String? _selectedAthleteId;
  String _input = '';

  Event get _event => widget.event;
  bool get _isInteger => _event.recordType == EventRecordType.count;

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (_input.contains('.') || _input.isEmpty) return;
        _input = '$_input.';
        return;
      }
      // 数字。先頭の余分なゼロは避ける。
      if (_input == '0') {
        _input = key;
      } else {
        _input = '$_input$key';
      }
    });
  }

  void _selectAthlete(String athleteId) {
    setState(() {
      _selectedAthleteId = athleteId;
      _input = '';
    });
  }

  void _advanceToNextUnmeasured(List<Athlete> roster) {
    final session = ref.read(measurementSessionProvider(_event));
    final currentIndex = roster.indexWhere((a) => a.id == _selectedAthleteId);
    // 現在地の次から未計測を探し、末尾まで無ければ先頭から探す。
    for (var step = 1; step <= roster.length; step++) {
      final next = roster[(currentIndex + step) % roster.length];
      if (!session.hasMeasured(next.id)) {
        _selectAthlete(next.id);
        return;
      }
    }
    // 全員計測済み。選択は維持して入力だけ消す。
    setState(() => _input = '');
  }

  Future<void> _save(List<Athlete> roster) async {
    final athleteId = _selectedAthleteId;
    if (athleteId == null) return;
    final athlete = roster.firstWhere(
      (a) => a.id == athleteId,
      orElse: () => roster.first,
    );

    final cleaned = _input.endsWith('.')
        ? _input.substring(0, _input.length - 1)
        : _input;
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('記録値を入力してください')));
      return;
    }

    final notifier = ref.read(measurementSessionProvider(_event).notifier);
    final decision = await notifier.recordAttempt(
      athleteId: athleteId,
      athleteName: athlete.name,
      value: value,
    );
    ref.invalidate(recordListNotifierProvider);

    if (!mounted) return;
    _showResult(athlete, value, decision, notifier);
    _advanceToNextUnmeasured(roster);
  }

  void _showResult(
    Athlete athlete,
    double value,
    BestAttemptDecision decision,
    MeasurementSessionNotifier notifier,
  ) {
    final unit = _event.recordType.defaultUnit;
    final valueText = RecordValueInput.formatDisplay(
      recordValue: value,
      recordUnit: unit,
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    if (decision.isNotImproved) {
      final bestText = RecordValueInput.formatDisplay(
        recordValue: decision.bestValue,
        recordUnit: unit,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${athlete.name}：ベストは$bestTextのまま（今回 $valueText は不採用）'),
          action: SnackBarAction(
            label: '今回を採用',
            onPressed: () async {
              await notifier.recordAttempt(
                athleteId: athlete.id,
                athleteName: athlete.name,
                value: value,
                forceAdopt: true,
              );
              ref.invalidate(recordListNotifierProvider);
            },
          ),
        ),
      );
      return;
    }

    final label = decision.isImproved
        ? '🔼 ${athlete.name}：ベスト更新！ $valueText'
        : '${athlete.name}：$valueText を記録';
    messenger.showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _finish() async {
    final session = ref.read(measurementSessionProvider(_event));
    await SessionSummarySheet.show(
      context,
      event: _event,
      entries: session.entries.values.toList(),
    );
    if (!mounted) return;
    // サマリーを閉じたらホームへ戻る（セットアップ画面も含めてスタックを片付ける）。
    context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(measurementSessionProvider(_event));
    final athleteState = ref.watch(athleteListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.name),
        actions: [TextButton(onPressed: _finish, child: const Text('終了'))],
      ),
      body: athleteState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (message) => Center(child: Text(message)),
        loaded: (athletes) {
          if (athletes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('選手が未登録です。管理タブで選手を登録してください。'),
              ),
            );
          }
          // 初期選択：最初の未計測選手。
          _selectedAthleteId ??= athletes
              .firstWhere(
                (a) => !session.hasMeasured(a.id),
                orElse: () => athletes.first,
              )
              .id;

          return Column(
            children: [
              _ProgressHeader(
                measured: session.measuredCount,
                total: athletes.length,
                isVideoEvent:
                    _event.measurementMethod == EventMeasurementMethod.video,
              ),
              Expanded(
                child: _RosterList(
                  athletes: athletes,
                  session: session,
                  selectedAthleteId: _selectedAthleteId,
                  onSelect: _selectAthlete,
                ),
              ),
              SessionKeypad(
                input: _input,
                unit: _event.recordType.defaultUnit,
                allowDecimal: !_isInteger,
                onKey: _onKey,
                onSave: () => _save(athletes),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.measured,
    required this.total,
    required this.isVideoEvent,
  });

  final int measured;
  final int total;
  final bool isVideoEvent;

  @override
  Widget build(BuildContext context) {
    final remaining = (total - measured).clamp(0, total);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.primaryLight.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '計測済み $measured人 ／ 残り $remaining人',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (isVideoEvent) ...[
            const SizedBox(height: 2),
            Text(
              '動画からの連続計測は準備中です。タイムを手入力できます。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.athletes,
    required this.session,
    required this.selectedAthleteId,
    required this.onSelect,
  });

  final List<Athlete> athletes;
  final MeasurementSessionState session;
  final String? selectedAthleteId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: athletes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final athlete = athletes[index];
        final entry = session.entryFor(athlete.id);
        final isSelected = athlete.id == selectedAthleteId;
        final isMeasured = entry != null;

        return Container(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.16)
              : null,
          child: ListTile(
            leading: Icon(
              isMeasured ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isMeasured ? AppColors.success : AppColors.textSecondary,
            ),
            title: Text(athlete.name),
            subtitle: isMeasured
                ? Text('${entry.formattedBest}（${entry.attemptCount}本）')
                : null,
            trailing: isSelected
                ? const Icon(Icons.edit, color: AppColors.primary)
                : null,
            onTap: () => onSelect(athlete.id),
          ),
        );
      },
    );
  }
}
