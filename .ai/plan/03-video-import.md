# 03. 動画取り込み機能 実装計画

## 概要

スマホで撮影した動画、またはアルバムから選択した動画をアプリに取り込み、計測用に圧縮・保存する機能。計測用途のため低画質で十分であり、容量削減を優先する。

---

## 1. 機能要件対応

| 要件ID | 要件 | 対応方針 |
|---|---|---|
| F-01 | カメラ撮影 / アルバム選択 | `image_picker` でカメラ撮影とギャラリー選択の両方に対応 |
| F-02 | 画質削減 | 720p以下 / 30fps に圧縮。計測用途なので低画質で十分 |
| F-03 | 動画保存方針 | 方針A（端末内のみ保持）を採用。クラウドアップロードしない |

---

## 2. 技術実装方針

### 2.1 動画取得パッケージ

**採用: `image_picker`**

- カメラ撮影とギャラリー選択の両方を単一パッケージで対応可能
- Flutter 公式推奨パッケージであり、メンテナンスが安定
- iOS / Android 両対応

```dart
// 依存パッケージ
dependencies:
  image_picker: ^1.0.0
```

#### `camera` パッケージとの比較

| 比較項目 | image_picker | camera |
|---|---|---|
| 実装コスト | 低（OS標準UIを利用） | 高（カスタムUI構築が必要） |
| カスタマイズ性 | 低 | 高 |
| 撮影中のオーバーレイ | 不可 | 可能 |
| 本アプリでの適性 | 十分（撮影後に計測するため） | オーバースペック |

**判断**: 本アプリは撮影後にフレーム確定を行うため、撮影時のカスタムUIは不要。`image_picker` で十分。

### 2.2 動画圧縮

**採用: `video_compress`**

- Flutter 向けの軽量な動画圧縮パッケージ
- 解像度・品質の指定が簡単
- iOS / Android 両対応

```dart
// 依存パッケージ
dependencies:
  video_compress: ^3.1.0
```

#### `ffmpeg_kit_flutter` との比較

| 比較項目 | video_compress | ffmpeg_kit_flutter |
|---|---|---|
| パッケージサイズ | 小 | 大（FFmpegバイナリ同梱） |
| API | Dart ネイティブ | コマンドライン形式 |
| カスタマイズ性 | 中 | 高（FFmpeg の全機能利用可能） |
| 本アプリでの適性 | 十分 | オーバースペック |

**判断**: 単純な解像度・FPS変換のみであり、`video_compress` で十分。将来的に高度な変換が必要になった場合に `ffmpeg_kit_flutter` へ移行する。

### 2.3 圧縮設定

```dart
import 'package:video_compress/video_compress.dart';

/// 計測用動画の圧縮設定
class VideoCompressConfig {
  /// 最大解像度: 720p
  static const VideoQuality quality = VideoQuality.MediumQuality;

  /// フレームレート: 30fps（元動画のFPSを保持したい場合は null）
  /// 注意: 高FPS（120fps, 240fps）の動画は圧縮せずFPSを保持する選択肢も提供
  static const int? frameRate = null; // FPS保持（計測精度のため）

  /// 動画の最大長（秒）
  static const int maxDurationSeconds = 30;
}
```

#### FPS に関する重要な注意点

計測精度に直接影響するため、FPS の扱いは慎重に行う。

- **30fps**: 1フレーム = 約33.3ms の精度
- **60fps**: 1フレーム = 約16.7ms の精度
- **120fps**: 1フレーム = 約8.3ms の精度
- **240fps**: 1フレーム = 約4.2ms の精度

**方針**: 解像度は下げるが、FPS はできるだけ元動画を保持する。ユーザーに圧縮オプションを提示する。

```
圧縮オプション:
├── 標準圧縮（720p, FPS保持）  ← デフォルト
└── 最大圧縮（720p, 30fps）    ← 容量優先の場合
```

### 2.4 保存先

```dart
import 'package:path_provider/path_provider.dart';

/// 動画ファイルの保存先ディレクトリを取得
Future<Directory> getVideoStorageDirectory() async {
  final appDir = await getApplicationDocumentsDirectory();
  final videoDir = Directory('${appDir.path}/videos');
  if (!await videoDir.exists()) {
    await videoDir.create(recursive: true);
  }
  return videoDir;
}
```

### 2.5 ファイル命名規則

```
measurement_{timestamp}.mp4

例: measurement_1708234567890.mp4
```

- `timestamp`: ミリ秒単位のUnixタイムスタンプ
- 拡張子: 常に `.mp4`（圧縮後のフォーマット）
- 衝突回避: タイムスタンプで十分だが、万が一の衝突時はサフィックス `_1`, `_2` を付与

```dart
/// 動画ファイル名を生成
String generateVideoFileName() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'measurement_$timestamp.mp4';
}
```

---

## 3. 容量管理

### 3.1 N-02 対応: 古い動画の削除導線

一定期間経過した動画に対して、削除を促す通知・UI を提供する。

#### 削除ポリシー

