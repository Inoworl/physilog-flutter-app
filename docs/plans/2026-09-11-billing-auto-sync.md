# 購入情報の自動同期

## 目的

通常利用で「購入を復元」を押さずに契約状態を反映する。復元機能は復旧用として維持する。

## 方針

- ストア購入の取得元はRevenueCatのままとし、Firestoreへ二重保存しない。
- Firestoreの特別利用権は既存の `users/{userId}/entitlements/current` を監視する。
- RevenueCatの通知に加え、起動・フォアグラウンド復帰・契約管理からの帰還・有効期限到達時にキャッシュを無効化して再取得する。
- 外部変更や通信失敗を回復するため、フォアグラウンド時のみ最大1分間隔で再確認する。バックグラウンドではタイマーを止める。
- 期限到達だけで有料権利を剥奪せず、RevenueCatの再確認結果を使う。取得失敗時は最後に確認できた状態を維持する。
- 同時リクエストをまとめ、古い取得結果が購入成功・通知による新しい状態を上書きしないようにする。
- 未認証・ローカルモードでは同期せず、アカウント変更・破棄時に監視を解除する。

## 実装と検証

1. `test/features/billing/application/billing_auto_sync_test.dart` と `test/providers/entitlement_stream_test.dart` に失敗する回帰テストを追加する。
2. `lib/features/entitlements/` と `lib/providers/app_providers.dart` をStream対応する。付与・変更・削除・期限切れ・UID変更を検証する。
3. `lib/features/billing/data/revenuecat_billing_repository.dart` と契約インターフェイスに強制再取得を追加する。SDKキャッシュ無効化と取得の順序を検証する。
4. `lib/features/billing/application/billing_controller.dart` に自動再確認・排他・期限タイマーを追加し、復帰・失効・更新・通信失敗・競合・破棄を検証する。
5. アプリ全体のライフサイクル監視を追加し、`plan_screen.dart` の契約管理終了時にも同期する。購入復元ボタンを維持する。
6. FVMで関連テスト、全体テスト、静的解析、フォーマット、差分チェックを行う。実機・ストアの検証は自動テストと区別する。

## 範囲外

本番デプロイ、ストア設定変更、価格変更、秘密値の読み取り、Firebase Commonsの未コミット変更、PRマージは行わない。

## 実装結果（2026-09-11）

- Firestore利用権のStream化、期限時の再評価、RevenueCat強制再取得、アプリ全体のライフサイクル同期を実装した。
- FirestoreのAsyncValueとfutureを二重に監視すると初回ロード中に購読が破棄される問題を回帰テストで確認し、future依存へ統一した。
- 起動時にSDK通知と初回取得が競合しても商品取得を失敗扱いにしない。連続するSDK通知の非同期処理と購入・復元の完了が競合しても、古い処理結果を適用しない。
- 自動再取得、期限切れ・更新、通信失敗、フォアグラウンド復帰、アカウント切替、Firestore付与・取消・削除、SDKキャッシュ無効化の順序を回帰テストで確認した。
- `firebase_options_test.dart` を除いた全テストは343件成功。除外理由は、このworktreeに機密設定をコピーしておらず `lib/firebase_options.dart` が存在しないため。
- `fvm flutter analyze --no-pub lib/app lib/features/billing lib/features/entitlements lib/providers test/app test/features/billing test/features/entitlements test/providers` は問題なし。
- 全体の `fvm flutter analyze --no-pub` は、上記設定ファイル不在に関連する8エラーで未完了。設定依存テスト・実機ビルド・実機での自動同期は未検証であり、成功扱いにしない。
- 実機の確認手順を `docs/revenuecat_test_store_runbook.md` に追加した。ストア設定、本番環境、Firestore Rulesは変更していない。
