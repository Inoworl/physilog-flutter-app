# 06: 画面設計・画面遷移 計画

## 概要

PhysiLogの全画面構成、画面遷移、デザインシステム、レスポンシブ対応、アクセシビリティについて定義する。

---

## 画面一覧

| # | 画面名 | パス | 概要 |
|---|--------|------|------|
| 1 | 記録一覧画面（ホーム） | `/` | 全計測記録の一覧表示 |
| 2 | 記録詳細画面 | `/records/:id` | 個別記録の詳細表示 |
| 3 | 動画取り込み画面 | `/import` | カメラ撮影またはギャラリーから動画選択 |
| 4 | 計測画面 | `/measure` | 動画再生・フレーム確定・タイム算出 |
| 5 | 記録編集画面 | `/records/:id/edit` | 記録のメタ情報編集 |

---

## 画面遷移図

```
┌─────────────┐
│  記録一覧     │ ← ホーム画面
│  （ホーム）    │
└──┬──────┬───┘
   │      │
   │      │ [+ FABタップ]
   │      ▼
   │   ┌─────────────┐
   │   │ 動画取り込み   │ ← カメラ/ギャラリー選択
   │   └──────┬───────┘
   │          │ [動画選択完了]
   │          ▼
   │   ┌─────────────┐
   │   │  計測画面     │ ← 開始/終了確定 → タイム算出
   │   └──┬───────────┘
   │      │ [保存]
   │      │ → 記録一覧に戻る（保存完了）
   │
   │ [リスト項目タップ]
   ▼
┌─────────────┐
│  記録詳細     │
└──┬──────┬───┘
   │      │
   │      │ [再計測ボタン]
   │      ▼
   │   ┌─────────────┐
   │   │  計測画面     │ ← 既存記録の動画で再計測
   │   └─────────────┘
   │
   │ [編集ボタン]
   ▼
┌─────────────┐
│  記録編集     │ ← 選手名・種目・メモの編集
└─────────────┘
```

### 遷移パターン一覧

| 元画面 | アクション | 遷移先 | 遷移方法 |
|--------|-----------|--------|----------|
| 記録一覧 | FABタップ | 動画取り込み | push |
| 記録一覧 | リスト項目タップ | 記録詳細 | push |
| 動画取り込み | 動画選択完了 | 計測画面 | pushReplacement |
| 計測画面 | 保存完了 | 記録一覧 | popUntil(root) |
| 計測画面 | 戻るボタン | 確認ダイアログ → 前画面 | pop |
| 記録詳細 | 編集ボタン | 記録編集 | push |
| 記録詳細 | 再計測ボタン | 計測画面 | push |
| 記録編集 | 保存完了 | 記録詳細 | pop |

---

## 各画面の詳細設計

### 1. 記録一覧画面（ホーム）

#### ワイヤーフレーム

```
┌──────────────────────────────────┐
│  PhysiLog          [フィルタ] [↕]  │  ← AppBar
├──────────────────────────────────┤
│                                  │
│  ┌────────────────────────────┐  │
│  │ 👤 田中太郎                 │  │
│  │    50m走  |  7.234秒        │  │
│  │    2026/02/15  ±16.7ms     │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ 👤 鈴木花子                 │  │
│  │    100m走  |  13.891秒      │  │
│  │    2026/02/14  ±33.3ms     │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │ ...                        │  │
│  └────────────────────────────┘  │
│                                  │
│  [さらに読み込み中...]            │  ← 無限スクロール
│                                  │
│                         [+ FAB]  │  ← 新規計測開始
└──────────────────────────────────┘
```

#### 主要ウィジェット構成

```dart
class RecordListScreen extends ConsumerWidget {
  // Scaffold
  //   ├── AppBar
  //   │     ├── Title: "PhysiLog"
  //   │     └── Actions: [FilterButton, SortButton]
  //   ├── Body: RecordListView
  //   │     ├── ListView.builder (無限スクロール対応)
  //   │     │     └── RecordListTile × N
  //   │     └── LoadingIndicator (末尾)
  //   └── FloatingActionButton: 新規計測
}
```

