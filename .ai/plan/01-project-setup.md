# Phase 1: プロジェクトセットアップ詳細計画

## Flutter プロジェクト作成

### プロジェクト生成コマンド

```bash
flutter create \
  --org com.physilog \
  --project-name physilog \
  --platforms ios,android \
  --description "スポーツ体力測定動画計測アプリ" \
  physilog
```

### プロジェクト基本情報

| 項目 | 値 |
|-----|-----|
| アプリ名 | PhysiLog |
| パッケージ名 | com.physilog.physilog |
| 対応プラットフォーム | iOS, Android |
| 最小 iOS バージョン | 15.0 |
| 最小 Android SDK | 24 (Android 7.0) |
| ターゲット Android SDK | 34 (Android 14) |

---

## ディレクトリ構成

```
physilog/
├── lib/
│   ├── main.dart                     # エントリーポイント
│   ├── app/
│   │   ├── app.dart                  # MaterialApp / アプリルート
│   │   └── router.dart               # ルーティング定義（go_router）
│   ├── features/
│   │   ├── measurement/              # 計測機能
│   │   │   ├── screens/              #   画面
│   │   │   ├── widgets/              #   専用ウィジェット
│   │   │   └── providers/            #   機能固有プロバイダ
│   │   ├── records/                  # 記録管理
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   └── video_import/             # 動画取り込み
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── providers/
│   ├── models/                       # データモデル（Freezed）
│   │   ├── measurement_record.dart
│   │   ├── video_metadata.dart
│   │   └── sport_event.dart
│   ├── repositories/                 # データアクセス層
│   │   ├── measurement_repository.dart
│   │   └── video_repository.dart
│   ├── providers/                    # グローバル Riverpod プロバイダ
│   │   └── app_providers.dart
│   └── shared/                       # 共有ウィジェット / ユーティリティ
│       ├── widgets/                  #   共通ウィジェット
│       ├── constants/                #   定数定義
│       ├── extensions/               #   拡張メソッド
│       └── utils/                    #   ユーティリティ関数
├── test/                             # テストディレクトリ
│   ├── unit/
│   ├── widget/
│   └── integration/
├── assets/                           # アセット（画像、フォント等）
│   ├── images/
│   └── fonts/
├── android/                          # Android 固有設定
├── ios/                              # iOS 固有設定
├── pubspec.yaml                      # パッケージ定義
├── analysis_options.yaml             # Lint 設定
└── firebase.json                     # Firebase 設定
```

### ディレクトリ構成の方針

- **Feature-first 構成**: 機能ごとにディレクトリを分割し、関連するコードをまとめる
- **models / repositories / providers**: 機能横断で共有されるものはトップレベルに配置
- **shared**: 複数の feature から参照される共通コンポーネントを配置
- **各 feature 内の providers**: その機能に閉じた状態管理のみ配置

---

## 依存パッケージ一覧

### pubspec.yaml（dependencies）

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状態管理
  flutter_riverpod: ^2.6.1          # Riverpod（Flutter 統合）
  riverpod_annotation: ^2.6.1       # Riverpod コード生成用アノテーション

  # ルーティング
  go_router: ^14.6.2                # 宣言的ルーティング

  # Firebase
  firebase_core: ^3.8.1             # Firebase コア
  firebase_auth: ^5.3.4             # Firebase 認証（匿名ログイン）

  # 動画操作
  video_player: ^2.9.2              # 動画再生
  ffmpeg_kit_flutter: ^6.0.3        # FFmpeg（フレーム抽出、メタデータ取得）
  image_picker: ^1.1.2              # カメラロールからの動画選択

  # ローカルDB
  hive: ^2.2.3                      # ローカルストレージ
  hive_flutter: ^1.1.0              # Hive の Flutter 統合

  # データモデル
  freezed_annotation: ^2.4.4        # Freezed アノテーション（不変データクラス）
  json_annotation: ^4.9.0           # JSON シリアライゼーション アノテーション

  # ユーティリティ
  path_provider: ^2.1.5             # ファイルパス取得
  permission_handler: ^11.3.1       # 権限管理
  intl: ^0.19.0                     # 国際化・日付フォーマット
  uuid: ^4.5.1                      # UUID 生成
```

### pubspec.yaml（dev_dependencies）

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # コード生成
  build_runner: ^2.4.13             # コード生成ランナー
  freezed: ^2.5.7                   # 不変データクラス生成
  json_serializable: ^6.8.0         # JSON シリアライゼーション生成
  riverpod_generator: ^2.6.3        # Riverpod コード生成
  hive_generator: ^2.0.1            # Hive TypeAdapter 生成

  # Lint
  flutter_lints: ^5.0.0             # Flutter 推奨 Lint ルール
  custom_lint: ^0.7.0               # カスタム Lint
  riverpod_lint: ^2.6.3             # Riverpod 専用 Lint

  # テスト
  mockito: ^5.4.4                   # モック生成
  mocktail: ^1.0.4                  # モック（コード生成不要版）
```

