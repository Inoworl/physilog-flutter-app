import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/features/measurement/application/measurement_notifier.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/application/video_player_notifier.dart';
import 'package:physi_log/features/measurement/presentation/widgets/seek_controls.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_player_pick_sheet.dart';
import 'package:physi_log/features/measurement/presentation/widgets/time_display.dart';
import 'package:physi_log/features/measurement/presentation/widgets/video_player_widget.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/video_import/application/video_import_notifier.dart';
import 'package:physi_log/features/video_import/presentation/widgets/compress_progress_dialog.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/record_value_input.dart';
import 'package:physi_log/shared/constants/app_constants.dart';
import 'package:physi_log/shared/extensions/duration_extensions.dart';

/// 動画ループの段階。動画を選ぶ → フレームを計測する、の2段。
/// 選手選択はタイム確定後にシートで行うため段階には含めない。
enum _VideoStep { pickVideo, measuring }

/// 計測会モード（動画種目）の連続計測ループ。
///
/// 動画を選ぶ → 開始/終了フレームでタイム確定 → 選手を選ぶ → 自動保存 → 次の動画、
/// を1画面で回す。フレーム計測の状態は単発計測と同じ [measurementProvider] を流用し、
/// 保存は計測会の [MeasurementSessionNotifier.recordAttempt]（動画対応済み）に委ねる。
class SessionVideoLoop extends ConsumerStatefulWidget {
  const SessionVideoLoop({
    super.key,
    required this.event,
    required this.args,
    required this.roster,
    required this.onSwitchToManual,
  });

  final Event event;
  final SessionArgs args;
  final List<Athlete> roster;

  /// 「手入力に切り替え」を押したとき（電池切れ・撮る暇がない時の保険）。
  final VoidCallback onSwitchToManual;

  @override
  ConsumerState<SessionVideoLoop> createState() => _SessionVideoLoopState();
}

class _SessionVideoLoopState extends ConsumerState<SessionVideoLoop> {
  final TransformationController _videoZoom = TransformationController();

  _VideoStep _step = _VideoStep.pickVideo;
  String? _videoPath;
  bool _compressDialogOpen = false;

  @override
  void dispose() {
    _videoZoom.dispose();
    super.dispose();
  }

  bool _isImportBusy(VideoImportState s) =>
      s is VideoImportPicking || s is VideoImportCompressing;