#### ユーザーインタラクション

- リスト項目タップ → 記録詳細画面へ遷移
- リスト項目左スワイプ → 削除（確認ダイアログ付き）
- FABタップ → 動画取り込み画面へ遷移
- フィルタアイコン → BottomSheetでフィルタ設定
- ソートアイコン → ドロップダウンメニューでソート切替
- プルダウン → リスト更新（RefreshIndicator）

#### エラー状態

- **データなし**: "まだ記録がありません\n右下の+ボタンから計測を始めましょう" + イラスト
- **読み込みエラー**: "データの読み込みに失敗しました" + リトライボタン
- **オフライン**: AppBarにオフラインバナー表示

---

### 2. 記録詳細画面

#### ワイヤーフレーム

```
┌──────────────────────────────────┐
│  ← 戻る    記録詳細    [編集] [⋮]  │  ← AppBar（⋮メニュー: 削除/共有）
├──────────────────────────────────┤
│                                  │
│  ┌────────────────────────────┐  │
│  │      動画サムネイル          │  │  ← タップで動画再生
│  │     （再生アイコン付き）      │  │
│  └────────────────────────────┘  │
│                                  │
│  選手名: 田中太郎                │
│  種目:   50m走                   │
│                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                  │
│  タイム                          │
│  ┌────────────────────────────┐  │
│  │      7.234 秒              │  │  ← 大きなモノスペースフォント
│  │   精度: ±16.7ms (60fps)    │  │
│  └────────────────────────────┘  │
│                                  │
│  計測詳細                        │
│  開始位置: 00:01.234             │
│  終了位置: 00:08.468             │
│                                  │
│  計測日: 2026年2月15日 14:30     │
│                                  │
│  メモ                            │
│  3回目の計測、風速1.2m           │
│                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                  │
│  [再計測]                        │  ← 同じ動画で計測画面を開く
│                                  │
└──────────────────────────────────┘
```

#### 主要ウィジェット構成

```dart
class RecordDetailScreen extends ConsumerWidget {
  // Scaffold
  //   ├── AppBar
  //   │     ├── Leading: BackButton
  //   │     ├── Title: "記録詳細"
  //   │     └── Actions: [EditButton, MoreMenu(delete, share)]
  //   └── Body: SingleChildScrollView
  //         ├── VideoThumbnail (タップで再生)
  //         ├── AthleteEventSection (選手名・種目)
  //         ├── Divider
  //         ├── TimeDisplayCard (タイム・精度)
  //         ├── MeasurementDetailSection (開始/終了位置)
  //         ├── DateSection (計測日)
  //         ├── MemoSection (メモ)
  //         ├── Divider
  //         └── RemeasureButton (再計測ボタン)
}
```

#### ユーザーインタラクション

- 動画サムネイルタップ → 計測画面を読み取り専用で開く（または動画再生）
- 編集ボタン → 記録編集画面へ遷移
- 再計測ボタン → 計測画面へ遷移（同じ動画で再計測）
- ⋮メニュー → 削除（確認ダイアログ）/ 共有
- 戻るボタン → 記録一覧へ戻る

#### エラー状態

- **記録が見つからない**: "この記録は削除されました" + 一覧に戻るボタン
- **動画が見つからない**: サムネイル部分に "動画ファイルが見つかりません" を表示

---

### 3. 動画取り込み画面

#### ワイヤーフレーム

```
┌──────────────────────────────────┐
│  ← 戻る    動画の選択             │  ← AppBar
├──────────────────────────────────┤
│                                  │
│                                  │
│                                  │
│     計測する動画を選んでください     │
│                                  │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │     カメラで撮影する          │  │  ← カメラ起動
│  │     📹                     │  │
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │     ギャラリーから選ぶ        │  │  ← ギャラリー起動
│  │     🖼                     │  │
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│                                  │
└──────────────────────────────────┘
```