- 30日以上経過した動画: 一覧画面にバッジ表示
- 90日以上経過した動画: 削除推奨ダイアログを表示（アプリ起動時）
- 手動削除: いつでも個別に削除可能

#### 削除時の動作

```
動画削除フロー:
1. ユーザーが削除を選択
2. 確認ダイアログ表示（「計測記録は残りますが、動画は削除されます」）
3. ユーザー確認後、動画ファイルを物理削除
4. records.videoRef を null に更新
5. 完了通知
```

### 3.2 使用容量の表示（オプション）

設定画面に動画使用容量の表示機能を提供する。

```dart
/// 動画ストレージの使用状況を取得
Future<VideoStorageInfo> getVideoStorageInfo() async {
  final videoDir = await getVideoStorageDirectory();
  final files = videoDir.listSync().whereType<File>();

  int totalSize = 0;
  int fileCount = 0;
  for (final file in files) {
    totalSize += await file.length();
    fileCount++;
  }

  return VideoStorageInfo(
    totalBytes: totalSize,
    fileCount: fileCount,
  );
}

class VideoStorageInfo {
  final int totalBytes;
  final int fileCount;

  VideoStorageInfo({required this.totalBytes, required this.fileCount});

  /// 表示用フォーマット（例: "256.3 MB"）
  String get formattedSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
```

### 3.3 最大動画長の制限

```dart
/// 動画選択時の制限
final picker = ImagePicker();

// カメラ撮影時: 30秒制限
final video = await picker.pickVideo(
  source: ImageSource.camera,
  maxDuration: const Duration(seconds: 30),
);

// ギャラリー選択時: 選択後に長さチェック
final video = await picker.pickVideo(
  source: ImageSource.gallery,
);
if (video != null) {
  final info = await VideoCompress.getMediaInfo(video.path);
  if (info.duration != null && info.duration! > 30000) {
    // エラー: 30秒を超える動画は選択できません
    throw VideoTooLongException(
      maxSeconds: 30,
      actualSeconds: (info.duration! / 1000).ceil(),
    );
  }
}
```

---

## 4. セキュリティ

### 4.1 N-10 対応: アプリ固有ディレクトリ

- **保存先**: `getApplicationDocumentsDirectory()` を使用
  - iOS: アプリのサンドボックス内。他アプリからアクセス不可
  - Android: アプリ固有の内部ストレージ。他アプリからアクセス不可
- 外部ストレージ（`getExternalStorageDirectory()`）は使用しない

### 4.2 シェアインテント非対応

- 動画ファイルの共有機能（シェアインテント）は実装しない
- 動画は計測専用であり、外部共有の必要性がない
- 将来的に共有が必要になった場合は、計測結果（テキスト/画像）の共有を優先

### 4.3 その他の配慮

- 動画ファイルへのパスをログに出力しない
- バックアップ対象から動画ファイルを除外する（iCloud / Google バックアップ）

```dart
// iOS: Info.plist でバックアップ除外を設定する場合
// NSURLIsExcludedFromBackupKey を設定

// Android: android:allowBackup="false" を検討
// または、動画ディレクトリに .nomedia ファイルを配置
```

---

## 5. 画面フロー

### 5.1 全体フロー

```
動画取り込み画面
├── 「カメラで撮影」ボタン
│   └── カメラ起動
│       └── 撮影完了
│           └── 圧縮処理（プログレス表示）
│               └── 保存完了
│                   └── 計測画面へ遷移（動画パスを渡す）
│
└── 「アルバムから選択」ボタン
    └── ギャラリー表示
        └── 動画選択
            └── 長さチェック（30秒以内）
                ├── OK → 圧縮処理（プログレス表示）
                │       └── 保存完了
                │           └── 計測画面へ遷移（動画パスを渡す）
                └── NG → エラー表示（「30秒以内の動画を選択してください」）
```

### 5.2 画面レイアウト（概要）

```
┌──────────────────────────────┐
│         PhysiLog             │  ← AppBar
├──────────────────────────────┤
│                              │
│    ┌──────────────────────┐  │
│    │                      │  │
│    │   📹 カメラで撮影    │  │  ← 大きなボタン
│    │                      │  │
│    └──────────────────────┘  │
│                              │
│    ┌──────────────────────┐  │
│    │                      │  │
│    │   🖼 アルバムから選択  │  │  ← 大きなボタン
│    │                      │  │
│    └──────────────────────┘  │
│                              │
│    ─── または ───            │
│                              │
│    過去の計測記録一覧へ →    │  ← テキストリンク
│                              │
└──────────────────────────────┘
```

### 5.3 圧縮中の表示

```
┌──────────────────────────────┐
│                              │
│        動画を処理中...       │
│                              │
│    ████████████░░░░░  67%    │  ← プログレスバー
│                              │
│    圧縮中（720p変換）        │  ← ステータステキスト
│                              │
│       [キャンセル]           │  ← キャンセルボタン
│                              │
└──────────────────────────────┘
```

---

## 6. エラーハンドリング

### 6.1 カメラ権限なし

