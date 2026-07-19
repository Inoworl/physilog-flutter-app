# RevenueCat Test Store設定・実行手順

最終更新: 2026-07-20

## 対象読者

- Physilog DevのRevenueCat catalogを管理する担当者
- devアプリでTest Store購入を再現する開発者

## 目的

個人・家族とTeamの月額・年額商品をTest Storeで購入し、Firebase UID単位のEntitlement更新を安全に検証する。Test Store keyやFirebase設定をreleaseへ混入させない。

## Catalogの正規構成

| Entitlement | Product ID | 周期 | Test Store価格 |
| --- | --- | --- | --- |
| `personal_family` | `personal_family_monthly` | 1か月 | USD 5.00 |
| `personal_family` | `personal_family_yearly` | 1年 | USD 50.00 |
| `team` | `team_monthly` | 1か月 | USD 9.80 |
| `team` | `team_yearly` | 1年 | USD 98.00 |

Offeringは`default`を使い、上記4商品をそれぞれ一意なPackageへ割り当てる。アプリはEntitlement IDでプランを判定し、Product IDで月額／年額を表示する。

Test Store商品の価格は作成後に編集できない。価格を直す場合は、OfferingとEntitlementの関連を控えたうえで商品を削除・再作成し、同じProduct IDを再度関連付ける。

## Dashboard設定

1. Physilog Devプロジェクトを選択する。
2. AppsでTest Store appが存在することを確認する。
3. Entitlementsに`personal_family`と`team`があることを確認する。
4. Test Store Productsに4商品を作成し、周期と価格を設定する。
5. 個人・家族2商品を`personal_family`へattachする。
6. Team 2商品を`team`へattachする。
7. Offering `default`へ4Packageを追加する。
8. 各PackageがTest Store商品を参照していることを確認する。

## Sandbox Testing Access

通常は検証用Firebase UIDだけをallowlistへ登録する。UIDはパスワード管理ツールなどの非Git領域で管理し、文書やPRへ貼らない。

2026-07-20時点では`Allowed App User IDs only`を選択し、4つの購入遷移アカウントを登録済みである。

- Catalog構築直後の疎通確認だけ一時的にAnybodyを使ってよい。
- 4つの購入遷移アカウントを入れ替えた場合はallowlistも同時に更新する。
- 新規匿名ユーザーで購入キャンセル・失敗を確認する場合は、その検証中だけ対象UIDを追加する。
- 検証終了後は不要なUIDを削除する。

## SDK key

- devのTest Store keyは`REVENUECAT_IOS_API_KEY`と`REVENUECAT_ANDROID_API_KEY`へ設定する。
- 値はGit除外済みのdev dart-defineファイルとCI Secretだけで管理する。
- 外部の秘密設定では`REVENUECAT_PHYSILOG_DEV_TEST_STORE_SDK_API_KEY`を原本として管理できる。
- API key値をログ、テスト、Issue、PRへ出さない。
- releaseモードでは`test_`プレフィックスのkeyを初期化時に拒否する。

RevenueCat SDKはアプリのライフサイクル中に1回だけconfigureする。hot restartなどでネイティブSDKが設定済みの場合、現在のApp User IDとFirebase UIDを比較し、異なる場合だけ`logIn`して同一顧客へ同期する。

## Android Firebase設定

Android devのapplication IDは`com.inoworl.physilog.dev`である。Firebase devには旧IDと新IDのアプリが存在するため、必ず新ID側から`google-services.json`を取得する。

ローカル配置:

```text
android/app/src/dev/google-services.json
```

CIでは`DEV_GOOGLE_SERVICES_JSON_BASE64`から同じファイルを復元する。ファイル本体とbase64値はGitへ追加しない。ローカルの秘密設定を更新する場合も、値を標準出力へ表示せずファイルから直接登録する。

次でGit除外だけを確認できる。

```bash
git check-ignore -v android/app/src/dev/google-services.json
```

## dev起動

```bash
fvm flutter run \
  --flavor dev \
  --dart-define-from-file=dart_define/dev_dart_define.json
```

起動後に次を確認する。

1. 新規匿名ユーザーが作られる。
2. 設定画面がメール未登録・Freeになる。
3. プラン画面に4商品が表示される。
4. Test Store購入ダイアログに選択中の商品ID、周期、価格が表示される。

## 購入結果

- Test valid purchase: CustomerInfoを再取得し、対応プランへ更新する。
- Test failed purchase: エラーメッセージを表示し、現在プランを変えない。
- Cancel: キャンセルメッセージを表示し、現在プランを変えない。
- 購入を復元: CustomerInfoを再取得し、同じFirebase UIDの権限を復元する。

## 更新・期限切れ

Test Storeのサブスクリプションは実時間より短縮される。2026-07-20時点の検証では、月額商品が約5分間隔で更新され、4回更新後に約25分で期限切れになった。年額商品は約1時間間隔で更新され、約5時間で期限切れになる。

1. RevenueCat Customer profileでSandbox dataを表示する。
2. Renewalイベントと次回更新時刻を確認する。
3. 更新後もアプリのプランが維持されることを確認する。
4. Expired表示になったら、アプリをバックグラウンドから復帰させる。
5. CustomerInfo再同期後、下位EntitlementがなければFreeへ戻ることを確認する。

短縮時間はRevenueCat側で変更される可能性があるため、実行前に公式Test Storeドキュメントを再確認する。

## トラブルシュート

### `productsUnavailable`

- Test Store商品に価格が登録されているか確認する。
- Offering `default`のPackageが新しい商品を参照しているか確認する。
- Entitlementへ正しい商品がattachされているか確認する。

### `No matching client found for package name`

- ローカルの`google-services.json`が旧Android ID用である。
- Firebase devの`com.inoworl.physilog.dev`から再取得する。
- CI成功だけではローカルファイルの鮮度は保証されない。CIはSecretから別の設定を復元するためである。

### FirebaseユーザーがRevenueCatに出ない

- Firebase Consoleで作成しただけではRevenueCat顧客にならない。
- 対象アカウントでアプリへログインし、UID同期を実行する。

## 保守メモ

Product ID、Entitlement ID、Offering、価格、周期、application ID、CI Secret名を変更した場合は、この手順と購入テストマトリクスを同時に更新する。