#### 主要ウィジェット構成

```dart
class VideoImportScreen extends ConsumerWidget {
  // Scaffold
  //   ├── AppBar
  //   │     ├── Leading: BackButton
  //   │     └── Title: "動画の選択"
  //   └── Body: Center
  //         ├── Text: "計測する動画を選んでください"
  //         ├── CameraButton (image_picker: カメラ起動)
  //         └── GalleryButton (image_picker: ギャラリー起動)
}
```

#### ユーザーインタラクション

- カメラで撮影 → カメラ起動 → 撮影完了で計測画面へ
- ギャラリーから選ぶ → ギャラリー起動 → 選択完了で計測画面へ
- 戻る → 記録一覧へ戻る

#### エラー状態

- **カメラ権限なし**: 設定画面への誘導ダイアログ
- **ストレージ権限なし**: 設定画面への誘導ダイアログ
- **動画選択キャンセル**: 取り込み画面に留まる
- **非対応フォーマット**: "この動画形式は対応していません" エラー表示

---

### 4. 計測画面

#### ワイヤーフレーム

```
┌──────────────────────────────────┐
│  ← 戻る    計測                   │  ← AppBar
├──────────────────────────────────┤
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │      動画プレイヤー          │  │
│  │   （タップで再生/停止）       │  │
│  │                            │  │
│  └────────────────────────────┘  │
├──────────────────────────────────┤
│                                  │
│  [<<0.1s] [<1f]  ▶/⏸  [1f>] [0.1s>>]  │  ← シークコントロール
│                                  │
│  ━━━━━━━━━●━━━━━━━━━━━━━━━━━━  │  ← シークバー
│  現在位置: 00:03.245              │
│                                  │
├──────────────────────────────────┤
│                                  │
│  開始: --:--.---      [確定]      │
│  終了: --:--.---      [確定]      │
│                                  │
│  ─────────────────────────────   │
│  タイム:  --.--- 秒               │
│  精度:   ±16.7ms (60fps)         │
│                                  │
├──────────────────────────────────┤
│  FPS: [30] [60] [120] [240]      │
├──────────────────────────────────┤
│  メモ: ________________________   │
├──────────────────────────────────┤
│                                  │
│  選手名: ___________              │
│  種目:   [▼ 50m走        ]       │
│                                  │
│          [保存]                   │
│                                  │
└──────────────────────────────────┘
```

※ 詳細な動作仕様は `04-measurement.md` を参照

#### 主要ウィジェット構成

```dart
class MeasurementScreen extends ConsumerWidget {
  // Scaffold
  //   ├── AppBar
  //   │     ├── Leading: BackButton（確認ダイアログ付き）
  //   │     └── Title: "計測"
  //   └── Body: SingleChildScrollView
  //         ├── VideoPlayerWidget (動画プレイヤー)
  //         ├── SeekControls (シークコントロールバー)
  //         ├── SeekBar + PositionLabel (シークバー・現在位置)
  //         ├── PositionMarkers (開始/終了確定セクション)
  //         │     ├── StartPositionRow (開始位置 + 確定ボタン)
  //         │     └── EndPositionRow (終了位置 + 確定ボタン)
  //         ├── TimeDisplay (タイム・精度表示)
  //         ├── FpsSelector (FPS選択トグル)
  //         ├── MemoField (メモ入力)
  //         ├── RecordInfoFields (選手名・種目)
  //         └── SaveButton (保存ボタン)
}
```

#### ユーザーインタラクション

- 動画タップ → 再生/停止切替
- シークコントロール → 微細な位置調整
- シークバードラッグ → 大まかな位置移動
- 開始確定 → 現在位置を開始位置として記録
- 終了確定 → 現在位置を終了位置として記録
- FPSトグル → 精度表示の更新
- 保存 → バリデーション後に保存して一覧へ
- 戻る → "計測を中断しますか？" 確認ダイアログ

