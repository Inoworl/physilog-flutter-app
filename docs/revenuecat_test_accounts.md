# RevenueCat devテストアカウント運用

最終更新: 2026-07-20

## 対象読者

- Firebase devとRevenueCat Test Storeでプラン表示・購入遷移を確認する開発者
- 検証アカウントを追加、更新、廃止する担当者

## 目的

Firebase UIDをRevenueCat App User IDとして使い、Free、個人・家族、Teamを再現する。メール、パスワード、UID、APIキーはGit管理ファイルへ記録しない。

## アカウントの役割

表示確認と購入遷移ではアカウントを分ける。

| 役割 | Firebase Auth | RevenueCat | 用途 |
| --- | --- | --- | --- |
| Free | 新規匿名ユーザー | active entitlementなし | 初回起動、Free上限、ログアウト後の権限分離 |
| 固定・個人／家族 | メールとパスワード | `personal_family`をDashboard Grant | 期限に左右されない表示・capability確認 |
| 固定・Team | メールとパスワード | `team`をDashboard Grant | 期限に左右されない表示・capability確認 |
| 購入・個人（月額） | メールとパスワード | `personal_family_monthly`をTest Store購入 | 月額購入、更新、期限切れ |
| 購入・個人（年額） | メールとパスワード | `personal_family_yearly`をTest Store購入 | 年額購入と復元 |
| 購入・Team（月額） | メールとパスワード | `team_monthly`をTest Store購入 | 月額購入、更新、期限切れ |
| 購入・Team（年額） | メールとパスワード | `team_yearly`をTest Store購入 | 年額購入と復元 |

実際のメールアドレスとパスワードは、チームのパスワード管理ツールに役割名で保存する。本文やIssue、PR、スクリーンショットには記載しない。

## 認証経路とUID

### 新しい匿名ユーザーをFreeとして使う

1. devアプリのアプリデータを消すか、登録済みアカウントからログアウトする。
2. アプリがFirebase匿名認証を完了するまで待つ。
3. 設定画面で「メールアドレス: 未登録」「現在のプラン: Free」を確認する。
4. debug overlayのUIDが空でないことだけ確認する。UID値を記録へ貼らない。

### 匿名ユーザーへメールとパスワードを設定する

設定画面の「メールとパスワードを設定」は、匿名ユーザーへEmail/Password credentialをリンクする。この場合、基本的にFirebase UIDは変わらず、匿名状態で作成したデータとRevenueCat顧客を継続する。

### 既存アカウントへ切り替える

設定画面の「別端末から引き継ぐ」は、既存Email/Passwordユーザーへサインインする。現在端末の匿名データは警告どおり削除され、Firebase UIDは既存アカウントのUIDへ変わる。アプリは変更後のUIDをRevenueCatへ`logIn`し、Firestore devの対象ユーザーデータを読み直す。

### Firebase Consoleで作ったユーザー

Firebase ConsoleでEmail/Passwordユーザーを作成しても問題ない。ただし、Console作成だけではRevenueCat顧客は作られない。対象アカウントで一度アプリへログインし、Firebase UIDをRevenueCatへ同期する必要がある。

## UID一致の確認

各アカウントで次を確認する。

1. アプリへログインする。
2. debug overlayでFirebase UIDが存在することを確認する。
3. RevenueCatのCustomersで同じUIDを検索する。
4. Customer profileのApp User IDが同じであることを確認する。
5. Sandbox dataを表示し、期待する商品とEntitlementを確認する。

確認結果には「一致／不一致」と役割名だけを記録し、UIDそのものは残さない。

## Granted Entitlementの使い分け

DashboardのGranted Entitlementはストア購入を発生させず、指定顧客へEntitlementを手動付与する機能である。固定表示アカウントだけに使う。

- 個人・家族の固定表示: `personal_family`
- Teamの固定表示: `team`
- 付与期限は検証期間より十分長くする。
- 検証終了時は不要なGrantを削除する。
- 購入成功・失敗・キャンセル・更新・期限切れの確認には使わない。

月額と年額は同じEntitlementへ集約されるため、Granted Entitlementだけでは購入周期を区別できない。周期確認はCustomer profileの商品IDで行う。

## Firestore devデータ

- 選手、種目、記録などの画面確認データはFirebase devへ用意する。
- 通常のストア購入プラン判定はRevenueCatを正本とする。
- Firestore entitlementはlegacyまたは管理者による特別付与だけに使う。
- アカウント切替時に匿名データが削除されるため、購入遷移用アカウントへ重要な検証データを置かない。

## ログアウト確認

1. 有料アカウントの設定画面でログアウトする。
2. 新しい匿名UIDが作られるまで待つ。
3. メールアドレスが未登録になることを確認する。
4. 現在プランがFreeになることを確認する。
5. 以前の有料Entitlementが匿名UIDへ漏れていないことを確認する。

## 保守メモ

認証リンク、アカウント引き継ぎ、RevenueCat identity同期の実装を変更した場合は、UID一致とログアウト後の権限分離を全アカウントで再確認する。
