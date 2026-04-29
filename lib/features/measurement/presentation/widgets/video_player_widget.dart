import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatelessWidget {
  const VideoPlayerWidget({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.isPlaying,
    required this.onTap,
    this.transformationController,
  });

  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool isPlaying;
  final VoidCallback onTap;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context) {
    if (!isInitialized || controller == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return InteractiveViewer(
      transformationController: transformationController,
      clipBehavior: Clip.hardEdge,
      minScale: 1,
      maxScale: 4,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: VideoPlayer(controller!),
        ),
      ),
    );
  }
}