#### エラー状態

- **動画読み込み失敗**: "動画を読み込めませんでした" + 戻るボタン
- **開始 > 終了**: "終了位置は開始位置より後にしてください" 警告
- **保存時バリデーション**: 選手名・種目が未入力の場合にエラー表示

---

### 5. 記録編集画面

#### ワイヤーフレーム

```
┌──────────────────────────────────┐
│  ← キャンセル  記録編集    [保存]  │  ← AppBar
├──────────────────────────────────┤
│                                  │
│  選手名                          │
│  ┌────────────────────────────┐  │
│  │ 田中太郎                    │  │  ← TextFormField
│  └────────────────────────────┘  │
│                                  │
│  種目                            │
│  ┌────────────────────────────┐  │
│  │ ▼ 50m走                    │  │  ← DropdownButton
│  └────────────────────────────┘  │
│                                  │
│  メモ                            │
│  ┌────────────────────────────┐  │
│  │ 3回目の計測、風速1.2m       │  │  ← TextFormField (multiline)
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  ─────────────────────────────   │
│                                  │
│  タイム: 7.234秒（読み取り専用）  │
│  ※ タイムを変更するには「再計測」  │
│    を使用してください              │
│                                  │
└──────────────────────────────────┘
```

#### 主要ウィジェット構成

```dart
class RecordEditScreen extends ConsumerWidget {
  // Scaffold
  //   ├── AppBar
  //   │     ├── Leading: CancelButton
  //   │     ├── Title: "記録編集"
  //   │     └── Actions: [SaveButton]
  //   └── Body: Form
  //         ├── AthleteNameField (選手名入力)
  //         ├── EventDropdown (種目選択)
  //         ├── MemoField (メモ入力)
  //         ├── Divider
  //         └── ReadOnlyTimeInfo (タイム表示・読み取り専用)
}
```

#### ユーザーインタラクション

- 各フィールドを編集
- 保存 → バリデーション後に更新して詳細画面へ戻る
- キャンセル → 変更がある場合は確認ダイアログ → 詳細画面へ戻る

#### エラー状態

- **バリデーション**: 選手名が空の場合 "選手名を入力してください"
- **保存失敗**: "保存に失敗しました。もう一度お試しください"

---

## ルーティング

### go_router 設定

```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 記録一覧（ホーム）
      GoRoute(
        path: '/',
        name: 'recordList',
        builder: (context, state) => const RecordListScreen(),
      ),

      // 記録詳細
      GoRoute(
        path: '/records/:id',
        name: 'recordDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecordDetailScreen(recordId: id);
        },
        routes: [
          // 記録編集（詳細のサブルート）
          GoRoute(
            path: 'edit',
            name: 'recordEdit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return RecordEditScreen(recordId: id);
            },
          ),
        ],
      ),

      // 動画取り込み
      GoRoute(
        path: '/import',
        name: 'videoImport',
        builder: (context, state) => const VideoImportScreen(),
      ),

      // 計測画面
      GoRoute(
        path: '/measure',
        name: 'measurement',
        builder: (context, state) {
          final videoPath = state.extra as String?;
          final recordId = state.uri.queryParameters['recordId'];
          return MeasurementScreen(
            videoPath: videoPath,
            existingRecordId: recordId,
          );
        },
      ),
    ],

    // エラーページ
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});
```

### ルート定義一覧

| ルート名 | パス | パラメータ | 説明 |
|----------|------|-----------|------|
| recordList | `/` | なし | ホーム画面 |
| recordDetail | `/records/:id` | id: 記録ID | 記録詳細 |
| recordEdit | `/records/:id/edit` | id: 記録ID | 記録編集 |
| videoImport | `/import` | なし | 動画取り込み |
| measurement | `/measure` | extra: videoPath, query: recordId | 計測画面 |

