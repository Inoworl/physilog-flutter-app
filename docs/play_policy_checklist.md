# Google Play Policy Checklist

## Scope

PhysiLog の prod Android 公開前に、Google Play Console のポリシー申告、データセーフティ、対象年齢、コンテンツレーティング、クローズドテスト要件を確認するための台帳です。

この文書は申告準備用です。Play Console での最終送信、production 申請、公開操作は人間承認後に実施してください。

## References

- Google Play Console Help: Data safety form
  - https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play Console Help: Open, closed, and internal tests
  - https://support.google.com/googleplay/android-developer/answer/9845334
- Google Play Console Help: Target audience and app content
  - https://support.google.com/googleplay/android-developer/answer/9867159

## Implementation Signals

| 項目 | 根拠 |
| --- | --- |
| Firebase Auth | `lib/main.dart`, `lib/features/auth/application/auth_service.dart` で匿名サインインを使用 |
| Firestore | `lib/features/*/data/firestore_*_repository.dart` で選手、種目、計測記録を保存 |
| 動画 | `image_picker`, `video_player`, `video_compress` を使用 |
| カメラ | `Permission.camera.request()` と `ImageSource.camera` を使用 |
| 写真と動画 | `ImageSource.gallery` で端末内動画を選択 |
| 端末内保存 | 圧縮動画をアプリ領域の `videos` ディレクトリに保存 |
| CSV / 共有 | `share_plus` 依存あり。CSV 出力や共有が申告・説明と矛盾しないか要確認 |

## Data Safety Draft

Google の定義では、端末外へ送信されるユーザーデータと SDK による送信もデータセーフティ申告対象です。PhysiLog は Firebase Auth / Firestore を使うため、少なくとも以下を確認してください。

| データ区分 | 想定申告 | 確認事項 |
| --- | --- | --- |
| ユーザーID | 収集あり | Firebase Auth の匿名 UID が Firestore の `userId` として使われる |
| アプリ操作 / 記録データ | 収集あり | 選手名、種目名、計測結果、メモ等が Firestore に保存される |
| 写真と動画 | 原則、端末内処理 | 動画ファイル自体を Firebase Storage 等へアップロードしていないことを確認 |
| デバイスまたはその他の ID | 要確認 | Firebase SDK / Google Play services が送信する識別子を Firebase の最新ガイドで確認 |
| クラッシュログ / 診断 | 要確認 | Crashlytics 等を追加していないこと。追加する場合は申告更新 |

想定目的:

- アプリ機能: 計測記録の保存、表示、編集。
- アカウント管理: 匿名ユーザー単位のデータ分離。
- 分析 / 広告: 現時点では未使用想定。SDK 追加時は再確認。

## App Content Declarations

| Play Console 項目 | 推奨初期値 | 理由 / 確認 |
| --- | --- | --- |
| 広告ID | いいえ | 広告 SDK は導入されていない想定。依存関係更新時に再確認 |
| 広告の有無 | いいえ | 広告表示機能なし |
| 健康アプリ | 要人間判断 | スポーツ・トレーニング計測だが、医療・診断・治療を提供しない前提。Google Play の健康関連申告画面で最終確認 |
| 金融取引 | いいえ | 決済、金融商品、送金なし |
| 行政アプリ | いいえ | 政府機関または公的サービスではない |
| ニュース | いいえ | ニュース配信アプリではない |
| COVID-19 / 医療 | いいえ | 該当機能なし |
| 対象年齢 | 要人間判断 | 子ども向けではない想定。対象年齢に 13 歳未満を含める場合は Families Policy 対応が必要 |
| コンテンツレーティング | 要入力 | 暴力、性的表現、ギャンブル等はなしの想定。質問票で正確に回答 |
| アプリへのアクセス | 要入力 | 審査担当者が匿名サインイン後に主要機能を操作できることを確認 |

## Closed Testing Plan

Google Play のヘルプでは、2023-11-13 以降に作成された個人デベロッパーアカウントは、本番公開前に追加のテスト要件を満たす必要があるとされています。アカウント種別と作成日を Play Console で確認してください。

| 項目 | 方針 |
| --- | --- |
| トラック | Closed testing |
| テスター | Google アカウントのメールリストまたは Google Group |
| 配布 | Play Console の opt-in link を共有 |
| フィードバック | サポートURL、メール、フォーム等の窓口を準備 |
| テスト期間 | Play Console が要求する期間を満了する |
| 確認項目 | インストール、動画取り込み、計測、保存、編集、CSV 出力、権限拒否時の挙動 |

## Consistency Checks

- データセーフティ申告、プライバシーポリシー、ストア説明が同じデータ取扱いを説明している。
- カメラ、写真と動画の権限説明が、実装とストア説明に一致している。
- 動画をサーバーへ送信しない場合、その旨がプライバシーポリシーと矛盾しない。
- Firebase / Google SDK のデータ送信内容を最新の公式ドキュメントで確認した。
- クローズドテストのフィードバック窓口が公開またはテスターに共有されている。
- Play Console の申告を変更した場合、この文書も更新する。

## Human Approval Gate

以下は人間承認後にのみ実施してください。

- Play Console のデータセーフティ申告送信。
- 対象年齢、コンテンツレーティング、健康アプリ該当性の最終回答。
- クローズドテスト release のロールアウト。
- production 申請、段階的公開、公開停止や rollback。
