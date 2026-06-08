# Codex 作業メモ

更新日: 2026-06-08

このメモは、PhysiLog の Flutter アプリで調査・実装・検証を始める前に確認するプロジェクト固有の運用情報です。Issue 固有の仕様ではなく、毎回の作業で使う基本情報だけを置きます。

## 配置とパス基準

- このファイルは PhysiLog Flutter アプリ repo のルートに置く。
- パスはすべてこの Flutter アプリ repo 直下を基準に書く。
- Firebase / Functions / Rules 関連は隣接 repo の `../physilog-firebase-commons/`。
- このプロジェクトは git worktree を使っている。
- 初期調査では、ユーザーから明示指示があるまで、この Flutter アプリ repo と `../physilog-firebase-commons/` だけを読む。
- `PhysiLog-*` や `physilog-*` の作業用ディレクトリは、worktree や過去ブランチ由来のディレクトリであることが多い。ユーザーから明示指示があるまで読まない。
- 作業対象が確定したら、cwd、branch、未コミット差分を確認する。

## 実装前に確認する情報

- `.ai/` が存在する場合、設計方針、実装計画、リリースメモ、ストア提出メモ、テスト方針などが入っている。
- 実装前に、対象機能に関係する `.ai` 配下のメモを確認する。
- `.ai/tmp/` には秘密鍵や一時ファイルが含まれる可能性があるため、勝手に読まない。
- 認証情報やテストアカウントを含む可能性があるファイルは、必要な場合だけユーザーに確認してから読む。
- `.playwright-mcp/` はローカル確認ログであり、feature 本体の成果物として扱わない。

## ブランチ運用

- Flutter アプリ repo の default ブランチは `dev`。
- feature 実装時は、誤って `main` などを起点にせず、原則として `dev` を起点にする。
- 新規実装・修正作業は、最新の `origin/dev` を確認してから専用ブランチまたは worktree で進める。
- 既存作業ツリーに未コミット変更がある場合は、それを触らず、必要に応じて最新 `origin/dev` から別 worktree を作成して進める。

## hatcher worktree 作成

- worktree 作成には `hatcher` を使う。
- PhysiLog の auto-copy 設定は、repo 直下の `.hatcher-auto-copy.json` で管理する。
- `.hatcher-auto-copy.json` を正しく読むには `hatcher v1.2.9` 以降が必要。古い `hatcher` では project root の top-level `version/items` 設定が正しく反映されない。
- `.hatcher-auto-copy.json` は、worktree作成時に次をコピーする。
  - `AGENTS.md`
  - `.ai/`
  - `.hatcher-auto-copy.json`
  - `dart_define/dev_dart_define.json`
  - `dart_define/prod_dart_define.json`
  - `lib/firebase_options.dart`
  - `lib/firebase_options_dev.dart`
  - `lib/firebase_options_prod.dart`
  - `ios/Runner/GoogleService-Info.plist` が存在する場合
  - `android/app/src/dev/google-services.json` が存在する場合
  - `android/app/src/prod/google-services.json` が存在する場合
  - `android/app/google-services.json` が存在する場合
- hatcher の auto-copy は存在しないパスをスキップする。コピー対象を増やす場合は `.hatcher-auto-copy.json` に追加してから、テスト用worktreeで実際にコピーされるか確認する。
- `.ai/` や Firebase 設定ファイルは gitignore されていても hatcher でコピーされる。内容を読む必要がある場合は、機密情報を含む可能性を前提にユーザー確認を取る。

## 起動とデバッグ

- dev 環境での通常デバッグは dev flavor を使う。
- CLI で同じ条件を再現する場合は、原則として次の形に合わせる。

```bash
fvm flutter run --debug --flavor dev --dart-define-from-file=dart_define/dev_dart_define.json
```

- prod 相当を確認する場合は prod flavor を使う。安易に prod 設定で実データ操作をしない。
- `dart_define/*.json` は環境値を含むため、内容確認が必要な場合だけユーザーに確認してから読む。通常は起動設定の参照先として扱えばよい。

## Firebase と関連 repo

- dev debug では dev Firebase に接続される前提だが、調査時は起動ログで flavor、store mode、projectId を確認する。
- dev の Firebase project は `physilog-dev`。
- Flutter app だけで完結しない挙動は、`../physilog-firebase-commons/` も確認する。
- `../physilog-firebase-commons/` には Firestore Rules、Firestore indexes、関連テストが含まれる。
- Flutter クライアントで新しい Firestore / Storage パスを読む・書く実装を追加する場合は、`../physilog-firebase-commons/` 側の rules と rules test も確認する。
- クライアント側の失敗に見えても、Rules や Functions の責務で動く処理がある。境界を確認してから修正する。
- Firebase 接続や Rules の挙動を調べるときは、アプリログだけで断定せず、必要に応じて Firebase Console やエミュレータテストも確認する。
- Firebase Console をブラウザで確認する必要がある場合は、Playwright Stateful MCP または Chrome DevTools MCP を使ってよい。
- 2 repo にまたがる変更は、原則として repo ごとにブランチ・コミット・PR を分ける。

