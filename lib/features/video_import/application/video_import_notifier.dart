import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';

// 動画取り込み状態
sealed class VideoImportState {
  const VideoImportState();
}

class VideoImportInitial extends VideoImportState {
  const VideoImportInitial();
}

class VideoImportPicking extends VideoImportState {
  const VideoImportPicking();
}

class VideoImportCompressing extends VideoImportState {
  const VideoImportCompressing({required this.progress});
  final double progress;
}

class VideoImportCompleted extends VideoImportState {
  const VideoImportCompleted({required this.filePath});
  final String filePath;
}

class VideoImportError extends VideoImportState {
  const VideoImportError({required this.message});
  final String message;
}

class VideoImportNotifier extends StateNotifier<VideoImportState> {
  VideoImportNotifier() : super(const VideoImportInitial());

  final _picker = ImagePicker();
  Subscription? _compressSubscription;

  Future<void> pickFromCamera() async {
    // カメラ権限チェック
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      state = const VideoImportError(message: 'カメラの権限が許可されていません');
      return;
    }

    state = const VideoImportPicking();

    try {
      final video = await _picker.pickVideo(source: ImageSource.camera);

      if (video == null) {
        state = const VideoImportInitial();
        return;
      }

      await _processVideo(video.path);
    } catch (e) {
      state = VideoImportError(message: '動画の撮影に失敗しました: $e');
    }
  }

  Future<void> pickFromGallery() async {
    state = const VideoImportPicking();

    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video == null) {
        state = const VideoImportInitial();
        return;
      }

      await _processVideo(video.path);
    } catch (e) {
      state = VideoImportError(message: '動画の選択に失敗しました: $e');
    }
  }

  Future<void> _processVideo(String sourcePath) async {
    await _compressVideo(sourcePath);
  }

  Future<void> _compressVideo(String sourcePath) async {
    state = const VideoImportCompressing(progress: 0);

    _compressSubscription = VideoCompress.compressProgress$.subscribe((
      progress,
    ) {
      state = VideoImportCompressing(progress: progress);
    });

    try {
      final result = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        includeAudio: false,
      );

      if (result == null || result.file == null) {
        state = const VideoImportError(message: '動画の圧縮に失敗しました');
        return;
      }

      // アプリ固有ディレクトリに保存
      final appDir = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${appDir.path}/videos');
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${videoDir.path}/video_$timestamp.mp4';
      final savedFile = await result.file!.copy(destPath);

      // 圧縮一時ファイル削除
      await result.file!.delete().catchError((_) => result.file!);

      state = VideoImportCompleted(filePath: savedFile.path);
    } catch (e) {
      state = VideoImportError(message: '動画の圧縮に失敗しました: $e');
    } finally {
      _compressSubscription?.unsubscribe();
      _compressSubscription = null;
    }
  }

  void reset() {
    state = const VideoImportInitial();
  }

  @override
  void dispose() {
    _compressSubscription?.unsubscribe();
    VideoCompress.cancelCompression();
    super.dispose();
  }
}

final videoImportProvider =
    StateNotifierProvider.autoDispose<VideoImportNotifier, VideoImportState>(
      (ref) => VideoImportNotifier(),
    );
