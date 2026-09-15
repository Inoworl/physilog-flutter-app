# 3プランMVPの仕様と検証

対象読者: 実装・レビュー・受け入れテストを行う開発者。

## 今回の範囲

| 項目 | Free | 個人・家族 | Team |
| --- | --- | --- | --- |
| 選手 | 1人 | 5人 | 無制限 |
| 種目 | 3つ | 無制限 | 無制限 |
| 計測会 | 利用不可 | 利用不可 | 利用可 |
| CSV出力 | Upgrade案内 | Upgrade案内 | 利用可 |
| 過去の記録の閲覧・削除 | 継続可 | 継続可 | 継続可 |

月額・年額でクライアント機能の差はない。価格要件は個人・家族が月100円／年1,000円、Teamが月980円／年8,980円。購入画面の価格はストアの商品情報を表示する。Teamの1か月無料トライアルはストア側で適用される対象者のみで、固定プレビューでは購入・適格性・トライアルを再現しない。

保護者・選手へのクラウド共有は #99 の別フェーズ。CSVの保存・共有はこの機能とは異なり、アプリ外にファイルを渡す操作である。

## ダウングレード時

- RevenueCatと既存の特別付与を合成した現在のプランで制御する。Teamの購入が失効しても、他の有効な利用権が残れば必ずFreeになるわけではない。
- 上限超過でも選手・種目・過去の記録を自動削除しない。履歴一覧もプラン上限で隠さない。
- 上限を超えている場合は「管理」または記録画面の「計測対象を選ぶ」から、上限内の選手・種目を選ぶ。先頭の選手を勝手に選ばない。
- 選択外への新規記録・記録更新は拒否する。開いたままのフォームでも、保存時にアカウント・現在プラン・計測対象を再確認する。
- 新規選手・種目の登録時も現在の登録数を再確認する。計測会の試技追加・更新ではTeam権限を再確認する。
- プランの取得中・取得失敗中は新規書き込みを許可しない。取得失敗をFreeと断定しない。
- 選択はデータ保存方式とアカウントごとに端末内へ保存する。再起動では保持されるが、別端末へは同期されない。上限超過した新しい端末では再選択が必要。
- クライアント制限であり、改造クライアントや複数端末の同時登録に対するサーバー側の原子的な上限制御ではない。Firestoreの既存の所有者Rulesは引き続き必要。

## CSVの操作と形式

1. Teamで「記録」タブのCSV出力ボタンを押す。
2. 選手・種目・測定期間を必要に応じて指定する。同名の選手・種目は内部IDで区別する。
3. 「対象を確認」で件数と含まれる情報を確認する。
4. 「CSVを保存・共有」でOSの共有画面を開き、保存先や送信先を本人が選ぶ。確認前の自動送信はしない。

- UTF-8 BOM、CRLF、列は `測定日時,選手,種目,記録値,単位,セット`。
- 日時はUTCのISO形式（末尾 `Z`）。期間の選択は端末のローカル暦日で、終了日全体を含む。
- Repositoryの既存の`dateTo + 1日`という契約に合わせ、CSVサービスは「終了日の翌日0時」をUTCへ変換して24時間引いた値を渡す。時刻つきの入力や夏時間の切り替えでも取得範囲を欠落させない。
- 小数を表示用に丸めず、重量・回数のセット情報も独立列へ残す。カンマ・改行・引用符をエスケープし、数式として解釈され得る文字列には先頭にアポストロフィを付ける。
- メール、UID、取引ID、メモ、動画パスは列に含めない。ただし選手名は含まれるため、共有前に確認する。アプリ外へ保存されたファイルは後から回収できない。
- 読み込みは250件単位。取得したレコードが10,000件を超えたら明示的に失敗し、黙って一部だけ出力しない。種目の絞り込みは取得後に行うため、出力件数が少なくても取得件数の上限に達することがある。期間や選手で絞り込む。
- 空の結果では共有不可。アカウント変更、Team失効、選択対象の削除時も古いプレビューを共有しない。OSへ渡す直前にも利用権を確認する。
- 一時ファイルは専用ディレクトリに保存する。次回出力時に24時間より古い専用ディレクトリを削除する。常駐タイマーによる24時間ちょうどの消去ではない。OSへの引き渡しに失敗したファイルはその場で削除する。

