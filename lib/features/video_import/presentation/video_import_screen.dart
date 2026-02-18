import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:physi_log/features/video_import/application/video_import_notifier.dart';
import 'package:physi_log/features/video_import/presentation/widgets/compress_progress_dialog.dart';

class VideoImportScreen extends ConsumerStatefulWidget {
  const VideoImportScreen({super.key});

  @override
  ConsumerState<VideoImportScreen> createState() => _VideoImportScreenState();
}

class _VideoImportScreenState extends ConsumerState<VideoImportScreen> {
  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(videoImportProvider);

    ref.listen<VideoImportState>(videoImportProvider, (prev, next) {
      // 圧縮中ダイアログ
      if (next is VideoImportCompressing && prev is! VideoImportCompressing) {
        _showCompressDialog(context);
      }

      // 圧縮完了 → ダイアログ閉じて遷移
      if (next is VideoImportCompleted) {
        if (prev is VideoImportCompressing) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        context.push('/measure', extra: {'videoPath': next.filePath});
        // リセット
        ref.read(videoImportProvider.notifier).reset();
      }

      // エラー → ダイアログ閉じてSnackBar
      if (next is VideoImportError) {
        if (prev is VideoImportCompressing) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    final isPicking = importState is VideoImportPicking;

    return Scaffold(
      appBar: AppBar(title: const Text('動画取り込み')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_outlined,
                size: 96,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 32),
              Text(
                '計測する動画を選択してください',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isPicking
                      ? null
                      : () => ref.read(videoImportProvider.notifier).pickFromCamera(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('カメラで撮影'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: isPicking
                      ? null
                      : () => ref.read(videoImportProvider.notifier).pickFromGallery(),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('アルバムから選択'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(videoImportProvider);
          final progress =
              state is VideoImportCompressing ? state.progress : 0.0;
          return CompressProgressDialog(progress: progress);
        },
      ),
    );
  }
}
