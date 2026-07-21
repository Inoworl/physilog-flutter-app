# RevenueCat Subscription Completion Implementation Plan

> **Goal:** Issue #91・#98・#96・#97を依存順に分割実装し、匿名認証から安全に購入へ進める導線、制限箇所からのUpgrade導線、既存契約の変更・管理、本番ストア接続を完成させる。

## 実装順とブランチ

各Issueは直前のPRをマージした最新`origin/dev`から専用worktreeを作り、1 Issue = 1 PRで進める。

1. `feature/issue-91-purchase-auth-gate`
2. `feature/issue-98-upgrade-entry-points`
3. `feature/issue-96-subscription-management`
4. `feature/issue-97-production-store-connection`

各PRは関連テスト、`fvm flutter analyze`、CIを通し、レビュー指摘がないことを確認してからマージする。PR本文には`Closes #<番号>`を入れる。

## 共通アーキテクチャ方針

- Firebase Authの匿名ユーザーには`linkWithCredential`を使い、Firebase UIDを変更しない。
- RevenueCat App User IDはFirebase UIDを唯一の識別子とし、購入状態の正本はCustomerInfo／Entitlementとする。
- UIは画面遷移と表示に限定し、購入状態・変更種別・Replacement ModeはBillingドメインとRepositoryへ閉じ込める。
- Loading／ErrorをFreeへフォールバックしない。
- 公開SDK Keyを含む設定値もGitへ直書きせず、GitHub Environment secretsからビルド時に注入する。
- Test Store、Apple Sandbox／TestFlight、Google Play Internal Testing、prodを明示的に分離する。

---

## PR 1: Issue #91 Upgrade前のメール登録必須化

### 受け入れ条件

- 匿名ユーザーが購入ボタンを押すとメール／パスワード登録画面へ遷移し、登録完了前はRepositoryの購入処理が呼ばれない。
- 登録をキャンセルするとプラン画面へ戻り、購入処理は呼ばれない。
- 登録成功時は同じ商品Package IDの購入処理を自動再開する。
- 登録済みユーザーは追加画面なしで直接購入できる。
- `linkWithCredential`前後でFirebase UIDが同一である。
- Billing identity同期に使うApp User IDも同じUIDのままである。
- 購入成功後は既存のCustomerInfo／Entitlement更新経路でプランが切り替わる。

### Task 1: 購入認証ゲートのWidgetテストを先に追加

**Files:**
- Modify: `test/features/billing/presentation/plan_screen_test.dart`

1. Firebase `User`の匿名／登録済みFakeを追加する。
2. 匿名ユーザーで購入ボタンを押したとき、登録画面を表示し購入が0回である失敗テストを書く。
3. 登録画面を閉じた場合に購入0回の失敗テストを書く。
4. 登録成功時に元のPackage IDで購入1回の失敗テストを書く。
5. 登録済みユーザーが直接購入できる失敗テストを書く。
6. `fvm flutter test test/features/billing/presentation/plan_screen_test.dart`を実行し、新規テストが期待理由で失敗することを確認する。

### Task 2: 登録画面から成功結果を返す

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `test/features/settings/presentation/settings_screen_test.dart`

1. `AccountEmailAuthMode.register`成功時だけ、呼び出し元へ`true`を返してpopする。
2. 通常の設定画面からの呼び出しは結果を無視し、既存UXを維持する。
3. 登録成功と戻る操作の結果をWidgetテストで固定する。

### Task 3: Plan画面へ購入前ゲートを実装

**Files:**
- Modify: `lib/features/billing/presentation/plan_screen.dart`

1. `authStateProvider`からFirebaseユーザーを取得する。
2. `isAnonymous == true`または登録メールなしの場合、`settingsAccountAuth/register`を`await`する。
3. `true`が返った場合のみ同じPackage IDで`BillingController.purchase`を呼ぶ。
4. 登録済みなら直接`purchase`を呼ぶ。
5. 認証状態がLoading／Error／nullの場合は購入せず、ユーザーへ再試行可能な案内を表示する。

### Task 4: UID維持と回帰を検証

**Files:**
- Verify: `test/features/auth/application/auth_service_test.dart`
- Verify: `test/features/billing/application/billing_identity_sync_test.dart`

1. 既存の`linkEmailAndPassword` UID維持テストを実行する。
2. Billing identity同期が同じUIDを再ログインしないことを確認する。
3. 関連テスト、全テスト、analyzeを実行する。
4. PRを作成し、CI成功後にマージする。

---

## PR 2: Issue #98 制限箇所からUpgrade画面への導線

### 受け入れ条件

- Freeの選手1人／種目3件、個人・家族の選手5人到達時に保存処理を開始せず、「プランを見る」「キャンセル」を表示する。
- 「プランを見る」で共通の`settingsPlan`へ遷移し、「キャンセル」で元画面に留まる。
- Free／個人・家族のTeam限定機能案内から同じプラン画面へ遷移できる。
- プラン情報Loading／Error時は制限ダイアログやUpgrade導線を表示せず、既存の待機／再読込状態を維持する。
- プラン画面での実購入にはIssue #91の認証ゲートが必ず適用される。
- Widget TestとIntegration Testで主要導線を確認できる。