## 固定プランの動作確認（ログイン・課金不要）

`lib/main_mock.dart`に`PREVIEW_PLAN`を渡すと、6選手・4種目・6記録のダミーデータで起動する。上限超過・履歴維持・計測対象選択・CSVを確認するための構成で、ストア購入やFirebaseの実ユーザーではない。起動し直すとダミーデータと選択は初期化される。

Android:

```bash
fvm flutter run --debug --flavor mock -t lib/main_mock.dart --dart-define=PREVIEW_PLAN=free
fvm flutter run --debug --flavor mock -t lib/main_mock.dart --dart-define=PREVIEW_PLAN=personalFamily
fvm flutter run --debug --flavor mock -t lib/main_mock.dart --dart-define=PREVIEW_PLAN=team
```

iOS Simulatorでは既存の`dev` schemeとmockエントリーポイントを使う（`mock` schemeはない）。接続先が複数ある場合は`-d <simulator-id>`でSimulatorを明示する。

```bash
fvm flutter run --debug --flavor dev -t lib/main_mock.dart --dart-define=PREVIEW_PLAN=team -d <simulator-id>
```

この固定プラン構成はreleaseで拒否する。本番の利用権を上書きする設定ではない。月額・年額は同じ機能権限なので、プレビューも3種類。購入周期・無料期間・解約・復元の検証には別途ストア用ビルドが必要。

## 自動検証

```bash
fvm flutter test --no-pub
TZ=America/New_York fvm flutter test --no-pub test/features/records/application/record_csv_export_service_test.dart
fvm flutter analyze --no-pub
git diff --check
```

主な回帰テスト:

- `test/features/billing/domain/recording_scope_test.dart`: Free・個人・家族・Teamの境界、期限切れ後の明示選択。
- `test/features/billing/application/recording_access_service_test.dart`: 保存・編集・登録、取得中／エラー、途中のプラン変更・アカウント変更。
- `test/features/billing/application/recording_access_providers_test.dart`: 実際のprovider接続と計測会の更新時チェック。
- `test/features/billing/data/hive_recording_selection_repository_test.dart`: 再オープン、アカウント・保存方式の分離。
- `test/features/records/domain/record_csv_test.dart`: 文字コード・引用符・改行・数式・精度・除外情報。
- `test/features/records/application/record_csv_export_service_test.dart`: 絞り込み・期間境界・他ユーザー除外・ページング・上限・途中失効。
- `test/features/records/data/record_csv_sharer_test.dart`: 一時ファイル・OS連携の引数・最終認可。
- `test/features/records/presentation/record_csv_export_button_test.dart`: 件数確認、Upgrade、アカウント切替、選択した選手の削除。
- `test/providers/mock_app_overrides_test.dart`: 3プランの固定構成でも本物の書き込みガードを通ること。

## まだ完了扱いにしない項目

- #108: 通信断が長期継続した場合の購入情報の鮮度・有料権限保持期限。新しい猶予日数をこの変更で勝手に決めない。最後に取得した購入情報を維持する既存処理を置き換えていない。
- #110: 実在するテストアカウントの確認・準備。認証情報を読まずに使える固定プレビューは実アカウントの代替証跡にはならない。
- iOS／Android実機でのCSV保存先選択、受信ファイルの日本語・日時・改行の確認、キャンセル、失効後の再試行。
- 最新ビルドでのSandbox／Internal Testingによる購入・解約・復元・Team無料期間の回帰確認。
- 本番ストアの提出・販売可否、Rulesの配備状況、価格改定時のストアでの既存価格維持運用。

構成コード、自動テスト、実機確認、ストア公開の完了状態を混同しない。実測結果を更新するときは、環境・確認内容・合否だけを記載し、メール・UID・取引ID・認証情報を残さない。
