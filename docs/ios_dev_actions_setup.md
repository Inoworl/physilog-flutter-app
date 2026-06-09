# iOS Dev TestFlight 配信（GitHub Actions）

このドキュメントは `deploy_dev_ios.yml` を実行するための設定手順です。

## 目的

- `dev` 向け iOS ビルドを GitHub Actions で作成する
- TestFlight（外部テスター）まで自動配信する

## GitHub Actions Workflow

- ファイル: `.github/workflows/deploy_dev_ios.yml`
- 実行方法:
  - `main` への push で自動実行
  - `Actions` タブから `[Release] Dev iOS` を手動実行（`workflow_dispatch`）

## 必要な GitHub Secrets

`Repository Settings > Secrets and variables > Actions` に以下を登録します。

- `IOS_CERTIFICATES_P12_BASE64`
  - Apple Distribution 証明書（`.p12`）を base64 化した文字列
- `IOS_CERTIFICATES_P12_PASSWORD`
  - `.p12` のパスワード
- `DEV_PROVISIONING_PROFILE_BASE64`
  - Dev 用 App Store Provisioning Profile（`.mobileprovision`）を base64 化した文字列
- `DEV_PROVISIONING_PROFILE_SPECIFIER`
  - Provisioning Profile 名（Xcode の `PROVISIONING_PROFILE_SPECIFIER` と同じ文字列）
- `DEVELOPMENT_TEAM_ID`
  - Apple Developer Team ID（例: `XXXXXXXXXX`）
- `ASC_KEY_ID`
  - App Store Connect API Key の Key ID
- `ASC_ISSUER_ID`
  - App Store Connect API Key の Issuer ID
- `ASC_API_KEY_BASE64`
  - App Store Connect API Key (`.p8`) を base64 化した文字列

任意（Firebase 初期化用）:

- `DEV_GOOGLESERVICE_INFO_PLIST_BASE64`
  - `ios/Runner/GoogleService-Info.plist` を base64 化した文字列
  - 未設定でも workflow は進行します

外部テスター自動配信（必須）:

- `DEV_TESTFLIGHT_EXTERNAL_GROUPS`
  - 配信対象の外部テスターグループ名（カンマ区切り可）
  - 例: `External Testers`
- `DEV_TESTFLIGHT_BETA_APP_DESCRIPTION`
  - TestFlight の「ベータ版アプリの説明」
- `DEV_TESTFLIGHT_WHATS_NEW_JA`
  - TestFlight の「テスト内容（日本語）」
- `DEV_TESTFLIGHT_FEEDBACK_EMAIL`
  - TestFlight のフィードバックメールアドレス
- `DEV_TESTFLIGHT_CONTACT_FIRST_NAME`
  - ベータ審査連絡先（名）
- `DEV_TESTFLIGHT_CONTACT_LAST_NAME`
  - ベータ審査連絡先（姓）
- `DEV_TESTFLIGHT_CONTACT_EMAIL`
  - ベータ審査連絡先メール
- `DEV_TESTFLIGHT_CONTACT_PHONE_E164`
  - ベータ審査連絡先電話番号（E.164形式、例: `+819012345678`）

外部テスター自動追加（任意）:

- `DEV_TESTFLIGHT_EXTERNAL_TESTER_EMAIL`
  - 追加したい外部テスターのメール
- `DEV_TESTFLIGHT_EXTERNAL_TESTER_FIRST_NAME`
  - 外部テスターの名
- `DEV_TESTFLIGHT_EXTERNAL_TESTER_LAST_NAME`
  - 外部テスターの姓
- `DEV_TESTFLIGHT_NOTIFY_EXTERNAL_TESTERS`
  - `true/false`（デフォルト: `true`）
  - 外部テスター通知メールの送信可否

## 事前に Apple 側で必要な設定

- Bundle ID: `com.inoworl.physilog.dev`
- App Store Connect App: `PhysiLog Dev`
- TestFlight 外部テスターグループ（例: `External Testers`）

## 実行後の確認ポイント

- Actions のジョブが成功していること
- TestFlight の `PhysiLog Dev` に新しいビルドが表示されること
- `External Testers` グループに最新ビルドが紐づいていること
- 必要に応じて外部テスターへ通知が送信されていること