### Task 1: 共通Upgradeプロンプトの失敗テスト

**Files:**
- Modify: `test/features/manage/presentation/manage_screen_test.dart`
- Modify: `test/features/home/presentation/home_screen_test.dart`
- Modify: `test/features/measurement/presentation/session_setup_screen_test.dart`

1. 各制限ダイアログの2アクションとキャンセル挙動をテストする。
2. `settingsPlan`への遷移をテストする。
3. Loading／Errorで誤表示しない回帰テストを維持する。

### Task 2: 共通プロンプトと各画面の遷移

**Files:**
- Create: `lib/features/billing/presentation/upgrade_prompt.dart`
- Modify: `lib/features/manage/presentation/manage_screen.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/features/measurement/presentation/session_setup_screen.dart`

1. 共通ダイアログは遷移を直接行わず、ユーザー選択をboolで返す。
2. 呼び出し画面が`true`時だけ`context.pushNamed('settingsPlan')`を実行する。
3. 既存上限制御と保存前停止を変更しない。

### Task 3: Integration Test

**Files:**
- Create: `integration_test/upgrade_entry_point_test.dart`

1. Fake Repository／ProviderでFree上限状態を構成する。
2. 制限操作→ダイアログ→プラン画面の経路を確認する。
3. キャンセル時に元画面へ残ることを確認する。
4. PRを作成し、CI成功後にマージする。

---

## PR 3: Issue #96 既存サブスクリプション変更・解約管理

### 受け入れ条件

- CustomerInfoから現在Tier、商品ID、月額／年額、Store、有効期限、更新予定、解約検知、請求問題、管理URLを取得できる。
- 現在の商品を「利用中」と表示して再購入を無効化する。
- 新規購入と、アップグレード／ダウングレード／周期変更を文言と確認画面で区別する。
- Android変更購入では旧Subscription product IDとReplacement ModeをSDKへ渡す。
- 個人・家族→Teamは即時変更、Team→個人・家族と同一Tierの月額／年額変更は次回更新時変更とする。
- iOSは同一Subscription GroupのStoreKit挙動へ委ね、変更タイミングを確認画面で説明する。
- キャンセル／失敗時に現在契約と権限を変更しない。
- Deferred変更はUID単位のローカル予約スナップショットへ保存し、再起動後も表示する。CustomerInfoで対象商品が有効になった時点で消し込む。ストア側で予約を取り消した可能性は契約管理画面で確認するよう案内する。
- `managementURL`を外部ブラウザで開き、null／起動失敗時は案内する。
- 解約検知後も`isActive`／期限までは有料権限を維持し、期限切れ後に既存Entitlement監視でFreeへ戻す。

### Task 1: 契約状態と変更ポリシーをTDDで定義

**Files:**
- Create: `lib/features/billing/domain/billing_subscription.dart`
- Create: `lib/features/billing/domain/billing_purchase_request.dart`
- Create: `lib/features/billing/domain/subscription_change_policy.dart`
- Create: `test/features/billing/domain/billing_subscription_test.dart`
- Create: `test/features/billing/domain/subscription_change_policy_test.dart`

1. 現在商品をCatalogからTier／周期へ変換する。
2. 新規／upgrade／downgrade／crossgradeを判定する。
3. Android Replacement Modeを`withTimeProration`と`deferred`へ明示変換する。

### Task 2: Repository境界とRevenueCat adapterを拡張

**Files:**
- Modify: `lib/features/billing/domain/billing_repository.dart`
- Modify: `lib/features/billing/data/revenuecat_billing_repository.dart`
- Modify: `lib/features/billing/data/no_billing_repository.dart`
- Modify: `test/features/billing/data/revenuecat_billing_repository_test.dart`
- Modify: `test/features/billing/support/fake_billing_repository.dart`

1. CustomerInfo snapshotへ有効商品、EntitlementInfo、Store、期限、更新、管理URLを写像する。
2. 購入APIをPackage IDだけでなく変更リクエストで受ける。
3. Androidだけ`StoreProductChangeInfo`をSDKへ渡す。
4. 管理URL取得とエラー変換を追加する。

### Task 3: 変更予約の永続化とController

**Files:**
- Create: `lib/features/billing/domain/pending_subscription_change_repository.dart`
- Create: `lib/features/billing/data/hive_pending_subscription_change_repository.dart`
- Modify: `lib/features/billing/application/billing_controller.dart`
- Modify: `lib/providers/app_providers.dart`
- Modify: `test/features/billing/application/billing_controller_test.dart`

1. UID別に変更元・変更先・作成時刻を保存する。
2. 成功したDeferred変更だけ保存し、キャンセル／失敗では保存しない。
3. 起動時に読み込み、CustomerInfoの現在商品が変更先になれば削除する。

### Task 4: 契約管理UIとテスト

