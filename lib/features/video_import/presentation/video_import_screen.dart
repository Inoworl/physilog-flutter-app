import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    final isPicking = importState is VideoImportPicking;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('動画取り込み')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.videocam_outlined,
                  size: 40,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '計測する動画を選択してください',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _ActionCard(
                icon: Icons.camera_alt,
                title: 'カメラで撮影する',
                subtitle: '今すぐ撮影して計測',
                onTap: isPicking
                    ? null
                    : () => ref
                          .read(videoImportProvider.notifier)
                          .pickFromCamera(),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionCard(
                icon: Icons.photo_library,
                title: 'アルバムから選択する',
                subtitle: '保存済みの動画から選択',
                onTap: isPicking
                    ? null
                    : () => ref
                          .read(videoImportProvider.notifier)
                          .pickFromGallery(),
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
          final progress = state is VideoImportCompressing
              ? state.progress
              : 0.0;
          return CompressProgressDialog(progress: progress);
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
                    Text(
                      title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: isDisabled
                            ? colorScheme.onSurface.withValues(alpha: 0.38)
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDisabled
                            ? colorScheme.onSurface.withValues(alpha: 0.38)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDisabled
                    ? colorScheme.onSurface.withValues(alpha: 0.38)
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
