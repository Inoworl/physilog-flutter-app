import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final theme = Theme.of(context);

    final frameDuration = Duration(
      milliseconds: (1000 / measureState.fps).round(),
    );
    final hasVideo = videoState.isInitialized && videoState.controller != null;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  _MeasurementSectionCard(
                    title: '動画プレビュー',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: VideoPlayerWidget(
                            controller: videoState.controller,
                            isInitialized: videoState.isInitialized,
                            isPlaying: videoState.isPlaying,
                            onTap: () => ref
                                .read(videoPlayerProvider.notifier)
                                .togglePlay(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (hasVideo) ...[
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              videoState.currentPosition.toTimestamp(),
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    _MeasurementSectionCard(
                      title: '計測コントロール',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '動画を再生して開始と終了のフレームを指定します。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(measurementProvider.notifier)
                                        .setStartPosition(
                                          videoState.currentPosition,
                                        );
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('スタート'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(measurementProvider.notifier)
                                        .setEndPosition(
                                          videoState.currentPosition,
                                        );
                                  },
                                  icon: const Icon(Icons.flag),
                                  label: const Text('ストップ'),
                                ),
                              ),
                            ],
                          ),
                          if (measureState.startPosition != null ||
                              measureState.endPosition != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(measurementProvider.notifier)
                                  .resetPositions(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('続けて測定する'),
                            ),
                          ],
                          const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  _MeasurementSectionCard(
                    title: '計測情報の入力',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('FPSを選択', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                        const SizedBox(height: 16),
                        TextField(
                          decoration: _filledDecoration(
                            '選手名',
                            icon: Icons.person,
                          ),
                          maxLength: AppConstants.maxAthleteNameLength,
                          onChanged: (value) => ref
                              .read(measurementProvider.notifier)
                              .setAthleteName(value),
                        ),
                        const SizedBox(height: 12),
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return AppConstants.eventSuggestions;
                            }
                            return AppConstants.eventSuggestions.where(
                              (option) =>
                                  option.contains(textEditingValue.text),
                            );
                          },
                          onSelected: (selection) {
                            ref
                                .read(measurementProvider.notifier)
                                .setEventType(selection);
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: _filledDecoration(
                                    '種目',
                                    icon: Icons.flag,
                                  ),
                                  maxLength: AppConstants.maxEventTypeLength,
                                  onChanged: (value) => ref
                                      .read(measurementProvider.notifier)
                                      .setEventType(value),
                                );
                              },
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed:
                              measureState.isSaving ||
                                  measureState.calculatedTime == null ||
                                  measureState.athleteName.isEmpty ||
                                  measureState.eventType.isEmpty
                              ? null
                              : () => _onSave(context),
                          child: measureState.isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('記録する'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => context.pushNamed('videoImport'),
                          child: const Text('別の動画を読み込む'),
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
        navigator.pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }
}

class _MeasurementSectionCard extends StatelessWidget {
  const _MeasurementSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
