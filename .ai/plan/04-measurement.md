# 04: 計測機能（コア機能）実装計画

## 概要

PhysiLogの中核機能。スマホで撮影した動画を再生し、開始フレームと終了フレームを手動で確定してタイムを算出する。スポーツ体力測定の正確な計時を実現する。

---

## 対応する機能要件

| 要件ID | 内容 | 優先度 |
|--------|------|--------|
| F-10 | フレーム精度シーク（0.1秒刻み、可能ならフレーム単位） | 必須 |
| F-11 | 「開始確定」「終了確定」ボタン | 必須 |
| F-12 | タイム算出（endMs - startMs） | 必須 |
| F-13 | 開始/終了の再設定 | 必須 |
| F-14 | 計測精度表示（FPS基準） | 必須 |
| F-15 | 計測ルールメモ | 任意 |

---

## 技術的注意事項: 可変フレームレート（VFR）対応

### 問題

スマホで撮影した動画は**可変フレームレート（VFR）**であることが多い。フレーム番号ベースの計算では正確な実時間が得られない。

### 方針

- **フレーム番号ではなく再生位置タイムスタンプ（実時間）基準**で計測する
- `video_player` の `position` プロパティ（`Duration` 型）を使用
- タイム算出: `endPosition.inMilliseconds - startPosition.inMilliseconds`

### FPS取得方法と精度表示

```dart
// video_player からは直接FPSを取得できないため、以下の方法で対応

// 方法1: ffprobe等のメタデータから取得（flutter_ffmpeg利用時）
// 方法2: 一般的な値（30fps/60fps）をユーザーが選択
// 方法3: 短い区間のフレーム数から推定

// 精度表示の計算
// 60fps → ±16.7ms (1000ms / 60)
// 30fps → ±33.3ms (1000ms / 30)
// 120fps → ±8.3ms (1000ms / 120)
double calculatePrecision(double fps) => 1000.0 / fps;
```

### MVP方針

- FPSはユーザーが手動選択（30fps / 60fps / 120fps / 240fps）
- 将来的にメタデータからの自動取得を検討

---

## UI設計

### 計測画面レイアウト

```
┌──────────────────────────────────┐
│          動画プレイヤー            │
│     （タップで再生/停止）          │
│                                  │
│                                  │
├──────────────────────────────────┤
│ [<<0.1s] [<1f] ▶/⏸ [1f>] [0.1s>>] │  ← シークコントロール
├──────────────────────────────────┤
│  ━━━━━━━●━━━━━━━━━━━━━━━━━━━━━  │  ← シークバー
│  現在位置: 00:03.245              │
├──────────────────────────────────┤
│  開始: --:--.---     [確定]       │
│  終了: --:--.---     [確定]       │
│  ─────────────────────           │
│  タイム: --.--- 秒                │
│  精度: ±16.7ms (60fps)           │
├──────────────────────────────────┤
│  FPS: [30] [60] [120] [240]      │  ← FPS選択トグル
├──────────────────────────────────┤
│  メモ: ________________________   │  ← 計測ルールメモ（F-15）
├──────────────────────────────────┤
│          [保存]                   │
└──────────────────────────────────┘
```

### ユーザーインタラクション

1. 動画が読み込まれた状態で画面が開く
2. 再生/停止でおおよその位置を探す
3. シークコントロールで微調整
4. 「開始確定」ボタンで開始位置を記録
5. 同様に終了位置を探して「終了確定」ボタンで記録
6. タイムが自動算出される
7. 必要に応じて再設定（F-13）
8. 「保存」で記録を保存

### シークコントロールの動作

| ボタン | 動作 | 移動量 |
|--------|------|--------|
| `<<0.1s` | 0.1秒戻る | -100ms |
| `<1f` | 1フレーム戻る | -(1000/fps)ms |
| `▶/⏸` | 再生/停止 | - |
| `1f>` | 1フレーム進む | +(1000/fps)ms |
| `0.1s>>` | 0.1秒進む | +100ms |

---

## 状態管理（Riverpod）

### MeasurementState

```dart
@freezed
class MeasurementState with _$MeasurementState {
  const factory MeasurementState({
    Duration? startPosition,    // 開始位置（null = 未確定）
    Duration? endPosition,      // 終了位置（null = 未確定）
    Duration? calculatedTime,   // 算出タイム
    @Default(60.0) double fps,  // 動画のFPS
    @Default('') String memo,   // 計測ルールメモ
  }) = _MeasurementState;
}
```

### プロバイダー構成

```dart
// 計測状態の管理
@riverpod
class MeasurementNotifier extends _$MeasurementNotifier {
  @override
  MeasurementState build() => const MeasurementState();

  /// 開始位置を確定
  void setStartPosition(Duration position) {
    state = state.copyWith(startPosition: position);
    _recalculateTime();
  }

  /// 終了位置を確定
  void setEndPosition(Duration position) {
    state = state.copyWith(endPosition: position);
    _recalculateTime();
  }

  /// 開始位置をリセット（F-13）
  void resetStartPosition() {
    state = state.copyWith(startPosition: null, calculatedTime: null);
  }

  /// 終了位置をリセット（F-13）
  void resetEndPosition() {
    state = state.copyWith(endPosition: null, calculatedTime: null);
  }

  /// FPSを設定
  void setFps(double fps) {
    state = state.copyWith(fps: fps);
  }

  /// メモを設定（F-15）
  void setMemo(String memo) {
    state = state.copyWith(memo: memo);
  }

  /// タイム再計算
  void _recalculateTime() {
    final start = state.startPosition;
    final end = state.endPosition;
    if (start != null && end != null) {
      final diff = end - start;
      state = state.copyWith(
        calculatedTime: diff.isNegative ? null : diff,
      );
    }
  }

  /// 計測精度を取得（ミリ秒）
  double get precisionMs => 1000.0 / state.fps;
}

// 動画プレイヤー制御
@riverpod
class VideoPlayerNotifier extends _$VideoPlayerNotifier {
  VideoPlayerController? _controller;

  @override
  AsyncValue<VideoPlayerController> build(String videoPath) {
    // コントローラーの初期化
  }

  /// 指定位置にシーク
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  /// フレーム単位でシーク
  Future<void> seekByFrames(int frames, double fps) async {
    final current = _controller?.value.position ?? Duration.zero;
    final frameDuration = Duration(
      microseconds: (1000000 / fps).round(),
    );
    final target = current + frameDuration * frames;
    await seekTo(target);
  }

  /// 0.1秒単位でシーク
  Future<void> seekByMilliseconds(int ms) async {
    final current = _controller?.value.position ?? Duration.zero;
    final target = current + Duration(milliseconds: ms);
    await seekTo(target);
  }
}
```

