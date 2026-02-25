# iOS Dev TestFlight 配信（GitHub Actions）

このドキュメントは `deploy_dev_ios.yml` を実行するための設定手順です。

## 目的

- `dev` 向け iOS ビルドを GitHub Actions で作成する
- TestFlight（内部テスター）へアップロードする

## GitHub Actions Workflow

- ファイル: `.github/workflows/deploy_dev_ios.yml`
- 実行方法: `Actions` タブから `[Release] Dev iOS` を手動実行（`workflow_dispatch`）

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
- `APPLE_ID`
  - App Store Connect へアップロードする Apple ID（メールアドレス）
- `APP_SPECIFIC_PASSWORD`
  - Apple ID の app-specific password

任意（Firebase 初期化用）:

- `DEV_GOOGLESERVICE_INFO_PLIST_BASE64`
  - `ios/Runner/GoogleService-Info.plist` を base64 化した文字列
  - 未設定でも workflow は進行します

## 事前に Apple 側で必要な設定

- Bundle ID: `com.physilog.physiLog.dev`
- App Store Connect App: `PhysiLog Dev`
- TestFlight 内部テスターグループ（例: `Internal Dev`）

## 実行後の確認ポイント

- Actions のジョブが成功していること
- TestFlight の `PhysiLog Dev` に新しいビルドが表示されること
- 必要に応じて内部テスターへビルドを配布すること
