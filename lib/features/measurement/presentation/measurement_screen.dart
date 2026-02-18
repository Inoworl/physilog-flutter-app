import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ref.read(videoPlayerProvider.notifier).initializeVideo(widget.videoPath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final measureState = ref.watch(measurementProvider);
    final theme = Theme.of(context);

    final frameDuration = Duration(
      milliseconds: (1000 / measureState.fps).round(),
    );

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
              child: Column(
                children: [
                  // 動画プレイヤー
                  VideoPlayerWidget(
                    controller: videoState.controller,
                    isInitialized: videoState.isInitialized,
                    isPlaying: videoState.isPlaying,
                    onTap: () =>
                        ref.read(videoPlayerProvider.notifier).togglePlay(),
                  ),

                  // シークバー
                  if (videoState.isInitialized) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
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
                              ref.read(videoPlayerProvider.notifier).seekTo(
                                    Duration(milliseconds: value.round()),
                                  );
                            },
                          ),
                          Text(
                            videoState.currentPosition.toTimestamp(),
                            style: const TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // シークコントロール
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SeekControls(
                        isPlaying: videoState.isPlaying,
                        fps: measureState.fps,
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
                    ),

                    const Divider(),

                    // 計測結果表示
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TimeDisplay(
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
                    ),

                    // 再設定ボタン
                    if (measureState.startPosition != null ||
                        measureState.endPosition != null)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(measurementProvider.notifier).resetPositions(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('再設定'),
                      ),

                    const Divider(),

                    // FPS選択
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text('FPS:', style: theme.textTheme.bodyMedium),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<double>(
                              segments: AppConstants.fpsOptions
                                  .map((fps) => ButtonSegment(
                                        value: fps,
                                        label: Text('${fps.toInt()}'),
                                      ))
                                  .toList(),
                              selected: {measureState.fps},
                              onSelectionChanged: (values) {
                                ref
                                    .read(measurementProvider.notifier)
                                    .setFps(values.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 入力フォーム
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: '選手名',
                              border: OutlineInputBorder(),
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
                                (option) => option.contains(textEditingValue.text),
                              );
                            },
                            onSelected: (selection) {
                              ref
                                  .read(measurementProvider.notifier)
                                  .setEventType(selection);
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: '種目',
                                  border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'メモ',
                              border: OutlineInputBorder(),
                            ),
                            maxLength: AppConstants.maxMemoLength,
                            maxLines: 3,
                            onChanged: (value) => ref
                                .read(measurementProvider.notifier)
                                .setMemo(value),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 保存ボタン
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: measureState.isSaving ||
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
                              : const Text('保存'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
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
        messenger.showSnackBar(
          const SnackBar(content: Text('記録を保存しました')),
        );
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _onBack(BuildContext context) async {
    final measureState = ref.read(measurementProvider);
    final hasData = measureState.startPosition != null ||
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