---

## シーク精度の実装

### `seekTo()` の精度とOS差異

| 項目 | iOS | Android |
|------|-----|---------|
| シーク精度 | キーフレーム単位が基本 | コーデック依存 |
| フレーム精度シーク | AVPlayerのステップ機能で対応可 | MediaCodecのシーク精度に依存 |
| 遅延 | 比較的低遅延 | デバイスにより差あり |

### フォールバック戦略

```dart
/// シーク精度に関するフォールバック戦略
///
/// 1. まず seekTo() で指定位置にシーク
/// 2. シーク後の実際の position を取得
/// 3. 差異が大きい場合（1フレーム以上）はユーザーに通知
/// 4. 確定時は実際の position を使用（seekTo の引数ではなく）
Future<Duration> preciseSeek(Duration target) async {
  await controller.seekTo(target);

  // シーク完了を待つ
  await Future.delayed(const Duration(milliseconds: 50));

  // 実際のポジションを取得
  final actual = controller.value.position;

  // 差異を検出
  final diff = (target - actual).abs();
  if (diff > Duration(microseconds: (1000000 / fps).round())) {
    // ユーザーに精度の注意を表示
    _showPrecisionWarning(target, actual);
  }

  return actual; // 実際のポジションを返す
}
```

### iOS固有の最適化（将来検討）

```
// iOS の AVPlayer にはフレーム単位ステップ機能がある
// Flutter プラグインのカスタム実装で対応可能
// - currentItem.step(byCount: 1)  // 1フレーム進む
// - currentItem.step(byCount: -1) // 1フレーム戻る
```

---

## パフォーマンス考慮

### N-01: シーク操作の遅延最小化

- シークバー操作中は動画フレームのリアルタイム更新を行う
- デバウンス処理でシーク命令の頻度を制御（50ms間隔）
- シーク中はオーバーレイUIの更新を優先

### サムネイルキャッシュ（オプション・MVP後）

```dart
/// シークバー上にサムネイルプレビューを表示する機能
/// MVP後の改善として検討
///
/// 実装方針:
/// - 動画読み込み時に一定間隔でサムネイルを生成
/// - LRUキャッシュで保持
/// - シークバーホバー時にサムネイルを表示
```

### メモリ管理

- 動画コントローラーは画面破棄時に確実にdispose
- 大きな動画ファイルへの対応（プログレッシブ読み込み）
- バックグラウンド遷移時のリソース解放

---

## ファイル構成（予定）

```
lib/
├── features/
│   └── measurement/
│       ├── domain/
│       │   └── measurement_state.dart       # 計測状態モデル
│       ├── application/
│       │   ├── measurement_notifier.dart     # 計測状態管理
│       │   └── video_player_notifier.dart    # 動画プレイヤー管理
│       └── presentation/
│           ├── measurement_screen.dart       # 計測画面
│           ├── widgets/
│           │   ├── video_player_widget.dart   # 動画プレイヤーウィジェット
│           │   ├── seek_controls.dart         # シークコントロール
│           │   ├── time_display.dart          # タイム表示
│           │   ├── position_marker.dart       # 開始/終了マーカー
│           │   └── fps_selector.dart          # FPS選択
│           └── measurement_screen.dart
```

---

## 実装順序

1. **Phase 1**: 動画プレイヤーの基本表示と再生/停止
2. **Phase 2**: シークバーと現在位置表示
3. **Phase 3**: シークコントロール（0.1秒/フレーム単位）
4. **Phase 4**: 開始/終了確定ボタンとタイム算出（F-11, F-12）
5. **Phase 5**: 再設定機能（F-13）
6. **Phase 6**: FPS選択と精度表示（F-14）
7. **Phase 7**: 計測ルールメモ（F-15）
8. **Phase 8**: 保存処理（記録管理機能と連携）

---

## テスト方針

### ユニットテスト

- `MeasurementState` のタイム算出ロジック
- 精度計算（FPSから±ms）
- シーク量の計算（フレーム数→Duration変換）
- エッジケース: 開始 > 終了の場合のバリデーション

### ウィジェットテスト

- シークコントロールのボタン動作
- 開始/終了確定ボタンの状態遷移
- タイム表示のフォーマット

### 統合テスト

- 動画読み込み→シーク→確定→保存の一連の流れ
- 再設定フローの動作確認

---

## 既知の制約事項

1. `video_player` パッケージはフレーム単位の精密なシークを保証しない
2. VFR動画ではフレーム単位シークの精度が低下する可能性がある
3. Android端末ではシーク精度にハードウェア依存の差異がある
4. 非常に高FPS（240fps）の動画では `seekTo()` の粒度が不足する可能性がある
5. 上記制約を踏まえ、確定時は `seekTo` の引数ではなく実際の `position` 値を使用する
