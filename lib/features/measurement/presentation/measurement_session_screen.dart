import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/application/min_sec_input.dart';
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
  const MeasurementSessionScreen({
    super.key,
    required this.event,
    required this.date,
  });

  final Event event;

  /// 計測会の日付（種目選択画面で指定。当日固定ではない）。
  final DateTime date;

  @override
  ConsumerState<MeasurementSessionScreen> createState() =>
      _MeasurementSessionScreenState();
}

class _MeasurementSessionScreenState
    extends ConsumerState<MeasurementSessionScreen> {
  String? _selectedAthleteId;
  String _input = '';
  _SessionFeedback? _feedback;

  /// タイム種目で「分:秒」入力にしているか（既定は秒）。
  bool _timeMode = false;

  Event get _event => widget.event;
  SessionArgs get _args => SessionArgs(event: widget.event, date: widget.date);
  bool get _isInteger => _event.recordType == EventRecordType.count;
  bool get _isTimeEvent => _event.recordType == EventRecordType.time;

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        return;
      }
      if (_timeMode) {
        // 分:秒モードは数字のみ・最大4桁（99:59）。先頭ゼロは受けない。
        if (key == '.') return;
        if (_input.length >= 4) return;
        if (_input.isEmpty && key == '0') return;
        _input = '$_input$key';
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
    final session = ref.read(measurementSessionProvider(_args));
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

    final double value;
    if (_timeMode) {
      final parsed = MinSecInput.toSeconds(_input);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分:秒を入力してください（秒は00〜59）')));
        return;
      }
      value = parsed;
    } else {
      final cleaned = _input.endsWith('.')
          ? _input.substring(0, _input.length - 1)
          : _input;
      final parsed = double.tryParse(cleaned);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('記録値を入力してください')));
        return;
      }
      value = parsed;
    }

    final notifier = ref.read(measurementSessionProvider(_args).notifier);
    final decision = await notifier.recordAttempt(
      athleteId: athleteId,
      athleteName: athlete.name,
      value: value,
    );
    ref.invalidate(recordListNotifierProvider);

    if (!mounted) return;
    // 結果は画面上部のバナーで知らせる（下部の「保存して次へ」に重ねない）。
    setState(() {
      _feedback = _SessionFeedback(
        athleteId: athleteId,
        athleteName: athlete.name,
        value: value,
        decision: decision,
      );
    });
    _advanceToNextUnmeasured(roster);
  }

  /// 更新ならずの試技を、あとから採用する救済路。
  Future<void> _adoptLast() async {
    final fb = _feedback;
    if (fb == null) return;
    final notifier = ref.read(measurementSessionProvider(_args).notifier);
    await notifier.recordAttempt(
      athleteId: fb.athleteId,
      athleteName: fb.athleteName,
      value: fb.value,
      forceAdopt: true,
    );
    ref.invalidate(recordListNotifierProvider);
    if (!mounted) return;
    setState(() => _feedback = null);
  }

  Future<void> _finish() async {
    final session = ref.read(measurementSessionProvider(_args));
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
    final session = ref.watch(measurementSessionProvider(_args));
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
                date: widget.date,
                isVideoEvent:
                    _event.measurementMethod == EventMeasurementMethod.video,
              ),
              if (_feedback != null)
                _ResultBanner(
                  feedback: _feedback!,
                  unit: _event.unit,
                  onAdopt: _adoptLast,
                  onClose: () => setState(() => _feedback = null),
                ),
              Expanded(
                child: _RosterList(
                  athletes: athletes,
                  session: session,
                  selectedAthleteId: _selectedAthleteId,
                  onSelect: _selectAthlete,
                ),
              ),
              if (_isTimeEvent)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('秒')),
                      ButtonSegment(value: true, label: Text('分:秒')),
                    ],
                    selected: {_timeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selected) => setState(() {
                      _timeMode = selected.first;
                      _input = '';
                    }),
                  ),
                ),
              SessionKeypad(
                input: _timeMode ? MinSecInput.format(_input) : _input,
                unit: _timeMode ? '分:秒' : _event.unit,
                allowDecimal: !_isInteger && !_timeMode,
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
    required this.date,
    required this.isVideoEvent,
  });

  final int measured;
  final int total;
  final DateTime date;
  final bool isVideoEvent;

  @override
  Widget build(BuildContext context) {
    final remaining = (total - measured).clamp(0, total);
    final dateText = '${date.month}月${date.day}日';
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
            '$dateText ・ 計測済み $measured人 ／ 残り $remaining人',
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

/// 直前の試技の結果（バナー表示用）。
class _SessionFeedback {
  const _SessionFeedback({
    required this.athleteId,
    required this.athleteName,
    required this.value,
    required this.decision,
  });

  final String athleteId;
  final String athleteName;
  final double value;
  final BestAttemptDecision decision;
}

/// 直前の保存結果を画面上部に出すバナー。SnackBarと違い下部のボタンに重ならない。
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.feedback,
    required this.unit,
    required this.onAdopt,
    required this.onClose,
  });

  final _SessionFeedback feedback;
  final String unit;
  final Future<void> Function() onAdopt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final decision = feedback.decision;
    final valueText = RecordValueInput.formatDisplay(
      recordValue: feedback.value,
      recordUnit: unit,
    );

    final Color background;
    final String message;
    if (decision.isImproved) {
      background = AppColors.success.withValues(alpha: 0.14);
      message = '🔼 ${feedback.athleteName}：ベスト更新！ $valueText';
    } else if (decision.isNotImproved) {
      background = AppColors.warning.withValues(alpha: 0.16);
      final bestText = RecordValueInput.formatDisplay(
        recordValue: decision.bestValue,
        recordUnit: unit,
      );
      message = '${feedback.athleteName}：ベストは$bestTextのまま（今回 $valueText は不採用）';
    } else {
      background = AppColors.primaryLight.withValues(alpha: 0.14);
      message = '${feedback.athleteName}：$valueText を記録';
    }

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (decision.isNotImproved)
            TextButton(onPressed: onAdopt, child: const Text('今回を採用')),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