  void _handleImportState(VideoImportState? prev, VideoImportState next) {
    // 圧縮中ダイアログの開閉は VideoImportScreen と同じ作法。
    if (next is VideoImportCompressing && !_compressDialogOpen) {
      _compressDialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(videoImportProvider);
            final progress = s is VideoImportCompressing ? s.progress : 0.0;
            return CompressProgressDialog(progress: progress);
          },
        ),
      );
    }

    if (next is VideoImportCompleted) {
      _dismissCompressDialog();
      _videoPath = next.filePath;
      // フレーム計測状態を初期化してから動画を読み込む。
      ref.read(measurementProvider.notifier).resetPositions();
      ref.read(videoPlayerProvider.notifier).initializeVideo(next.filePath);
      ref.read(videoImportProvider.notifier).reset();
      if (mounted) setState(() => _step = _VideoStep.measuring);
    }

    if (next is VideoImportError) {
      _dismissCompressDialog();
      ref.read(videoImportProvider.notifier).reset();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message)));
      }
    }
  }

  void _dismissCompressDialog() {
    if (_compressDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _compressDialogOpen = false;
    }
  }

  Future<void> _pickAthleteAndSave() async {
    final measure = ref.read(measurementProvider);
    final calculated = measure.calculatedTime;
    if (calculated == null) return;
    final value = calculated.inMilliseconds / 1000.0;
    if (value <= 0) return;

    final session = ref.read(measurementSessionProvider(widget.args));
    final result = await showSessionPlayerPickSheet(
      context: context,
      roster: widget.roster,
      session: session,
      measuredValue: value,
      unit: widget.event.unit,
    );
    if (result == null || !mounted) return; // 閉じただけ＝計測継続

    if (result.discard) {
      await _resetForNextVideo();
      return;
    }

    final athleteId = result.athleteId!;
    final athlete = widget.roster.firstWhere(
      (a) => a.id == athleteId,
      orElse: () => widget.roster.first,
    );

    final notifier = ref.read(measurementSessionProvider(widget.args).notifier);
    final decision = await notifier.recordAttempt(
      athleteId: athleteId,
      athleteName: athlete.name,
      value: value,
      videoRef: _videoPath,
      fps: measure.fps,
    );
    ref.invalidate(recordListNotifierProvider);
    if (!mounted) return;

    _showDecisionSnack(
      decision: decision,
      athleteId: athleteId,
      athleteName: athlete.name,
      value: value,
      fps: measure.fps,
    );
    await _resetForNextVideo();
  }

  void _showDecisionSnack({
    required BestAttemptDecision decision,
    required String athleteId,
    required String athleteName,
    required double value,
    required double fps,
  }) {
    final unit = widget.event.unit;
    final valueText = RecordValueInput.formatDisplay(
      recordValue: value,
      recordUnit: unit,
    );

    final String message;
    SnackBarAction? action;
    if (decision.isImproved) {
      message = '🔼 $athleteName：ベスト更新！ $valueText';
    } else if (decision.isNotImproved) {
      final bestText = RecordValueInput.formatDisplay(
        recordValue: decision.bestValue,
        recordUnit: unit,
      );
      message = '$athleteName：ベストは$bestTextのまま（今回 $valueText は不採用）';
      // 1本目のフレーム指定ミスなどの救済路。あとから今回値を採用できる。
      final videoRef = _videoPath;
      action = SnackBarAction(
        label: '今回を採用',
        onPressed: () async {
          await ref
              .read(measurementSessionProvider(widget.args).notifier)
              .recordAttempt(
                athleteId: athleteId,
                athleteName: athleteName,
                value: value,
                videoRef: videoRef,
                fps: fps,
                forceAdopt: true,
              );
          ref.invalidate(recordListNotifierProvider);
        },
      );
    } else {
      message = '$athleteName：$valueText を記録';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _resetForNextVideo() async {
    await ref.read(videoPlayerProvider.notifier).release();
    ref.read(measurementProvider.notifier).resetPositions();
    _videoPath = null;
    if (mounted) setState(() => _step = _VideoStep.pickVideo);
  }

  Future<void> _switchToManual() async {
    await ref.read(videoPlayerProvider.notifier).release();
    if (!mounted) return;
    ref.read(measurementProvider.notifier).resetPositions();
    widget.onSwitchToManual();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VideoImportState>(videoImportProvider, _handleImportState);

    return _step == _VideoStep.pickVideo
        ? _buildPickVideo(context)
        : _buildMeasuring(context);
  }

  Widget _buildPickVideo(BuildContext context) {
    final importState = ref.watch(videoImportProvider);
    final busy = _isImportBusy(importState);

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              '次の選手の動画を撮影または選択してください',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PickCard(
              icon: Icons.camera_alt,
              title: 'カメラで撮影する',
              subtitle: '今すぐ撮影して計測',
              onTap: busy
                  ? null
                  : () =>
                        ref.read(videoImportProvider.notifier).pickFromCamera(),
            ),
            const SizedBox(height: AppSpacing.md),
            _PickCard(
              icon: Icons.photo_library,
              title: 'アルバムから選択する',
              subtitle: '保存済みの動画から選択',
              onTap: busy
                  ? null
                  : () => ref
                        .read(videoImportProvider.notifier)
                        .pickFromGallery(),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: busy ? null : _switchToManual,
              icon: const Icon(Icons.keyboard),
              label: const Text('手入力に切り替え'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasuring(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final measure = ref.watch(measurementProvider);
    final theme = Theme.of(context);

    final hasVideo = videoState.isInitialized && videoState.controller != null;
    final frameDuration = Duration(milliseconds: (1000 / measure.fps).round());
    final canPickAthlete = measure.calculatedTime != null;

    if (videoState.error != null) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(videoState.error!, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _resetForNextVideo,
                  child: const Text('別の動画を選ぶ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 動画プレビュー
            Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoPlayerWidget(
                  controller: videoState.controller,
                  isInitialized: videoState.isInitialized,
                  isPlaying: videoState.isPlaying,
                  transformationController: _videoZoom,
                  onTap: () =>
                      ref.read(videoPlayerProvider.notifier).togglePlay(),
                ),
              ),
            ),
            if (hasVideo) ...[
              const SizedBox(height: AppSpacing.md),
              Slider(
                value: videoState.currentPosition.inMilliseconds
                    .toDouble()
                    .clamp(
                      0,
                      videoState.totalDuration.inMilliseconds.toDouble(),
                    ),
                max: videoState.totalDuration.inMilliseconds.toDouble().clamp(
                  1,
                  double.infinity,
                ),
                onChanged: (value) => ref
                    .read(videoPlayerProvider.notifier)
                    .seekTo(Duration(milliseconds: value.round())),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  videoState.currentPosition.toTimestamp(),
                  style: AppTextStyles.timeDisplaySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SeekControls(
                isPlaying: videoState.isPlaying,
                fps: measure.fps,
                onSeekBackward100ms: () => ref
                    .read(videoPlayerProvider.notifier)
                    .seekBackward(const Duration(milliseconds: 100)),
                onSeekBackward1Frame: () => ref
                    .read(videoPlayerProvider.notifier)
                    .seekBackward(frameDuration),
                onTogglePlay: () =>
                    ref.read(videoPlayerProvider.notifier).togglePlay(),
                onSeekForward1Frame: () => ref
                    .read(videoPlayerProvider.notifier)
                    .seekForward(frameDuration),
                onSeekForward100ms: () => ref
                    .read(videoPlayerProvider.notifier)
                    .seekForward(const Duration(milliseconds: 100)),
              ),
              const SizedBox(height: AppSpacing.lg),
              // スタート / ストップ
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.startColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => ref
                            .read(measurementProvider.notifier)
                            .setStartPosition(videoState.currentPosition),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('スタート'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.endColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => ref
                            .read(measurementProvider.notifier)
                            .setEndPosition(videoState.currentPosition),
                        icon: const Icon(Icons.flag),
                        label: const Text('ストップ'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TimeDisplay(
                startPosition: measure.startPosition,
                endPosition: measure.endPosition,
                calculatedTime: measure.calculatedTime,
                fps: measure.fps,
                onConfirmStart: () => ref
                    .read(measurementProvider.notifier)
                    .setStartPosition(videoState.currentPosition),
                onConfirmEnd: () => ref
                    .read(measurementProvider.notifier)
                    .setEndPosition(videoState.currentPosition),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('FPSを選択', style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: AppConstants.fpsOptions.map((fpsOption) {
                  return ChoiceChip(
                    label: Text('${fpsOption.toInt()} fps'),
                    selected: measure.fps == fpsOption,
                    onSelected: (_) => ref
                        .read(measurementProvider.notifier)
                        .setFps(fpsOption),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: canPickAthlete ? _pickAthleteAndSave : null,
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('この記録の選手を選ぶ'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetForNextVideo,
                      icon: const Icon(Icons.refresh),
                      label: const Text('別の動画を選ぶ'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _switchToManual,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('手入力に切替'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                '動画を読み込んでいます…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = onTap == null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: BorderSide(
          color: isDisabled
              ? colorScheme.outline.withValues(alpha: 0.3)
              : colorScheme.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDisabled
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer,
                child: Icon(
                  icon,
                  size: 20,
                  color: isDisabled
                      ? colorScheme.onSurface.withValues(alpha: 0.38)
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