> **注意**: バージョンは 2026年2月時点の目安であり、実際のセットアップ時に `flutter pub outdated` で最新版を確認すること。

---

## Firebase セットアップ手順

### 1. Firebase プロジェクト作成

```bash
# Firebase コンソール（https://console.firebase.google.com）で新規プロジェクトを作成
# プロジェクト名: physilog
# Google Analytics: MVP では無効でも可
```

### 2. Firebase CLI インストール・ログイン

```bash
# Firebase CLI のインストール
npm install -g firebase-tools

# ログイン
firebase login

# FlutterFire CLI のインストール
dart pub global activate flutterfire_cli
```

### 3. FlutterFire 設定

```bash
# プロジェクトルートで実行
flutterfire configure \
  --project=physilog \
  --platforms=ios,android

# 以下のファイルが自動生成される:
# - lib/firebase_options.dart
# - android/app/google-services.json
# - ios/Runner/GoogleService-Info.plist
```

### 4. Firebase 初期化コード

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: PhysiLogApp(),
    ),
  );
}
```

### 5. Firebase 匿名ログインの有効化

```
Firebase コンソール → Authentication → Sign-in method
→ 「匿名」を有効にする
```

### 6. Firestore セキュリティルール（初期設定）

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // MVP: 認証済みユーザーは自分のデータのみ読み書き可能
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## CI/CD

MVP 段階では CI/CD の構築は必須ではないが、将来的に以下を導入する想定。

### 将来計画

| ツール | 用途 |
|-------|------|
| GitHub Actions | テスト自動実行、ビルド |
| Fastlane | iOS / Android のリリース自動化 |
| Firebase App Distribution | テスト版配布 |
| Codemagic（代替） | Flutter 特化の CI/CD |

### MVP 段階で最低限やること

```yaml
# .github/workflows/test.yml（参考）
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

---

## コーディング規約

### Lint 設定（analysis_options.yaml）

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    # 厳格モード
    always_declare_return_types: true
    always_use_package_imports: true
    avoid_dynamic_calls: true
    avoid_print: true
    avoid_relative_lib_imports: true
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_locals: true
    require_trailing_commas: true
    sort_constructors_first: true
    unawaited_futures: true
```

### 命名規則

| 対象 | 規則 | 例 |
|-----|------|-----|
| ファイル名 | snake_case | `measurement_record.dart` |
| クラス名 | UpperCamelCase | `MeasurementRecord` |
| 変数名・関数名 | lowerCamelCase | `startMeasurement()` |
| 定数 | lowerCamelCase | `defaultFrameRate` |
| プライベート | アンダースコア接頭辞 | `_internalState` |
| Riverpod Provider | lowerCamelCase + Provider 接尾辞 | `measurementListProvider` |

### コーディングルール

1. **不変データ**: データモデルは `freezed` を使い、イミュータブルにする
2. **null安全**: `required` パラメータを積極的に使用し、nullable を最小限にする
3. **エラーハンドリング**: `Result` パターンまたは `AsyncValue` を使用し、例外を適切に処理する
4. **コメント**: 公開APIには `///` ドキュメンテーションコメントを付与する
5. **テスト**: 新しい機能には必ずユニットテストを作成する
6. **コード生成**: `build_runner` で生成されるファイル（`*.g.dart`, `*.freezed.dart`）はバージョン管理に含める

### Git ブランチ戦略

```
main          ← リリース可能な状態を維持
├── develop   ← 開発統合ブランチ
│   ├── feature/video-import    ← 機能ブランチ
│   ├── feature/measurement     ← 機能ブランチ
│   └── fix/frame-rate-issue    ← バグ修正ブランチ
```

### コミットメッセージ規約

```
<type>: <subject>

<body>（任意）
```

| type | 用途 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| refactor | リファクタリング |
| docs | ドキュメント |
| test | テスト追加・修正 |
| chore | ビルド設定、依存更新等 |

例:
```
feat: 動画取り込み機能を追加
fix: フレームレート計算の精度を改善
refactor: MeasurementRepository の依存注入を整理
```

---

## セットアップ完了チェックリスト

- [ ] Flutter SDK がインストールされ、`flutter doctor` が全項目パスする
- [ ] `flutter create` でプロジェクトが生成されている
- [ ] ディレクトリ構成が上記の通り作成されている
- [ ] `pubspec.yaml` に全依存パッケージが記載されている
- [ ] `flutter pub get` が成功する
- [ ] Firebase プロジェクトが作成されている
- [ ] `flutterfire configure` が完了し、設定ファイルが生成されている
- [ ] Firebase 匿名ログインが有効化されている
- [ ] `analysis_options.yaml` に Lint ルールが設定されている
- [ ] `flutter analyze` でエラーが出ない
- [ ] `flutter run` で空のアプリが起動する（iOS / Android 各1台以上）
- [ ] Git リポジトリが初期化され、初回コミットが完了している
