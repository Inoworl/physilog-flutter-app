import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerState {
  const VideoPlayerState({
    this.controller,
    this.isInitialized = false,
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.error,
  });

  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? error;

  VideoPlayerState copyWith({
    VideoPlayerController? controller,
    bool? isInitialized,
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    String? error,
  }) {
    return VideoPlayerState(
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      error: error,
    );
  }
}

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier() : super(const VideoPlayerState());

  Future<void> initializeVideo(String path) async {
    // 既存コントローラ破棄
    await state.controller?.dispose();

    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();

      controller.addListener(_onVideoUpdate);

      state = VideoPlayerState(
        controller: controller,
        isInitialized: true,
        totalDuration: controller.value.duration,
        currentPosition: Duration.zero,
      );
    } catch (e) {
      state = VideoPlayerState(error: '動画の読み込みに失敗しました: $e');
    }
  }

  void _onVideoUpdate() {
    final controller = state.controller;
    if (controller == null || !mounted) return;

    state = state.copyWith(
      isPlaying: controller.value.isPlaying,
      currentPosition: controller.value.position,
    );
  }

  Future<void> play() async {
    await state.controller?.play();
  }

  Future<void> pause() async {
    await state.controller?.pause();
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    final controller = state.controller;
    if (controller == null) return;

    // 範囲制限
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        state.totalDuration.inMilliseconds,
      ),
    );

    await controller.seekTo(clamped);
    state = state.copyWith(currentPosition: clamped);
  }

  Future<void> seekForward(Duration amount) async {
    await seekTo(state.currentPosition + amount);
  }

  Future<void> seekBackward(Duration amount) async {
    await seekTo(state.currentPosition - amount);
  }

  @override
  void dispose() {
    state.controller?.removeListener(_onVideoUpdate);
    state.controller?.dispose();
    super.dispose();
  }
}

final videoPlayerProvider =
    StateNotifierProvider.autoDispose<VideoPlayerNotifier, VideoPlayerState>(
  (ref) => VideoPlayerNotifier(),
);
