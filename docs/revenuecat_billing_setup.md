# RevenueCat 課金基盤メモ

最終更新: 2026-07-20

## 目的

PhysiLog の利用権を、Free / 個人・家族 / Team の3段階サブスクリプションで扱えるようにする。購入状態は RevenueCat entitlement を正とし、Firestore entitlement はサーバー側・管理者側の特別付与(グランドファザリング、手動付与)に使う。

旧方針の「7日無料トライアル + 買い切り `lifetime_pro`」および「`pro` / `organization_pro` / `early_supporter_pro`」は採用しない。

## プラン

| プラン | 上限 / 機能 | 本番価格案（未確定） | 備考 |
| --- | --- | --- | --- |
| Free | 選手1人 / 種目3つ | 無料 | 体験・入口用 |
| 個人・家族 | 選手5人 / 種目無制限 | 月100円 / 年1,000円 | 個人利用、家族利用向け |
| Team | 無制限 + 計測会 + 成長共有 + CSV | 月980円 / 年8,980円前後 | 本命。1ヶ月無料あり |

この価格案は本番ストア向けであり、devのTest Store価格とは一致させる必要がない。Test Storeの正規価格は`revenuecat_test_store_runbook.md`を参照する。

## プラン別 capability

単純な `isPro` ではなく、プラン別 capability として扱う。判定は `PlanCapabilities` がドメイン層で持つ。

| Capability | Free | 個人・家族 | Team |
| --- | --- | --- | --- |
| 選手数 | 1人 | 5人 | 無制限 |
| 種目数 | 3つ | 無制限 | 無制限 |
| 計測会 | 不可 | 不可 | 可 |
| 成長共有 | 不可 | 不可 | 可 |
| CSV | 不可 | 不可 | 可 |

## 現在の実装範囲

- Flutter SDK は `purchases_flutter` を使う。
- アプリ起動時に Firebase Auth UID を RevenueCat の App User ID として設定する。
- RevenueCat の public SDK key は `REVENUECAT_IOS_API_KEY` / `REVENUECAT_ANDROID_API_KEY` の dart-define から取得する。
- APIキー未設定、Firebase未設定、非モバイル環境ではアプリ起動を継続する。
- `BillingIdentitySync`がFirebase Auth UIDをRevenueCat App User IDへ同期し、初回だけSDKをconfigureする。
- hot restartなどでネイティブSDKが設定済みの場合は再configureせず、App User IDが異なる場合だけ`logIn`する。
- `BillingRepository`がOffering取得、購入、復元、CustomerInfo更新を抽象化する。
- `BillingController`が4商品の表示と購入・キャンセル・失敗・復元のUI状態を管理する。
- `PlanAccessController`がRevenueCat CustomerInfo更新を購読し、最新の利用権をプラン表示へ反映する。
- プラン画面では個人・家族／Teamの月額・年額を選択し、Test Store購入と購入復元を実行できる。
- Firestore の `users/{uid}/entitlements/current` はアプリから読み取りのみ許可し、書き込みは拒否する。
- `PlanAccessPolicy` は RevenueCat の購入状態と Firestore の legacy / manual entitlement を合成し、`PlanTier`(free / personalFamily / team)を解決する。Team 判定を個人・家族より優先する。

## RevenueCat 側の設定

- Entitlement ID:
  - `personal_family`: 個人・家族プラン
  - `team`: Team プラン
- Product ID:
  - `personal_family_monthly`
  - `personal_family_yearly`
  - `team_monthly`
  - `team_yearly`
- Offering:
  - `default`: 個人・家族と Team を表示する通常オファリング
- Team の1ヶ月無料は、RevenueCat 側の仕組みではなく App Store Connect / Google Play Console の introductory offer(無料トライアル)として各サブスクリプション商品に設定する。RevenueCat は store 側のトライアル状態をそのまま entitlement 判定に反映する。
- Test Store: 開発・テスト用に使う。Test Store API key をストア提出ビルドに入れない。
- Production: iOS / Android それぞれの app-specific public SDK key を dart-define 経由で設定する。

## Firestore 側の entitlement

RevenueCat の購入状態は RevenueCat entitlement を正とする。Firestore の `users/{uid}/entitlements/current` は、サーバー側・管理者側の特別付与だけに使う。

```json
{
  "plan": "manual_team",
  "source": "manual",
  "status": "active",
  "grantedAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

- `plan = legacy_personal_family`: 値上げ前の個人・家族プラン据え置き(グランドファザリング)。
- `plan = legacy_team`: 値上げ前の Team プラン据え置き(グランドファザリング)。
- `plan = manual_team`: 管理者が手動付与する Team 相当権限。
- `source = store`: RevenueCat / Store由来。
- `source = manual`: 管理者の手動付与。
- `source = promo`: キャンペーン付与。

アプリは entitlement を作成・更新しない。付与・更新は Admin / サーバー側で行う。

## グランドファザリング設計

将来の値上げ時に、値上げ前からの契約者を旧価格相当の扱いで据え置くための仕組み。

- 値上げ時、据え置き対象ユーザーへ Admin / サーバー側で `legacy_personal_family` または `legacy_team` を付与する。
- アプリ側は RevenueCat entitlement と Firestore legacy entitlement のどちらが有効でも同じ `PlanTier` に解決するため、価格改定によるコード変更を局所化できる。
- ストア側の価格据え置き(既存サブスクライバー価格の維持)を使う場合も、Firestore legacy entitlement を併用して判定を安定させる。

## プラン判定

```dart
final tier = PlanAccessStatus(
  hasRevenueCatPersonalFamily: ...,
  hasRevenueCatTeam: ...,
  hasLegacyPersonalFamily: ...,
  hasLegacyTeam: ...,
  hasManualTeam: ...,
).tier;

final capabilities = PlanCapabilities.forTier(tier);
```

- `hasRevenueCatPersonalFamily`: RevenueCat の `personal_family` Entitlement が active。
- `hasRevenueCatTeam`: RevenueCat の `team` Entitlement が active。
- `hasLegacyPersonalFamily` / `hasLegacyTeam` / `hasManualTeam`: Firestore の current entitlement が該当 plan かつ active。
- Team 系がひとつでも有効なら `PlanTier.team`、次に個人・家族系が有効なら `PlanTier.personalFamily`、いずれもなければ `PlanTier.free`。

## 現在のスコープ外

- App Store / Google Play の本番商品作成
- RevenueCat Webhook による Firestore 同期
- チームメンバー管理の詳細実装
- 学校向け請求・見積・請求書払い対応

## 運用メモ

- RevenueCat の public SDK key は公開前提のキーだが、ストア提出ビルドには Test Store API key を入れない。
- RevenueCat の料金は月間 tracked revenue が一定額を超えると従量課金になるため、公開前に最新の Pricing を再確認する。
- Team の1ヶ月無料トライアルの提供条件(初回のみ等)は、App Store / Google Play それぞれの introductory offer 仕様に従う。