### ディープリンク対応（将来）

- MVP段階では未対応
- 将来的に `/records/:id` へのディープリンクを検討
- Firebase Dynamic Links または App Links / Universal Links で実装

---

## デザインシステム

### Material Design 3 ベース

PhysiLogはMaterial Design 3（Material You）をベースにカスタマイズする。

### カラースキーム

```dart
/// スポーツ/フィットネス系のカラーテーマ
/// 活動的でエネルギッシュな印象
class AppColors {
  // プライマリー: ディープブルー（信頼性・正確さ）
  static const primary = Color(0xFF1565C0);        // Blue 800
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFBBDEFB); // Blue 100

  // セカンダリー: ティール（スポーツ・活動的）
  static const secondary = Color(0xFF00897B);       // Teal 600
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFB2DFDB); // Teal 100

  // アクセント/エラー
  static const error = Color(0xFFD32F2F);           // Red 700
  static const onError = Color(0xFFFFFFFF);

  // サーフェス
  static const surface = Color(0xFFFAFAFA);
  static const onSurface = Color(0xFF212121);
  static const surfaceVariant = Color(0xFFF5F5F5);

  // 計測画面固有
  static const startMarker = Color(0xFF4CAF50);     // Green 500（開始）
  static const endMarker = Color(0xFFF44336);        // Red 500（終了）
  static const timeDisplay = Color(0xFF212121);      // 黒（タイム表示）
}

/// テーマ定義
ThemeData appTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    // ... カスタマイズ
  );
}

/// ダークテーマ
ThemeData appDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    // ... カスタマイズ
  );
}
```

### タイポグラフィ

```dart
class AppTextStyles {
  /// タイム表示用 - モノスペースフォント
  /// 数字の幅が揃い、タイム変動時にレイアウトシフトしない
  static const timeDisplay = TextStyle(
    fontFamily: 'RobotoMono',  // またはGoogleFontsから
    fontSize: 36,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  /// タイム表示（小）- 開始/終了位置等
  static const timeSmall = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// 精度表示
  static const precisionLabel = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    color: Colors.grey,
  );

  /// 選手名（リスト項目）
  static const athleteName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// 種目・日付（リスト項目）
  static const recordSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  /// セクション見出し
  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}
```

### 共有コンポーネント

```dart
/// アプリ全体で共有するウィジェット

// 1. タイムフォーマッター
class TimeFormatter {
  /// ミリ秒をフォーマット: "7.234" (秒表示)
  static String formatSeconds(double ms) {
    return (ms / 1000).toStringAsFixed(3);
  }

  /// Durationをフォーマット: "00:03.245" (分:秒.ミリ秒)
  static String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }
}

// 2. 空状態ウィジェット
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  // ...
}

// 3. エラー状態ウィジェット
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  // ...
}

// 4. 読み込み状態ウィジェット
class LoadingState extends StatelessWidget {
  final String? message;
  // ...
}

// 5. 確認ダイアログ
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = '確認',
  String cancelLabel = 'キャンセル',
  bool isDestructive = false,
});
```

---

## レスポンシブ対応

### スマホ縦向き優先

- 全画面がスマホ縦向き（ポートレート）で最適に表示されるよう設計
- 横幅320dp〜428dpの範囲で正しく表示されることを確認

### 計測画面の横向き対応

```dart
/// 計測画面では横向きも検討
/// 横向きでは動画表示領域を広く確保し、コントロールを横に配置
///
/// 横向きレイアウト:
/// ┌───────────────────┬─────────────┐
/// │                   │ 開始: 01.234 │
/// │   動画プレイヤー    │ 終了: 08.468 │
/// │                   │ タイム: 7.234│
/// │                   │ [確定] [確定] │
/// ├───────────────────┤ [保存]       │
/// │ [<<] [<] ▶ [>] [>>] │            │
/// │ ━━━━●━━━━━━━━━━━━ │            │
/// └───────────────────┴─────────────┘

class MeasurementScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout(context, ref);
        }
        return _buildPortraitLayout(context, ref);
      },
    );
  }
}
```

