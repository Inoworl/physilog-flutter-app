import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/record_value_input.dart';

/// 動画計測でタイムを確定したあと「どの選手の記録か」を選ぶシートの結果。
///
/// - [athleteId] が非nullなら、その選手にこのタイムを保存する。
/// - [discard] が true なら、この計測を破棄して次の動画へ進む。
/// - シートを閉じただけ（barrier/スワイプ）のときは null を返し、計測画面に留まる。
class SessionPlayerPickResult {
  const SessionPlayerPickResult.select(String this.athleteId) : discard = false;
  const SessionPlayerPickResult.discard() : athleteId = null, discard = true;

  final String? athleteId;
  final bool discard;
}

/// タイム確定後に呼ぶ。名簿から選手を選ばせ、計測済みの選手にはベスト・試技数を表示する。
Future<SessionPlayerPickResult?> showSessionPlayerPickSheet({
  required BuildContext context,
  required List<Athlete> roster,
  required MeasurementSessionState session,
  required double measuredValue,
  required String unit,
}) {
  return showModalBottomSheet<SessionPlayerPickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SessionPlayerPickSheet(
      roster: roster,
      session: session,
      measuredValue: measuredValue,
      unit: unit,
    ),
  );
}

class _SessionPlayerPickSheet extends StatelessWidget {
  const _SessionPlayerPickSheet({
    required this.roster,
    required this.session,
    required this.measuredValue,
    required this.unit,
  });

  final List<Athlete> roster;
  final MeasurementSessionState session;
  final double measuredValue;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = RecordValueInput.formatDisplay(
      recordValue: measuredValue,
      recordUnit: unit,
    );
    final measured = session.measuredCount;
    final remaining = (roster.length - measured).clamp(0, roster.length);
    // シートが画面いっぱいに伸びないよう高さを抑える（名簿が長くても内側でスクロール）。
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('計測タイム $valueText', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'この記録の選手を選んでください ・ 残り $remaining人',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                shrinkWrap: true,
                itemCount: roster.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final athlete = roster[index];
                  final entry = session.entryFor(athlete.id);
                  final isMeasured = entry != null;
                  return ListTile(
                    leading: Icon(
                      isMeasured
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isMeasured
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    title: Text(athlete.name),
                    subtitle: isMeasured
                        ? Text('${entry.formattedBest}（${entry.attemptCount}本）')
                        : null,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(SessionPlayerPickResult.select(athlete.id)),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const SessionPlayerPickResult.discard()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('この計測を破棄して次へ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