```dart
/// カメラ権限の確認と要求
Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.status;

  if (status.isGranted) return true;

  if (status.isDenied) {
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  if (status.isPermanentlyDenied) {
    // 設定画面への誘導ダイアログを表示
    _showPermissionSettingsDialog(
      title: 'カメラの使用許可が必要です',
      message: '設定画面からカメラへのアクセスを許可してください。',
    );
    return false;
  }

  return false;
}
```

**ユーザーへの表示**:
- 初回: システムの権限ダイアログ
- 拒否後: 「カメラの使用許可が必要です。設定画面から許可してください。」+ 設定画面へのリンク

### 6.2 ストレージ容量不足

```dart
/// ストレージ容量チェック
Future<bool> hasEnoughStorage({int requiredMB = 100}) async {
  // 利用可能な容量を確認
  // ※ プラットフォーム固有の実装が必要
  // disk_space パッケージ等を利用
  final freeSpace = await getFreeDiskSpace();
  return freeSpace > requiredMB * 1024 * 1024;
}
```

**ユーザーへの表示**:
- 「ストレージの空き容量が不足しています。不要なファイルを削除してください。」
- 「現在の動画使用量: XXX MB」の表示
- 過去の動画削除への導線を提示

### 6.3 非対応フォーマット

```dart
/// サポートする動画フォーマット
const supportedVideoFormats = [
  'mp4',
  'mov',
  'avi',
  'm4v',
];

/// フォーマットチェック
bool isSupportedFormat(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();
  return supportedVideoFormats.contains(extension);
}
```

**ユーザーへの表示**:
- 「この動画フォーマットには対応していません。MP4 または MOV 形式の動画を選択してください。」

### 6.4 圧縮失敗

```dart
/// 圧縮処理（エラーハンドリング付き）
Future<File?> compressVideo(String sourcePath) async {
  try {
    final info = await VideoCompress.compressVideo(
      sourcePath,
      quality: VideoCompressConfig.quality,
      deleteOrigin: false, // 元ファイルは削除しない
    );

    if (info == null || info.file == null) {
      throw VideoCompressException('圧縮結果が null です');
    }

    return info.file;
  } on VideoCompressException catch (e) {
    // 圧縮ライブラリ固有のエラー
    logger.error('動画圧縮エラー: $e');
    rethrow;
  } catch (e) {
    // その他の予期しないエラー
    logger.error('予期しない圧縮エラー: $e');
    throw VideoCompressException('動画の圧縮に失敗しました: $e');
  } finally {
    // 一時ファイルのクリーンアップ
    await VideoCompress.deleteAllCache();
  }
}
```

**ユーザーへの表示**:
- 「動画の圧縮に失敗しました。別の動画で再度お試しください。」
- リトライボタンの提供

### 6.5 エラー種別の一覧

| エラー種別 | 検知タイミング | ユーザーメッセージ | リカバリ |
|---|---|---|---|
| カメラ権限なし | 撮影ボタンタップ時 | 「カメラの使用許可が必要です」 | 設定画面への誘導 |
| ギャラリー権限なし | 選択ボタンタップ時 | 「写真へのアクセス許可が必要です」 | 設定画面への誘導 |
| 容量不足 | 撮影/選択後 | 「ストレージの空き容量が不足しています」 | 動画削除への導線 |
| 非対応フォーマット | 動画選択後 | 「この動画フォーマットには対応していません」 | 別動画の選択を促す |
| 動画長超過 | 動画選択後 | 「30秒以内の動画を選択してください」 | 別動画の選択を促す |
| 圧縮失敗 | 圧縮処理中 | 「動画の圧縮に失敗しました」 | リトライまたは別動画 |
| 保存失敗 | ファイル書き込み時 | 「動画の保存に失敗しました」 | リトライ |

---

## 7. 実装タスク一覧

### Phase 1: 基盤実装

1. [ ] `image_picker`, `video_compress`, `path_provider`, `permission_handler` の依存追加
2. [ ] 動画保存ディレクトリのユーティリティ実装
3. [ ] ファイル命名規則の実装
4. [ ] 権限チェック・要求のユーティリティ実装

### Phase 2: 動画取得

5. [ ] カメラ撮影機能の実装
6. [ ] ギャラリー選択機能の実装
7. [ ] 動画長チェックの実装
8. [ ] フォーマットチェックの実装

### Phase 3: 圧縮・保存

9. [ ] 動画圧縮処理の実装
10. [ ] 圧縮プログレス表示の実装
11. [ ] 圧縮後ファイルのアプリディレクトリへの保存
12. [ ] FPS 情報の取得・保持

### Phase 4: 容量管理

13. [ ] 使用容量の計算・表示機能
14. [ ] 古い動画の削除機能
15. [ ] 削除推奨通知の実装

### Phase 5: UI

16. [ ] 動画取り込み画面のUI実装
17. [ ] 圧縮中プログレス画面の実装
18. [ ] エラーダイアログ群の実装

### Phase 6: テスト

19. [ ] ユーティリティ関数のユニットテスト
20. [ ] 圧縮処理のインテグレーションテスト
21. [ ] 権限拒否時のフローテスト
22. [ ] 容量管理のテスト
