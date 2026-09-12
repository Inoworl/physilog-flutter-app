# 公開Webの運用

対象読者は、PhysiLogのLP・規約・サポートを更新する開発者とコンテンツ担当者です。

## 配置

LaKiiteと同様に、ユーザー向けの公開コンテンツはアプリリポジトリの `web/` に集約します。
`docs/` は開発者向け資料です。Firebase Hostingの `public` は `web` です。
静的HTML・CSS・画像を直接配信するため、Flutterビルドやnpmパッケージのインストールは不要です。
`flutter build web` や `flutter create --platforms web .` でこのディレクトリを上書きしないでください。

| 公開パス | ソース | 用途 |
| --- | --- | --- |
| `/` / `/index.html` | `web/index.html` | 公式LP |
| `/support.html` | `web/support.html` | サポートと規約の一覧（旧トップ） |
| `/privacy.html` | `web/privacy.html` | プライバシーポリシー |
| `/terms.html` | `web/terms.html` | 利用規約 |
| `/usage.html` | `web/usage.html` | アプリの使い方 |
| `/transfer.html` | `web/transfer.html` | 端末引き継ぎ |
| `/account-deletion.html` | `web/account-deletion.html` | アカウント削除 |
| `/measurement-tips.html` | `web/measurement-tips.html` | 計測のコツ |

既存6ページと `/styles.css` のURLは変更していません。各ページの戻り先は `support.html` です。
LPのCSSは `style.css`、規約・サポートのCSSは従来の `styles.css` を使用し、見た目を分離しています。
サイト内リンクは相対URLにし、本番LPから開発環境へ移動しないようにします。
README・テスト・認証ファイルなど公開不要なファイルは `web/` に置かないでください。

## 取り込み元と変更範囲

- リポジトリ: `Inoworl/physilog-hp`
- コミット: `009d21462547ff97bc812a62fbbf4e83f26d7efc`
- 対象: `index.html`、`style.css`、`images/*.png`
- 元デザイン・画像を維持し、サイト内リンク、サポート導線、基本的なキーボード操作を調整しています。
- 登録フォームがないため、「事前登録」は「公開予定」の確認に変更しています。
- 既存のLPリポジトリやGitHub Pagesの設定は変更していません。正式な更新元の切り替えは公開時に担当者と合意してください。

## ローカル検証

Node.js 22以降を使用します。テストは外部依存・Firebase認証情報なしで実行できます。

```bash
node --test scripts/test_web_hosting.mjs
firebase emulators:start --only hosting --project demo-physilog-hosting
```

Emulatorはローカル確認専用です。実環境への公開ではありません。
既定の `http://127.0.0.1:5000/` でLP、サポート、各規約ページを確認してください。
ポートが使用中の場合は、ローカル用の一時configに空きポートを指定し `--config` で渡します。

確認項目:

- トップ・既存6ページ・サポートの200、CSS・画像の読み込み。
- フッター → サポート → 各ページ → サポートへ戻る、という導線。
- FAQの開閉、キーボード操作、狭い画面での表示。
- 存在しないパスがLPに置き換わらず404になること。
- `/README.md` や `/docs/web-hosting.md` など、開発資料が配信されないこと。

## CIと公開

- PR: `.github/workflows/ci.yml` の `Public Web` ジョブを必須チェックに含めます。
- dev: `dev` ブランチの `web/**`、テスト、Hosting設定、devワークフローの変更で既存のdev公開を実行します。
- prod: `.github/workflows/deploy_prod_hosting.yml` の手動実行のみです。自動公開は追加していません。
- どちらの公開も、静的テスト成功後に既存のGitHub環境・認証設定で `firebase deploy --only hosting` を実行します。
- `dev` へのマージはdev公開を伴います。本番公開は、対象コミット・環境・正式URLの確認と明示承認後に行ってください。

正式公開前には、プラン・機能説明、仮のアプリ画像、公開予定の文言を実際の提供状況と照合してください。
canonical・sitemap、devの検索除外、ストア側URL、旧GitHub Pagesの移行案内は別途確認・実施が必要です。
今回の移設だけでは、SEO環境分離や他サイト・ストアの設定は変更されません。

新しいFAQやサポートページも `web/` に追加し、導線と静的テストを合わせて更新してください。

## 独自ドメインとDNS

2026-09-09に、ユーザー承認のもとでFirebaseのカスタムドメインを登録し、ConoHaの既存 `inoworl.com` ゾーンへ次のCNAMEを追加しました。

| 環境 | 独自ドメイン | Firebase project / Hosting site | ConoHaの名称 | CNAMEの値 | TTL |
| --- | --- | --- | --- | --- | --- |
| dev | `physilog-dev.inoworl.com` | `physilog-dev` | `physilog-dev` | `physilog-dev.web.app` | 3600 |
| prod | `physilog.inoworl.com` | `physilog-cb6cd` | `physilog` | `physilog-cb6cd.web.app` | 3600 |

接続先はFirebaseコンソールの指示値です。LaKiite、メール、ルートドメイン、ネームサーバーを含む既存レコードは変更しません。
DNS保存、Firebaseのドメイン接続・証明書発行、Hostingへのコンテンツ公開は別の状態です。
本番Hostingの初期設定や独自ドメイン登録だけではLPは公開されません。初回公開も承認済みのコミットを対象に本番の手動ワークフローで行います。

変更後は権威DNSのCNAME、Firebaseコンソールの接続状態、HTTPS証明書、公開ページのHTTPステータスを確認してください。
Firebaseが追加レコードを要求した場合は、その時点のコンソールの値を使用します。接続先を変更した場合はこの表も更新してください。

## 移設時の確認結果と既知の課題

- 静的テスト15件と、既存のリリースワークフローテスト12件を検証しています。
- ローカルHosting Emulatorで公開ページ・CSS・画像20パスの200と配信内容の一致、非公開・不存在7パスの404を確認しています。
- Chromiumの1440px / 390px幅で表示・画像・FAQ・公開予定CTA・サポート往復を確認しています。
- 320px幅では横方向のはみ出しがあります。取り込み元の同一コミットにも同じ状態（document幅322px、ヒーロー内部幅400px）があることを比較確認しました。移設による回帰ではないため、今回は元デザインを維持し、別のレスポンシブ改善課題として残しています。
- スクリーンショットの仮表示とプラン・機能説明は元LPの内容です。本番公開前の照合が必要です。