**Files:**
- Modify: `lib/features/billing/presentation/plan_screen.dart`
- Modify: `test/features/billing/presentation/plan_screen_test.dart`
- Create: `integration_test/subscription_change_flow_test.dart`

1. 現在契約カード、利用中状態、変更確認ダイアログ、予約表示、契約管理ボタンを実装する。
2. URL起動を注入可能にし、Widget Testで成功／URLなし／失敗を検証する。
3. Test Storeで新規・変更・キャンセル・失敗・再起動復元を確認する。
4. Apple Sandbox／Google Play Internalの実機確認項目をrunbookへ記録する。
5. PRを作成し、CI成功後にマージする。

---

## PR 4: Issue #97 App Store／Google Play本番接続

### 受け入れ条件

- App Store ConnectとGoogle Play Consoleに購入可能な個人・家族／Teamの月額・年額が設定される。
- Appleは同一Subscription GroupでTeamを上位レベルにする。
- Google PlayはSubscription／Base Plan IDの形式をRevenueCatのstore identifierと一致させる。
- Team無料トライアルの期間を1つに確定し、両ストアとドキュメントで一致させる。
- RevenueCat prodへiOS／Android App、Entitlement、Offering、Package、Store Productの関連を設定する。
- dev配信とprod配信は各ストアのplatform-specific Public SDK Keyを使用し、Test Store Keyを使わない。
- prod iOS／Android workflowは対応Public SDK Keyが空ならビルド前に明示失敗する。
- releaseで`test_`キーを拒否する既存ランタイムガードを維持する。
- Apple Sandbox／TestFlightとGoogle Play Internal Testingで購入・復元・更新・解約・期限切れ・Teamトライアルを確認し、機密値なしの結果を記録する。

### Task 1: 本番カタログをplatform別にTDDで拡張

**Files:**
- Modify: `tools/revenuecat/revenuecat_catalog.yaml`
- Modify: `tools/revenuecat/sync_revenuecat_catalog.rb`
- Modify: `tools/revenuecat/sync_revenuecat_catalog_test.rb`
- Modify: `tools/revenuecat/README.md`

1. environmentへiOS／AndroidそれぞれのRevenueCat App IDを持たせる。
2. productへStore別identifierを持たせ、1 Packageへ両Store productをattachできるよう同期処理を拡張する。
3. app ID／product ID欠落をapply前に失敗させる。
4. dry-runとFake API applyテストを先に失敗させてから実装する。

### Task 2: CI/CDキー分離と静的ガード

**Files:**
- Modify: `.github/workflows/deploy_dev_ios.yml`
- Modify: `.github/workflows/deploy_dev_android.yml`
- Modify: `.github/workflows/deploy_prod_ios.yml`
- Modify: `.github/workflows/deploy_prod_android.yml`
- Modify: `test/release/revenuecat_environment_setup_test.dart`
- Create: `tools/revenuecat/validate_public_sdk_key.rb`
- Create: `tools/revenuecat/validate_public_sdk_key_test.rb`

1. dev/prod × iOS/AndroidのPublic SDK KeyをGitHub Environment secretから個別注入する。
2. 空値、Test Store prefix、想定外platform prefixを値を出力せず検証する。
3. workflow構造テストで全4配信経路の検証stepを固定する。

### Task 3: 外部コンソール設定

1. App Store Connectで4 Subscription、Groupレベル、JPY価格、Team introductory offerを設定する。
2. Google Play ConsoleでSubscription、月額／年額Base Plan、JPY価格、Team trialを設定する。
3. App Store Server Notifications／In-App Purchase Keyと、Google Service Credentials／RTDNをRevenueCatへ接続する。
4. RevenueCat prodのiOS／Android App IDをカタログへ反映し、prod dry-run→applyを実行する。
5. Public SDK KeyをGitHub Environment secretsへ保存する。値はログ・PR・Issueへ出さない。

### Task 4: 実ストア検証と証跡

**Files:**
- Modify: `docs/revenuecat_billing_setup.md`
- Modify: `docs/revenuecat_purchase_test_matrix.md`
- Create: `docs/revenuecat_production_store_runbook.md`

1. Apple Sandbox／TestFlightで4商品の購入・復元・更新・解約・期限切れ・Team trialを確認する。
2. Google Play Internal Testingで同じ項目を確認する。
3. RevenueCat Customer／Entitlementとアプリ表示の一致を確認する。
4. 証跡には日時、build、匿名化したテストケースID、結果だけを残す。
5. PRを作成し、CI成功後にマージする。

---

## 各PRの完了前検証

```bash
fvm dart format <changed dart files>
fvm flutter test <relevant tests>
fvm flutter test --dart-define=FLUTTER_TEST=true
fvm flutter analyze
ruby tools/revenuecat/sync_revenuecat_catalog_test.rb
git diff --check
```

変更範囲に応じてIntegration Test、Android Emulator、iOS Simulator／TestFlight、Google Play Internal Testingを追加する。機密ファイルや`dart_define/*.json`は読み込まず、`git diff`と追跡ファイルに秘密値がないことを確認する。
