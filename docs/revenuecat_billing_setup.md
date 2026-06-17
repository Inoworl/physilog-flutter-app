# RevenueCat 課金基盤メモ

最終更新: 2026-06-18

## 目的

PhysiLog の利用権を、無料ユーザー、個人PRO、団体PROの3段階で扱えるようにする。個人PROの購入状態は RevenueCat の `pro` Entitlement で判定し、団体PROと配信初期ユーザー特典は Firestore の entitlement で管理する。

## 利用権

| 種別 | 管理元 | 判定 | 利用範囲 |
| --- | --- | --- | --- |
| 無料ユーザー | entitlementなし | `canUsePro = false` | 簡易機能のみ |
| 個人PRO | RevenueCat または Firestore | `pro` | 個人向けPRO機能 |
| 団体PRO | Firestore | `organization_pro` | 個人向けPRO機能 + 団体機能 |
| 配信初期ユーザー特典 | Firestore | `early_supporter_pro` | 無料で個人PRO相当 |

## 現在の実装範囲

- Flutter SDK は `purchases_flutter` を使う。
- アプリ起動時に Firebase Auth UID を RevenueCat の App User ID として設定する。
- RevenueCat の public SDK key は `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` の dart-define から取得する。
- APIキー未設定、Firebase未設定、非モバイル環境ではアプリ起動を継続する。
- RevenueCat の `pro` Entitlement は `RevenueCatService.hasLifetimePro()` で取得する。
- Firestore の `users/{uid}/entitlements/current` はアプリから読み取りのみ許可し、書き込みは拒否する。
- `ProAccessPolicy` は RevenueCat の個人PRO、Firestore の団体PRO、Firestore の配信初期ユーザー特典を合成して判定する。

## RevenueCat 側の設定案

- Entitlement ID: `pro`
- Product ID: 初期の買い切り案では `lifetime_pro`
- Offering: 初期リリースでは個人PRO商品1件を表示する構成にする。
- Test Store: 開発・テスト用に使う。Test Store API key をストア提出ビルドに入れない。
- Production: iOS / Android それぞれの app-specific public SDK key を dart-define 経由で設定する。

将来サブスクリプションへ変える場合も、アプリ側の判定は `pro` Entitlement を維持する。商品IDだけを `monthly_pro` などへ追加・変更する。

## Firestore 側の entitlement

`users/{uid}/entitlements/current` に現在の利用権を保存する。

```json
{
  "plan": "early_supporter_pro",
  "source": "promo",
  "status": "active",
  "grantedAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

- `plan = pro`: 個人PRO。RevenueCat Webhookや管理者付与で使う。
- `plan = organization_pro`: 団体PRO。団体契約や学校単位の付与で使う。
- `plan = early_supporter_pro`: 配信開始から1週間以内に初回利用したユーザーへの無料PRO特典。
- `source = store`: RevenueCat / Store由来。
- `source = manual`: 管理者の手動付与。
- `source = promo`: 配信初期ユーザー特典やキャンペーン。

アプリは entitlement を作成・更新しない。初期DL特典の付与は、`users/{uid}.createdAt` が配信開始から1週間以内かをサーバ/Admin 側で判定して行う。

## Pro 判定

```dart
final canUsePro =
    hasRevenueCatPro || hasEarlySupporterPro || hasOrganizationPro;

final canUseOrganizationFeatures = hasOrganizationPro;
```

- `hasRevenueCatPro`: RevenueCat の `pro` Entitlement が active。
- `hasEarlySupporterPro`: Firestore の current entitlement が `early_supporter_pro` かつ active。
- `hasOrganizationPro`: Firestore の current entitlement が `organization_pro` かつ active。

## 初期スコープ外

- 購入画面の最終UI
- 購入復元UI
- RevenueCat Webhook による Firestore 同期
- 団体メンバー管理
- AI回数券などの consumable 商品

## 運用メモ

- RevenueCat の public SDK key は公開前提のキーだが、ストア提出ビルドには Test Store API key を入れない。
- RevenueCat の料金は月間 tracked revenue が一定額を超えると従量課金になるため、公開前に最新の Pricing を再確認する。
- 「配信開始から1週間以内」はストアのダウンロード日時ではなく、Firebase Auth / Firestore の初回ユーザー作成日時を基準にする。
