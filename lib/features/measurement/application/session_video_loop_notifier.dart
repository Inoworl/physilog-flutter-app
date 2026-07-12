import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/features/measurement/application/measurement_notifier.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/application/video_player_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/video_import/application/video_import_notifier.dart';

/// 動画ループの段階。動画を選ぶ → フレームを計測する、の2段。
enum SessionVideoLoopStep { pickVideo, measuring }

/// [SessionVideoLoopNotifier] の状態。
///
/// フィールドが少ないため copyWith は持たず、遷移のたびに全フィールドを
/// 明示して新しいインスタンスを作る（videoPath を null に戻す遷移があり、
/// `??` によるマージだと null を渡せなくなるため）。
class SessionVideoLoopState {
  const SessionVideoLoopState({
    this.step = SessionVideoLoopStep.pickVideo,
    this.videoPath,
    this.isSaving = false,
  });

  final SessionVideoLoopStep step;
  final String? videoPath;

  /// `recordAttempt` 実行中かどうか。二重実行防止のガードに使う。
  final bool isSaving;
}

/// 計測会モード（動画種目）の連続計測ループの状態・副作用を管理する。
///
/// [SessionVideoLoop] Widget は状態表示とユーザー操作の委譲に絞り、
/// 動画取り込み完了時の初期化・保存・次の動画への遷移・手入力切替前の
/// 解放など、BuildContext に依存しない処理はすべてここに寄せる
/// （`measurement_session_notifier.dart` と同じ方針）。
class SessionVideoLoopNotifier extends StateNotifier<SessionVideoLoopState> {
  SessionVideoLoopNotifier(this._ref, this._args)
    : super(const SessionVideoLoopState());

  final Ref _ref;
  final SessionArgs _args;

  /// 動画取り込み完了時のユースケース：計測状態の初期化 → 動画初期化 →
  /// 取り込み状態のリセット → 計測ステップへ遷移。
  ///
  /// `VideoImportScreen`（単発計測）と同じ手順をここに一本化し、動画初期化
  /// 手順が変わったときの修正漏れを防ぐ。
  Future<void> handleImportCompleted(String filePath) async {
    _ref.read(measurementProvider.notifier).resetPositions();
    await _ref.read(videoPlayerProvider.notifier).initializeVideo(filePath);
    _ref.read(videoImportProvider.notifier).reset();
    if (!mounted) return;
    state = SessionVideoLoopState(
      step: SessionVideoLoopStep.measuring,
      videoPath: filePath,
      isSaving: state.isSaving,
    );
  }

  /// 1試技を記録する。保存中は二重実行を防ぐため何もせず null を返す。
  Future<BestAttemptDecision?> recordAttempt({
    required String athleteId,
    required String athleteName,
    required double value,
    required double fps,
    bool forceAdopt = false,
  }) async {
    if (state.isSaving) return null;
    state = SessionVideoLoopState(
      step: state.step,
      videoPath: state.videoPath,
      isSaving: true,
    );
    try {
      final decision = await _ref
          .read(measurementSessionProvider(_args).notifier)
          .recordAttempt(
            athleteId: athleteId,
            athleteName: athleteName,
            value: value,
            videoRef: state.videoPath,
            fps: fps,
            forceAdopt: forceAdopt,
          );
      _ref.invalidate(recordListNotifierProvider);
      return decision;
    } finally {
      if (mounted) {
        state = SessionVideoLoopState(
          step: state.step,
          videoPath: state.videoPath,
          isSaving: false,
        );
      }
    }
  }

  /// 動画プレイヤーを解放し、次の動画選択へ戻る。
  Future<void> resetForNextVideo() async {
    await _ref.read(videoPlayerProvider.notifier).release();
    _ref.read(measurementProvider.notifier).resetPositions();
    if (!mounted) return;
    state = SessionVideoLoopState(
      step: SessionVideoLoopStep.pickVideo,
      videoPath: null,
      isSaving: state.isSaving,
    );
  }

  /// 手入力に切り替える前に、動画プレイヤーを解放し計測状態をリセットする。
  Future<void> prepareSwitchToManual() async {
    await _ref.read(videoPlayerProvider.notifier).release();
    _ref.read(measurementProvider.notifier).resetPositions();
  }
}

final sessionVideoLoopProvider = StateNotifierProvider.autoDispose
    .family<SessionVideoLoopNotifier, SessionVideoLoopState, SessionArgs>((
      ref,
      args,
    ) {
      return SessionVideoLoopNotifier(ref, args);
    });
