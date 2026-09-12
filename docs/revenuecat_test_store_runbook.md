# RevenueCat Test Store設定・実行手順

最終更新: 2026-09-11

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

## 既存サブスクリプションの変更

アプリはRevenueCatのCustomerInfoを契約の正本として扱う。現在の商品ID、周期、Store、有効期限、更新予定、解約検知、請求問題、管理URLをCustomerInfoから取得する。

| 変更 | アプリの案内 | Android Replacement Mode | 反映タイミング |
| --- | --- | --- | --- |
| 個人・家族 → Team | アップグレード | `withTimeProration` | 即時 |
| Team → 個人・家族 | プラン変更 | `deferred` | 次回更新時 |
| 同一Tierの月額 ↔ 年額（同一Google Play Subscription） | 周期変更 | `withoutProration` | プランは即時、新料金は次回更新時 |

iOSでは旧商品IDとAndroid固有のReplacement Modeを渡さない。同一Subscription GroupのStoreKit挙動へ委ね、アプリの確認画面で想定タイミングを説明する。

[Google Play Billingの定期購入変更仕様](https://developer.android.com/google/play/billing/subscriptions#replacement-modes)では、同一Subscription内のBase Plan変更に使用できるReplacement Modeが`CHARGE_FULL_PRICE`または`WITHOUT_PRORATION`に限定される。現在の月額／年額は同じSubscriptionのBase Planなので、`withoutProration`を使い「プラン内容はすぐに切り替わり、新しい料金は次回更新時に請求」と案内する。完全な次回更新時切替が必要なら、月額／年額を別Subscriptionへ分ける商品設計変更が必要になる。

### Test Storeでの変更確認

1. 現在商品が「利用中」で無効化され、再購入できないことを確認する。
2. 個人・家族の有効契約からTeamを選び、「すぐに反映」と表示されることを確認する。
3. Test valid purchaseを選び、CustomerInfoと画面がTeamへ更新されることを確認する。
4. Teamの有効契約から個人・家族を選び、「次回更新時に反映」と表示されることを確認する。
5. Test valid purchase後に「変更予約中」と変更先が表示されることを確認する。
6. アプリを終了・再起動し、同じFirebase UIDで変更予約が復元されることを確認する。
7. CustomerInfoで変更先商品がactiveになった後、予約表示が消えることを確認する。
8. 変更操作をCancelまたはTest failed purchaseで終了し、現在契約と権限が変わらないことを確認する。

変更予約はUID単位でHiveへ保存する補助表示であり、契約の正本ではない。別端末、再インストール後、またはStore側で予約を取り消した場合は、契約管理画面とCustomerInfoを正とする。

## 解約・契約管理

1. 現在契約カードの「契約を管理」を押す。
2. CustomerInfoの`managementURL`がある場合、外部のStore契約管理画面が開くことを確認する。
3. `managementURL`がない場合、購入したStoreのアカウント設定から確認する案内が表示されることを確認する。
4. 解約後もCustomerInfoがactiveかつ期限内なら有料権限を維持することを確認する。
5. 画面に「有効期限で終了予定」と有効期限が表示されることを確認する。
6. Billing Issueがある場合、「支払い情報を確認してください」と表示されることを確認する。
7. 期限切れ後、CustomerInfo再同期で下位EntitlementがなければFreeへ戻ることを確認する。

### 自動同期の回帰確認

2026-09-11追加。以下は変更後ビルドでの手動確認手順であり、実機検証済みの記録ではない。

1. 有料契約の解約後、ストアの管理画面から戻り、「購入を復元」を押さずに終了予定が表示されることを確認する。
2. アプリを開いたまま期限を迎え、RevenueCatで失効が確定した後、手動更新せずFreeへ戻ることを確認する。自動更新成功時は有料プランを維持する。
3. プラン画面以外に移動してからバックグラウンドへ送り、契約変更後の復帰でプランと利用制限が更新されることを確認する。
4. 期限付近でオフラインにしても端末時刻だけでFreeに変わらず、通信回復後の再確認で正しい状態になることを確認する。
5. dev環境で管理者が特別利用権を付与・取消・削除し、手動更新なしに反映されることを確認する。有効期限指定時は期限到達も確認する。
6. アカウント切替・サインアウト後、前のユーザーの購入状態や特別利用権が表示されないことを確認する。
7. 復旧導線として「購入を復元」も従来どおり動くことを確認する。

再確認はフォアグラウンドで通常1分後、期限直後は30秒後を基準とする。通信中・購入中・復元中は重複要求しない。ストア側の反映待ちをアプリの自動同期失敗と混同せず、匿名化した時刻・プラン・結果だけを記録する。

## 実Storeの手動確認

Test StoreはApple／Google固有の請求状態を完全には再現しない。リリース前に次を実施する。

### Apple Sandbox／TestFlight

- 4商品が同一Subscription Groupにあり、Teamが上位レベルである。
- 個人・家族 → TeamがAppleの確認画面とCustomerInfoで即時反映される。
- Team → 個人・家族が次回更新時変更として表示される。
- 月額 ↔ 年額変更の請求日と反映タイミングが確認画面の説明と一致する。
- 解約後も期限までは権限を維持し、期限切れ後にFreeへ戻る。
- 購入復元と「契約を管理」がAppleのSandboxアカウントで動作する。

### Google Play Internal Testing

- 4つのBase Planが購入可能で、RevenueCatのStore product identifierと一致する。
- 個人・家族 → Teamで旧商品IDと`withTimeProration`が適用される。
- Team → 個人・家族で`deferred`が適用される。
- 同一Subscription内の月額 ↔ 年額で`withoutProration`が適用され、プランは即時、新料金は次回更新になる。
- Google Playの購入確認画面に差額、次回請求日、変更先が正しく表示される。
- 解約、Billing Retry、Grace Period／Account HoldでCustomerInfoと画面表示が一致する。
- 購入復元と「契約を管理」がGoogle Playテストアカウントで動作する。

### 証跡

次だけを記録する。

- 実施日
- OS、端末、配信チャネル
- 変更元／変更先の商品ID
- Store確認画面の反映タイミング
- CustomerInfoのactive商品、期限、更新状態
- アプリの表示プラン
- PASS／FAILと、FAIL時のIssue番号

メール、パスワード、UID、API key、レシート、設定ファイル本文は記録しない。

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

Product ID、Entitlement ID、Offering、価格、周期、Subscription Group／Base Plan、Replacement Mode、application ID、CI Secret名を変更した場合は、この手順と購入テストマトリクスを同時に更新する。