## 実データ操作

- 実 Firebase 環境への Firestore 書き込みは、通常は dry-run で確認してから行う。
- 書き込みスクリプトがある場合も、`--apply` なしでは書き込まない設計にする。
- production data への write、審査提出、production 公開などは、Issue またはチャット上の明示承認がある場合だけ実行する。
- migration / backfill では、dry-run の集計ログと apply の差分が説明できる状態にする。

## Android 実機調査

- 実機確認が必要なときは、まず接続端末を確認する。

```bash
adb devices
adb devices -l
fvm flutter devices
```

- Android 実機で確認する場合は、emulator と取り違えないよう device id を明示する。

```bash
fvm flutter run --flavor dev --dart-define-from-file=dart_define/dev_dart_define.json -d <device-id>
```

- Android の画面状態を CLI から確認する場合は、`uiautomator dump` を使う。全量は長くなるため、必要な文言だけに絞る。

```bash
adb -s <device-id> shell uiautomator dump /sdcard/window.xml >/dev/null
adb -s <device-id> exec-out cat /sdcard/window.xml | tr '>' '\n' | rg '<確認したい文言>'
```

- 実機操作を CLI で補助する場合は、座標タップとテキスト入力を使う。座標は端末解像度や表示中画面で変わるため、直前に `uiautomator dump` の `bounds` を確認してから打つ。
- dev アプリを停止する場合は、dev package を対象にする。

```bash
adb -s <device-id> shell am force-stop com.physilog.physi_log.dev
```

- 実機ログは `flutter run` の出力、`adb logcat`、アプリ内の debug log を合わせて見る。
- 実機で再現確認した場合は、使用端末、ビルド flavor、接続先 Firebase project、操作したテストデータを最終報告に残す。

## ローカル検証

- Flutter 側の基本検証は FVM 経由で実行する。
- 通常の `flutter` は SDK が古い可能性があるため、テスト・解析・pub 操作では原則使わない。
- `.fvmrc` の Flutter バージョンを正とする。

```bash
fvm dart format <changed dart files>
fvm flutter test <relevant tests>
fvm flutter analyze
```

- Freezed / Riverpod / JSON などの annotation 付き model / provider を変更した場合は、生成ファイルを手編集せず、build runner を実行する。

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

- `../physilog-firebase-commons/` 側の Rules / Functions テストは、その repo の `package.json` scripts と GitHub Actions を確認してから実行する。
- Firebase Emulator 実行時に Java 21 が必要な場合、Homebrew の OpenJDK 21 を使う。

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH
```

- Firestore rules test の例:

```bash
cd ../physilog-firebase-commons
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH \
npm run emulator:test:ci
```

- ローカル依存が壊れている場合は、失敗ログを残し、PR 本文や報告に未検証理由を明記する。

## 実装方針の前提

- PhysiLog は `features/<feature>/{presentation,application,domain,data}` と `models/` を中心に構成されている。
- 既存配置を優先する。UI は `presentation`、Riverpod Notifier / State は `application`、Entity / Interface は `domain`、Firebase 実装は `data` に置く。
- 完全な Clean Architecture 化を目的にせず、Riverpod を前提にした Flutter 実用型の責務分離を優先する。
- Domain は Flutter / Riverpod / Presentation からできるだけ独立させる。
- Notifier はユーザー操作と画面状態更新を担当する。
- Repository は外部データソースとの読み書き、Mapper、最低限のデータ取得に寄せる。
- Freezed の生成ファイルは手編集しない。
- ユーザー向け文言は既存アプリの日本語表現に合わせる。

## PR 作成

- Issue を解決する PR の本文には、対象 Issue を自動クローズするために `Closes #<issue番号>` を必ず記載する。
- 複数 Issue を解決する場合は、対象 Issue ごとに `Closes #<issue番号>` を記載する。
- Issue を解決せず参照だけする場合は、`Refs #<issue番号>` を使う。
- PR 作成前に、本文内の Issue 番号が今回の変更範囲と一致しているか確認する。

## セキュリティと機密情報

- `.env`、鍵ファイル、secret/config、API key を含む可能性があるファイルは読まない。
- `lib/firebase_options*.dart` は API key などを含み得るため、勝手に内容を貼り付けたり、ログやPR本文に値を出したりしない。
- `lib/firebase_options*.dart` が無いために `flutter analyze` や test が失敗する場合は、生成ファイル不在が原因として報告する。
- Firebase token、service account、private key、署名鍵が必要になった場合は、ユーザーに確認してから扱う。
- ログや PR 本文には token、メール以外の認証情報、秘密値を出さない。
