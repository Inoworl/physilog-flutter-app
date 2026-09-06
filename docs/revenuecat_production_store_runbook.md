# RevenueCat本番ストア設定・検証手順

最終更新: 2026-09-07

## 目的

App Store／Google Playのdev／prod商品を対応するRevenueCat Appへ接続し、
Sandbox／Internal Testingで購入ライフサイクルとアプリのプラン表示が一致することを確認する。
Test Storeの公開SDKキー、secret API key、ストア秘密鍵を配信物や証跡へ含めない。

## 正本

- RevenueCat project: `Physilog`（`ec10fe6b`）
- Entitlement: `personal_family`、`team`
- Offering: `default`
- Package: `personal_family_monthly`、`personal_family_yearly`、`team_monthly`、`team_yearly`
- Team無料トライアル: 1か月
- 商品IDと価格案: `tools/revenuecat/revenuecat_catalog.yaml`

| Environment | Bundle ID / Package name | RevenueCat App Store App | RevenueCat Google Play App |
| --- | --- | --- | --- |
| dev | `com.inoworl.physilog.dev` | `appf453300e51` | `appbbd1f7da16` |
| prod | `com.inoworl.physilog` | `appcf636b29a7` | `app07c4ac722f` |

## App Store Connect

1. devとprodの各Appでサブスクリプショングループを1つずつ作成する。
2. 各グループへカタログに定義した4つのProduct IDを作成する。
3. Teamを個人・家族より上位のSubscription Levelへ配置する。
4. 月額／年額の期間とJPY価格をカタログの`intended_price`に合わせる。
5. Team月額／年額へ1か月のFree Trialを設定する。
6. Users and Access > Integrations > In-App PurchaseでRevenueCat専用キーを作成する。
7. `.p8`、Key ID、Issuer IDをRevenueCatのApp Store Appへ登録する。
8. 商品インポートと価格同期用のApp Store Connect APIキーをRevenueCatのdev／prod両方へ登録する。
9. App Store Connectで、各RevenueCat App固有のプロダクション／SandboxのServer Notification URLを設定する。

In-App Purchaseキーは一度しかダウンロードできない。内容をログ、Issue、PR、Gitへ出さず、
承認された秘密情報保管先へ直ちに保存する。

### 料金プランタイプと反映確認

通常の月額／年額商品は`UPFRONT`を選ぶ。これは契約期間ごとにその期間分を前払いする
通常の自動更新サブスクリプションである。12か月契約を月払いする`MONTHLY`は別の料金形態であり、
今回の4商品には使用しない。

初期検証ではdev／prodとも提供地域を日本（`JPN`）だけに限定し、
`availableInNewTerritories`を無効にする。価格と無料トライアルを設定した後は、
App Store Connect APIまたは画面で次を読み戻す。

- Team月額／年額はSubscription Level 1、個人・家族月額／年額はLevel 2である。
- 4商品の期間、JPY価格、`UPFRONT`、日本だけの提供地域が正本と一致する。
- Team月額／年額だけに1か月のFree Trialがあり、個人・家族にはIntroductory Offerがない。
- 月額商品には月額画面、年額商品には年額画面のApp Review Screenshotがあり、asset状態が`COMPLETE`である。

Appleは商品メタデータのSandbox反映に最大1時間かかる場合があるとしている。
現行APIでは親Subscriptionの`state`とSubscription Versionの`state`が別に返る。
親Subscription APIの`MISSING_METADATA`だけで不足と判定せず、最新Versionが`PREPARE_FOR_SUBMISSION`で、
App Store Connect画面も「提出準備中」であることを確認する。画面上の必須項目が揃っていても、
Sandboxで商品を取得できるまでは購入検証をPASSにしない。

### 現在のApp Store Connect設定（2026-09-07）

- dev／prodの各Appへ`PhysiLog Plans`グループと4商品を作成済み。
- 日本向け`UPFRONT`の価格を、個人・家族 月額100円／年額1,000円、Team 月額980円／年額8,980円で設定済み。
- Team月額／年額へ日本向け1か月Free Trialを設定済み。
- 日本語のグループ名、商品名、説明と、支払い周期別のApp Review Screenshotを設定済み。
- API読み戻しでは8商品すべての値と画像assetの`COMPLETE`を確認済み。
- 最新Subscription Versionは8商品すべて`PREPARE_FOR_SUBMISSION`で、画面上で8商品すべてが「提出準備中」であることを確認済み。
- 親Subscription APIの`state`は`MISSING_METADATA`のまま残るため、現行Versionと画面の状態を正とする。
- In-App PurchaseキーとApp Store Connect APIキーはRevenueCatのdev／prod両方で`Valid credentials`を確認済み。
- dev／prodそれぞれのプロダクション／Sandbox Server Notification URLをApp Store Connectへ設定し、画面で読み戻し済み。URL値は証跡へ残さない。
- 最初のサブスクリプショングループは新しいアプリバージョンとともに提出する必要がある。
- App Store Connectには最新のApple Developer Program契約への同意警告が出ている。Account Holderの同意後に審査提出とSandbox／TestFlight実測を行う。

## Google Play Console

1. デベロッパーアカウントのGoogle Payments販売アカウントを設定する。
2. devとprodの各AppへSubscription `personal_family`と`team`を作成する。
3. 各SubscriptionへBase Plan `monthly`と`yearly`を作成する。
4. 自動更新期間とJPY価格をカタログの`intended_price`に合わせる。
5. Teamの両Base Planへ1か月のFree Trial Offerを設定する。
6. RevenueCat用Service Accountへ、後述する対象アプリ権限とアカウント権限を付与する。
7. Service Account credentialをRevenueCatのGoogle Play Appへ登録する。
8. Real-time Developer NotificationsはこのIssueでは構成しない。必要になった時点で別Issueとして追加する。
9. Internal testing trackへ検証ビルドを配信し、テスターを登録する。

