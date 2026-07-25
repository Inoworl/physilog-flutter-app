# RevenueCat購入テストマトリクス

最終更新: 2026-07-24

## 対象環境

- Firebase: `physilog-dev`
- RevenueCat: Physilog Dev / Test Store
- Android: API 34 Emulator、dev debug
- iOS: Simulator、dev debug
- アカウントの実メール、パスワード、UID、API keyは記録しない。

## 実測結果

| # | シナリオ | 期待結果 | 実測 | 結果 |
| --- | --- | --- | --- | --- |
| 1 | 新規匿名起動 | UIDが存在し、メール未登録・Free | Androidでメール未登録・Freeを確認 | PASS |
| 2 | 商品取得（月額） | 個人・家族とTeamの月額商品を表示 | USD 5.00 / USD 9.80をAndroid・iOSで確認 | PASS |
| 3 | 商品取得（年額） | 個人・家族とTeamの年額商品を表示 | USD 50.00 / USD 98.00をAndroid・iOSで確認 | PASS |
| 4 | 購入キャンセル | Freeのまま、キャンセル表示 | iOS Test StoreでFree維持とキャンセル表示を確認 | PASS |
| 5 | 購入失敗 | Freeのまま、失敗表示 | iOS Test StoreでFree維持と失敗表示を確認 | PASS |
| 6 | 個人・家族（月額）購入 | `personal_family`がactive、UI更新 | Androidで`personal_family_monthly`、Personal Family、Activeを確認 | PASS |
| 7 | 個人・家族（年額）購入 | `personal_family`がactive、UI更新 | Androidで`personal_family_yearly`、Personal Family、Activeを確認 | PASS |
| 8 | Team（月額）購入 | `team`がactive、UI更新 | Androidで`team_monthly`、Team、Activeを確認 | PASS |
| 9 | Team（年額）購入 | `team`がactive、UI更新 | Androidで`team_yearly`、Team、Activeを確認 | PASS |
| 10 | UID同期 | Firebase UIDとRevenueCat App User IDが一致 | 4購入アカウントすべてで同一顧客を確認 | PASS |
| 11 | 購入復元 | CustomerInfo再取得後も購入プランを表示 | iOSの個人・家族、AndroidのTeam年額で確認 | PASS |
| 12 | 月額更新 | Renewal後も権限を維持 | 個人・家族（月額）で複数RenewalとUI維持を確認 | PASS |
| 13 | 月額期限切れ | 下位EntitlementなしならFreeへ戻る | Expired後、フォアグラウンド復帰でFree降格を確認 | PASS |
| 14 | ログアウト | 新しい匿名UIDでFree、権限漏れなし | 各有料アカウント切替時にメール未登録・Freeを確認 | PASS |
| 15 | Sandbox access | 検証用UIDだけがtest entitlementを取得 | `Allowed App User IDs only (4)`を確認 | PASS |
| 16 | release keyガード | releaseでTest Store keyを拒否 | ガードを含む全自動テストが成功 | PASS |
| 17 | 全自動テスト・解析 | format/test/analyzeが成功 | format差分なし、全テスト成功、analyze指摘なし、秘密情報混入検査成功 | PASS |

## Issue #96 自動検証結果

実Storeでしか確認できない請求結果と、自動テストで確認したアプリ境界を分けて記録する。

| # | シナリオ | 自動検証範囲 | 結果 |
| --- | --- | --- | --- |
| 18 | CustomerInfo契約詳細 | 商品ID、Tier、周期、Store、期限、更新、解約、請求問題、管理URLの変換 | PASS |
| 19 | 現在商品の再購入防止 | 現在商品を「利用中」にして購入ボタンを無効化 | PASS |
| 20 | 個人・家族 → Team | 即時変更、旧商品ID、`withTimeProration`、確認ダイアログ | PASS |
| 21 | Team → 個人・家族 | 次回更新時変更、旧商品ID、`deferred`、確認ダイアログ | PASS |
| 22 | 同一Tierの周期変更 | 次回更新時変更、旧商品ID、`deferred`、確認ダイアログ | PASS |
| 23 | iOS変更購入 | Android固有の商品変更情報を渡さずStoreKitへ委譲 | PASS |
| 24 | キャンセル／失敗 | 現在契約、権限、変更予約を維持 | PASS |
| 25 | 変更予約 | UID別保存、再起動復元、CustomerInfo更新時の消し込み | PASS |
| 26 | 契約管理 | 管理URL起動、URLなし、外部起動失敗の案内 | PASS |
| 27 | Android端末統合 | スクロール、変更確認、購入要求生成をAPI 34 Emulatorで実行 | PASS |

## Issue #96 実Store検証状況

| 環境 | 確認対象 | 状況 |
| --- | --- | --- |
| RevenueCat Test Store | 変更成功、キャンセル、失敗、再起動後の予約表示 | 未実施 |
| Apple Sandbox／TestFlight | upgrade、downgrade、周期変更、解約、復元、期限切れ | Issue #97で実施 |
| Google Play Internal Testing | Replacement Mode、解約、復元、請求状態、期限切れ | Issue #97で実施 |

未実施項目をPASSとして扱わない。実行後は本表の状況と下記の再実行記録を更新する。

## 手動実行手順

### 共通前提

1. `default` Offeringに4商品がある。
2. dev dart-defineにTest Store SDK keyが設定されている。
3. Firebase UIDがSandbox Testing Accessで許可されている。
4. RevenueCat Customer profileではSandbox dataを表示する。

### 成功・失敗・キャンセル

1. 新しい匿名ユーザーでFreeを確認する。
2. 対象周期とプランを選択する。
3. 購入ボタンを押す。
4. CancelまたはTest failed purchaseを選び、Free維持を確認する。
5. Test valid purchaseを選び、再起動なしで対象プランへ変わることを確認する。
6. Customer profileで商品ID、Entitlement、Active状態を確認する。

### 復元

1. 有効な購入があるアカウントで「購入を復元」を押す。
2. 復元完了メッセージを確認する。
3. 現在プランとRevenueCat Customer profileが変わらないことを確認する。

### 更新・期限切れ

1. 月額商品を有効購入する。
2. Customer profileのRenewalイベントを監視する。
3. 更新後もアプリの有料プランが維持されることを確認する。
4. Expiredになるまで待つ。
5. アプリをバックグラウンドから復帰させる。
6. 下位EntitlementがなければFreeへ戻ることを確認する。

### ログアウト

1. 有料アカウントからログアウトする。
2. メール未登録を確認する。
3. 現在プランがFreeであることを確認する。
4. RevenueCat顧客が新しい匿名UIDへ切り替わることを確認する。

## 既知の差分

- Test StoreはApple / Google固有のBilling Retry、Grace Period、Account Hold、pending購入を完全には再現しない。
- 月額期限切れはバックエンド時刻到達だけでは画面が即時更新されず、アプリのフォアグラウンド復帰によるCustomerInfo再同期でFreeへ更新された。
- 年額の自動期限切れは約5時間かかるため、今回の実測は月額で代表した。Entitlement解決ロジックは周期に依存しない。

## 再実行時の記録

再実行時は日付、端末、商品ID、期待プラン、実測プラン、PASS/FAILだけを追記する。メール、パスワード、UID、API key、設定ファイル本文は記録しない。