### ブレークポイント（将来のタブレット対応用）

| デバイス | 幅 | 対応 |
|----------|-----|------|
| スマホ（小） | 320-375dp | MVP対応 |
| スマホ（大） | 376-428dp | MVP対応 |
| タブレット | 600dp+ | 将来対応 |

---

## アクセシビリティ

### セマンティクスラベル

```dart
/// 全てのインタラクティブ要素にセマンティクスラベルを設定

// シークコントロール
Semantics(
  label: '0.1秒戻る',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.fast_rewind),
    onPressed: () => seekByMilliseconds(-100),
  ),
);

// 開始確定ボタン
Semantics(
  label: '開始位置を現在のフレームに確定',
  button: true,
  child: ElevatedButton(
    onPressed: setStartPosition,
    child: const Text('確定'),
  ),
);

// タイム表示
Semantics(
  label: '計測タイム 7.234秒',
  child: Text('7.234', style: AppTextStyles.timeDisplay),
);
```

### コントラスト比

- テキスト: 最低4.5:1（WCAG AA準拠）
- 大きなテキスト（18sp以上）: 最低3:1
- タイム表示: 黒文字/白背景で最大コントラスト

### タッチターゲットサイズ

```dart
/// Material Design 3 ガイドライン準拠
/// 最小タッチターゲット: 48dp x 48dp

// シークコントロールボタン
SizedBox(
  width: 48,
  height: 48,
  child: IconButton(
    icon: const Icon(Icons.skip_next),
    onPressed: () => seekByFrames(1),
  ),
);

// 確定ボタン - 十分な大きさ
ElevatedButton(
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(80, 48),
  ),
  onPressed: setStartPosition,
  child: const Text('確定'),
);
```

### その他のアクセシビリティ考慮

- **フォーカス順序**: 論理的なタブ順序を設定
- **スクリーンリーダー**: TalkBack/VoiceOverでの操作を考慮
- **動画のアクセシビリティ**: 再生状態の音声フィードバック
- **色だけに頼らない**: 開始（緑+ラベル）/終了（赤+ラベル）を色+テキストで区別

---

## ファイル構成（予定）

```
lib/
├── app/
│   ├── app.dart                    # MaterialApp設定
│   ├── router.dart                 # go_router設定
│   └── theme/
│       ├── app_theme.dart          # テーマ定義
│       ├── app_colors.dart         # カラー定義
│       └── app_text_styles.dart    # テキストスタイル定義
├── shared/
│   └── widgets/
│       ├── empty_state.dart        # 空状態
│       ├── error_state.dart        # エラー状態
│       ├── loading_state.dart      # 読み込み状態
│       ├── confirm_dialog.dart     # 確認ダイアログ
│       └── time_formatter.dart     # タイムフォーマッター
├── features/
│   ├── records/
│   │   └── presentation/
│   │       ├── record_list_screen.dart
│   │       ├── record_detail_screen.dart
│   │       └── record_edit_screen.dart
│   ├── measurement/
│   │   └── presentation/
│   │       └── measurement_screen.dart
│   └── video_import/
│       └── presentation/
│           └── video_import_screen.dart
```

---

## 実装順序

1. **Phase 1**: デザインシステム（テーマ・カラー・テキストスタイル）
2. **Phase 2**: 共有コンポーネント（空状態・エラー状態・タイムフォーマッター）
3. **Phase 3**: ルーティング設定（go_router）
4. **Phase 4**: 記録一覧画面（ホーム）
5. **Phase 5**: 動画取り込み画面
6. **Phase 6**: 計測画面
7. **Phase 7**: 記録詳細画面
8. **Phase 8**: 記録編集画面
9. **Phase 9**: レスポンシブ対応（横向き）
10. **Phase 10**: アクセシビリティ改善
