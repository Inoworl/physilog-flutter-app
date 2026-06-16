# RevenueCat 課金基盤メモ

最終更新: 2026-06-15

## 目的

PhysiLog の Pro 機能を、初回利用から7日間は無料で開放し、その後は買い切り購入で永久開放する。購入管理は RevenueCat、無料期間と特別権限は Firestore 側で管理する。

## 現在の実装範囲

- Flutter SDK は `purchases_flutter` を使う。
- アプリ起動時に Firebase 匿名認証を完了し、Firebase Auth UID を RevenueCat の App User ID として設定する。
- RevenueCat の public SDK key は `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` の dart-define から取得する。
- APIキー未設定、Firebase未設定、非モバイル環境ではアプリ起動を継続する。
- `pro` Entitlement の有効状態を `RevenueCatService.hasLifetimePro()` で取得する。
- 7日間無料、買い切り購入済み、特別ユーザーの統合判定は `ProAccessPolicy` に閉じ込める。

## RevenueCat 側の設定案

- Entitlement ID: `pro`
- Non-consumable Product ID: `lifetime_pro`
- Offering: 初期リリースでは買い切り商品1件を表示する構成にする。
- Test Store: 開発・テスト用に使う。Test Store API key をストア提出ビルドに入れない。
- Production: iOS / Android それぞれの app-specific public SDK key を dart-define 経由で設定する。

## App Store / Google Play 側の設定案

- iOS: App Store Connect に non-consumable の `lifetime_pro` を作成し、Xcode の In-App Purchase capability を有効化する。
- Android: Google Play Console に one-time product の `lifetime_pro` を作成し、`AndroidManifest.xml` に `com.android.vending.BILLING` を宣言する。
- RevenueCat 側で各ストアの商品を `lifetime_pro` Product として紐付け、`pro` Entitlement を開放する。

## Firestore 側のユーザー属性案

`users/{uid}` に以下の属性を持たせる。

```json
{
  "trialStartedAt": "serverTimestamp",
  "isEarlyUser": false
}
```

- `trialStartedAt` は初回ユーザー作成時だけ server timestamp で保存する。
- 無料期間は `trialStartedAt` から7日未満とする。
- `isEarlyUser` は初期ユーザー、βユーザー、招待ユーザーなどの特別権限に使う。
- 端末時刻ではなく Firestore に保存された日時を基準にする。

## Pro 判定

```dart
final canUsePro = isTrialActive || hasLifetimePro || isEarlyUser;
```

- `isTrialActive`: `trialStartedAt` から7日未満
- `hasLifetimePro`: RevenueCat の `pro` Entitlement が active
- `isEarlyUser`: Firestore の特別権限フラグ

## 初期スコープ外

- サブスクリプション商品
- Web課金 / Stripe
- RevenueCat Webhook によるサーバー同期
- AI回数券などの consumable 商品
- 既存ユーザーの自動権限付与ルール

## 運用メモ

- RevenueCat の public SDK key は公開前提のキーだが、ストア提出ビルドには Test Store API key を入れない。
- RevenueCat の料金は月間 tracked revenue が一定額を超えると従量課金になるため、公開前に最新の Pricing を再確認する。
- 購入復元、購入画面、Firestore の `trialStartedAt` 初期化は次の実装タスクとして分離する。