Service Accountのアプリ権限は環境ごとに分離する。

- dev用Service AccountはPhysiLog Devだけを対象にし、「アプリ情報の閲覧（読み取り専用）」と「ストアでの表示の管理」を付与する。
- prod用Service AccountはPhysiLogだけを対象にし、同じ2権限を付与する。
- 「売上閲覧と注文管理はアカウント全体」というPlay Consoleの仕様上、財務・注文権限だけはアプリ単位に分離できない。

既存のdev用Service AccountにはPhysiLogとPhysiLog Devの両方が登録されている。prod credentialをRevenueCatで検証してから、dev用Service AccountからPhysiLogのアプリ権限を削除する。切り替え前に削除して購入検証を停止させない。

Google Play Service Credentialは、新規作成や権限変更からRevenueCatで有効になるまで最大36時間かかる場合がある。
商品カタログとSubscription／Base Planの検証が成功し、購入検証だけが権限不足の場合は、
権限の付け直しや鍵の再作成を直ちに行わず、Project IDとPlay Consoleの付与内容を読み戻してから再検証する。
3検証がすべて成功するまでは、切り替え元credentialの対象アプリ権限を削除しない。

RevenueCatのGoogle store identifierは`<subscription_id>:<base_plan_id>`形式にする。
`Valid credentials`だけでは環境分離を確認できない。Credentials Validation Detailsを開き、
次のProject IDと購入・商品・Base Planの3検証を確認する。

| RevenueCat environment | Expected service account Project ID |
| --- | --- |
| dev | `physilog-dev` |
| prod | `physilog-cb6cd` |

Play Consoleのアカウント権限は複数アプリへ作用するため、別環境のService Accountでも
検証項目だけは成功する場合がある。Project ID不一致を成功として扱わない。

### 現在のGoogle Play credential設定（2026-09-07）

- prod用Service AccountをPlay Consoleへ招待済みで、状態は有効。
- prod用Service Accountの対象アプリはPhysiLog（`com.inoworl.physilog`）だけ。
- アプリ情報閲覧、ストア表示管理、売上・注文閲覧、注文・定期購入管理を画面で読み戻し済み。
- RevenueCat prod AndroidへProject ID `physilog-cb6cd`のcredentialを保存済み。
- RevenueCatの3検証中、商品カタログとSubscription／Base Planは成功。購入検証はPlay権限の反映待ち。
- Google Payments販売アカウントが未選択のため、Subscription／Base Plan作成は未着手。

## RevenueCat

1. dev／prod projectにApp Store AppとGoogle Play Appが存在することを確認する。
2. 各Appのstore credentialが有効であることを確認する。
3. dev／prodそれぞれへApp Store／Google Playの8商品を取り込む。
4. 各商品を`personal_family`または`team` Entitlementへ関連付ける。
5. `default` Offeringの各PackageへiOS／Androidの同等商品を2件ずつ関連付ける。
6. `default`をCurrent Offeringにする。
7. platform別Public SDK KeyをGitHubのdev／prod Environment secretへ保存する。

カタログ同期:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env dev \
  --env-file "$REVENUECAT_ENV_FILE" \
  --dry-run

ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env dev \
  --env-file "$REVENUECAT_ENV_FILE" \
  --apply

ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env prod \
  --env-file "$REVENUECAT_ENV_FILE" \
  --dry-run

ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env prod \
  --env-file "$REVENUECAT_ENV_FILE" \
  --apply
```

## 配信キーの確認

GitHub Environment secret:

- dev: `REVENUECAT_DEV_IOS_API_KEY`、`REVENUECAT_DEV_ANDROID_API_KEY`
- prod: `REVENUECAT_PROD_IOS_API_KEY`、`REVENUECAT_PROD_ANDROID_API_KEY`

各値は対応Appのpublic SDK key（iOSは`appl_`、Androidは`goog_`）を使う。
Test Store key、secret API key、別platformのkeyを設定すると配信workflowはビルド前に失敗する。

## 実ストア検証

Apple Sandbox／TestFlightとGoogle Play Internal Testingの両方で確認する。

| ケース | 期待結果 |
| --- | --- |
| 4商品の新規購入 | 選択PackageとEntitlementが一致し、アプリ表示が即時更新される |
| 購入復元 | 同じFirebase UID／RevenueCat App User IDで契約が復元される |
| 個人・家族からTeam | ストア規則に従って上位プランへ変更される |
| Teamから個人・家族 | ストア規則に従って次回更新予定が表示される |
| 月額／年額変更 | 現在契約と予約変更が重複せず表示される |
| 解約 | 有効期限まではEntitlementを維持する |
| 期限切れ | Entitlementが非activeになりFree表示へ戻る |
| Team trial | 1か月Trialとして開始され、Team Entitlementがactiveになる |
| 購入キャンセル／失敗 | 現在契約とEntitlementを変更しない |

## 証跡

秘密値、実メールアドレス、氏名、ストア取引ID、Firebase UIDを記録しない。
各実行は次の形式で`docs/revenuecat_purchase_test_matrix.md`へ追記する。

| 日時（JST） | Platform | Build | 匿名ケースID | 操作 | アプリ表示 | RevenueCat状態 | 結果 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD HH:mm | iOS／Android | version+build | CASE-XX | 購入／復元等 | Free／個人・家族／Team | Entitlement概要 | PASS／FAIL |

未実施の実機検証を自動テスト成功だけでPASSに変更しない。
