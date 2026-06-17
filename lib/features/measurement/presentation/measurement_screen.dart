import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/shared/constants/app_constants.dart';
import 'package:physi_log/shared/extensions/duration_extensions.dart';
import 'package:physi_log/features/measurement/application/measurement_notifier.dart';
import 'package:physi_log/features/measurement/application/video_player_notifier.dart';
import 'package:physi_log/features/measurement/presentation/widgets/video_player_widget.dart';
import 'package:physi_log/features/measurement/presentation/widgets/seek_controls.dart';
import 'package:physi_log/features/measurement/presentation/widgets/time_display.dart';

class MeasurementScreen extends ConsumerStatefulWidget {
  const MeasurementScreen({super.key, this.videoPath, this.existingRecordId});

  final String? videoPath;
  final String? existingRecordId;

  @override
  ConsumerState<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends ConsumerState<MeasurementScreen> {
  final TransformationController _videoZoomController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.videoPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(videoPlayerProvider.notifier)
            .initializeVideo(widget.videoPath!);
      });
    }
  }

  @override
  void dispose() {
    _videoZoomController.dispose();
    super.dispose();
  }

  InputDecoration _filledDecoration(
    String label, {
    IconData? icon,
    bool align = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      alignLabelWithHint: align,
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final measureState = ref.watch(measurementProvider);
    final athleteState = ref.watch(athleteListNotifierProvider);
    final eventState = ref.watch(eventListNotifierProvider);
    final List<Athlete> athletes = athleteState.maybeWhen(
      loaded: (athletes) => athletes,
      orElse: () => const <Athlete>[],
    );
    final List<Event> events = eventState.maybeWhen(
      loaded: (events) => events,
      orElse: () => const <Event>[],
    );
    final theme = Theme.of(context);

    final frameDuration = Duration(
      milliseconds: (1000 / measureState.fps).round(),
    );
    final hasVideo = videoState.isInitialized && videoState.controller != null;
    final hasPositions =
        measureState.startPosition != null || measureState.endPosition != null;
    final selectedAthleteId =
        athletes.any((athlete) => athlete.id == measureState.athleteId)
        ? measureState.athleteId
        : null;
    if (athletes.isNotEmpty &&
        (measureState.athleteId == null || measureState.athleteName.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final selected = athletes.first;
        ref
            .read(measurementProvider.notifier)
            .setAthlete(athleteId: selected.id, athleteName: selected.name);
      });
    }
    final selectedEventId =
        events.any((event) => event.id == measureState.eventId)
        ? measureState.eventId
        : null;
    if (events.isNotEmpty && measureState.eventType.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final selected = events.first;
        ref
            .read(measurementProvider.notifier)
            .setEvent(eventId: selected.id, eventName: selected.name);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('計測'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _onBack(context),
        ),
      ),
      body: videoState.error != null
          ? Center(child: Text(videoState.error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  // ── 動画プレビューセクション ──
                  _MeasurementSectionCard(
                    title: '動画プレビュー',
                    icon: Icons.videocam,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ダーク背景コンテナ
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
                              transformationController: _videoZoomController,
                              onTap: () => ref
                                  .read(videoPlayerProvider.notifier)
                                  .togglePlay(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (hasVideo) ...[
                          Row(
                            children: [
                              Text(
                                'ピンチで拡大縮小',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  _videoZoomController.value =
                                      Matrix4.identity();
                                },
                                icon: const Icon(Icons.fit_screen, size: 16),
                                label: const Text('リセット'),
                              ),
                            ],
                          ),
                          // シークスライダー
                          Slider(
                            value: videoState.currentPosition.inMilliseconds
                                .toDouble()
                                .clamp(
                                  0,
                                  videoState.totalDuration.inMilliseconds
                                      .toDouble(),
                                ),
                            max: videoState.totalDuration.inMilliseconds
                                .toDouble()
                                .clamp(1, double.infinity),
                            onChanged: (value) {
                              ref
                                  .read(videoPlayerProvider.notifier)
                                  .seekTo(
                                    Duration(milliseconds: value.round()),
                                  );
                            },
                          ),
                          // タイムスタンプ
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              videoState.currentPosition.toTimestamp(),
                              style: AppTextStyles.timeDisplaySmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // シークコントロール
                          SeekControls(
                            isPlaying: videoState.isPlaying,
                            fps: measureState.fps,
                            onSeekBackward100ms: () => ref
                                .read(videoPlayerProvider.notifier)
                                .seekBackward(
                                  const Duration(milliseconds: 100),
                                ),
                            onSeekBackward1Frame: () => ref
                                .read(videoPlayerProvider.notifier)
                                .seekBackward(frameDuration),
                            onTogglePlay: () => ref
                                .read(videoPlayerProvider.notifier)
                                .togglePlay(),
                            onSeekForward1Frame: () => ref
                                .read(videoPlayerProvider.notifier)
                                .seekForward(frameDuration),
                            onSeekForward100ms: () => ref
                                .read(videoPlayerProvider.notifier)
                                .seekForward(const Duration(milliseconds: 100)),
                          ),
                        ] else ...[
                          Text(
                            '動画が読み込まれていません。\n「動画を読み込む」から計測用の動画を選択してください。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () => context.pushNamed('videoImport'),
                            icon: const Icon(Icons.video_call),
                            label: const Text('動画を読み込む'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (hasVideo) ...[
                    const SizedBox(height: AppSpacing.lg),
                    // ── 計測コントロールセクション ──
                    _MeasurementSectionCard(
                      title: '計測コントロール',
                      icon: Icons.timer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '動画を再生して開始と終了のフレームを指定します。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // スタート/ストップボタン + 確定値
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // スタートボタン
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 56,
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.startColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(
                                                measurementProvider.notifier,
                                              )
                                              .setStartPosition(
                                                videoState.currentPosition,
                                              );
                                        },
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('スタート'),
                                      ),
                                    ),
                                    if (measureState.startPosition != null) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        measureState.startPosition!
                                            .toTimestamp(),
                                        style: AppTextStyles.timeDisplaySmall
                                            .copyWith(
                                              color: AppColors.startColor,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              // ストップボタン
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 56,
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.endColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(
                                                measurementProvider.notifier,
                                              )
                                              .setEndPosition(
                                                videoState.currentPosition,
                                              );
                                        },
                                        icon: const Icon(Icons.flag),
                                        label: const Text('ストップ'),
                                      ),
                                    ),
                                    if (measureState.endPosition != null) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        measureState.endPosition!.toTimestamp(),
                                        style: AppTextStyles.timeDisplaySmall
                                            .copyWith(
                                              color: AppColors.endColor,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // タイマー表示（ダークカード）
                          TimeDisplay(
                            startPosition: measureState.startPosition,
                            endPosition: measureState.endPosition,
                            calculatedTime: measureState.calculatedTime,
                            fps: measureState.fps,
                            onConfirmStart: () {
                              ref
                                  .read(measurementProvider.notifier)
                                  .setStartPosition(videoState.currentPosition);
                            },
                            onConfirmEnd: () {
                              ref
                                  .read(measurementProvider.notifier)
                                  .setEndPosition(videoState.currentPosition);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  // ── 計測情報の入力セクション ──
                  _MeasurementSectionCard(
                    title: '計測情報の入力',
                    icon: Icons.edit_note,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('FPSを選択', style: AppTextStyles.cardTitle),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: AppConstants.fpsOptions.map((fpsOption) {
                            final selected = measureState.fps == fpsOption;
                            return ChoiceChip(
                              label: Text('${fpsOption.toInt()} fps'),
                              selected: selected,
                              onSelected: (_) => ref
                                  .read(measurementProvider.notifier)
                                  .setFps(fpsOption),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (athletes.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '選手が登録されていません。管理タブから選手を追加してください。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedAthleteId),
                            decoration: _filledDecoration(
                              '選手',
                              icon: Icons.person,
                            ),
                            initialValue: selectedAthleteId,
                            items: athletes
                                .map(
                                  (athlete) => DropdownMenuItem<String>(
                                    value: athlete.id,
                                    child: Text(athlete.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final selected = athletes.firstWhere(
                                (athlete) => athlete.id == value,
                              );
                              ref
                                  .read(measurementProvider.notifier)
                                  .setAthlete(
                                    athleteId: selected.id,
                                    athleteName: selected.name,
                                  );
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (events.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '種目が登録されていません。管理タブから種目を追加してください。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey(selectedEventId),
                            initialValue: selectedEventId,
                            decoration: _filledDecoration(
                              '種目',
                              icon: Icons.flag,
                            ),
                            items: events
                                .map(
                                  (event) => DropdownMenuItem<String>(
                                    value: event.id,
                                    child: Text(event.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final selected = events.firstWhere(
                                (event) => event.id == value,
                              );
                              ref
                                  .read(measurementProvider.notifier)
                                  .setEvent(
                                    eventId: selected.id,
                                    eventName: selected.name,
                                  );
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          decoration: _filledDecoration(
                            'メモ',
                            icon: Icons.edit_note,
                            align: true,
                          ),
                          maxLength: AppConstants.maxMemoLength,
                          maxLines: 3,
                          onChanged: (value) => ref
                              .read(measurementProvider.notifier)
                              .setMemo(value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // アクションボタン横並び
                        Row(
                          children: [
                            if (hasPositions) ...[
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(measurementProvider.notifier)
                                          .resetPositions();
                                      _releaseVideoAndPushVideoImport(context);
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('続けて測定'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed:
                                      measureState.isSaving ||
                                          measureState.calculatedTime == null ||
                                          athletes.isEmpty ||
                                          events.isEmpty ||
                                          measureState.athleteId == null ||
                                          measureState.athleteName.isEmpty ||
                                          measureState.eventType.isEmpty
                                      ? null
                                      : () => _onSave(context),
                                  icon: measureState.isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: const Text('記録する'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // テキストリンクスタイル
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                _releaseVideoAndPushVideoImport(context),
                            child: const Text('別の動画を読み込む'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _onSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final record = await ref
          .read(measurementProvider.notifier)
          .saveRecord(videoPath: widget.videoPath);

      if (record != null && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('記録を保存しました')));
        await ref.read(videoPlayerProvider.notifier).release();
        if (!mounted) return;
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }
  }

  Future<void> _onBack(BuildContext context) async {
    final measureState = ref.read(measurementProvider);
    final hasData =
        measureState.startPosition != null ||
        measureState.endPosition != null ||
        measureState.athleteName.isNotEmpty;

    if (hasData) {
      final navigator = Navigator.of(context);
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認'),
          content: const Text('計測データが失われます。戻りますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('戻る'),
            ),
          ],
        ),
      );
      if (result == true && mounted) {
        await ref.read(videoPlayerProvider.notifier).release();
        if (!mounted) return;
        navigator.pop();
      }
    } else {
      final navigator = Navigator.of(context);
      await ref.read(videoPlayerProvider.notifier).release();
      if (!mounted) return;
      navigator.pop();
    }
  }

  Future<void> _releaseVideoAndPushVideoImport(BuildContext context) async {
    final router = GoRouter.of(context);
    await ref.read(videoPlayerProvider.notifier).release();
    if (!mounted) return;
    router.pushNamed('videoImport');
  }
}

class _MeasurementSectionCard extends StatelessWidget {
  const _MeasurementSectionCard({
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // CardTheme から 16dp角丸 + outline border を継承
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(title, style: AppTextStyles.sectionTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}
