# 公開Webの統合計画

## 目的と合意事項

LaKiiteと同様に、PhysiLogのLP・利用規約・サポートをアプリリポジトリの `web/` に集約する。`docs/` は開発者向けドキュメントに限定する。既存の公開URLを維持し、Flutter Webには変換しない。

作業起点は `origin/dev` の `43caac8a9dcd4962813df8437d3dbe0abfabf3ff`。LPの取り込み元は `Inoworl/physilog-hp` の `009d21462547ff97bc812a62fbbf4e83f26d7efc`。元のデザインと画像を維持する。

## Task 1: 移行契約のテスト

- ファイル: `scripts/test_web_hosting.mjs`
- `web/` 配信、既存6ページのURL、サポートへの戻り先、LPからの導線、内部リンク・画像、公開ワークフローの検証を追加する。
- 検証: `node --test scripts/test_web_hosting.mjs` が移行前に失敗すること。

## Task 2: 公開ページの統合

- ファイル: `docs/pages/*` → `web/*`、LP → `web/index.html`、`web/style.css`、`web/images/*`
- 旧トップは `web/support.html` に移す。規約などのファイル名と `styles.css` は維持する。
- 既存ページの「サポートトップへ戻る」を `support.html` に変更する。
- LPの開発環境への固定リンクを同一サイトの相対リンクにし、サポート・アカウント削除への導線を追加する。
- 登録フォームがないため、事前登録CTAは公開予定の確認として表現する。主コンテンツのランドマーク、キーボードフォーカス、動きを抑える設定を補う。
- 検証: 静的テストでリンク・画像・既存URLを確認する。

## Task 3: Hosting・CI・ドキュメント

- ファイル: `firebase.json`、`.github/workflows/deploy_*_hosting.yml`、`.github/workflows/ci.yml`、`README.md`、`docs/web-hosting.md`
- Hostingの `public` と開発環境の監視パスを `web/` に変更する。
- PRとdev/prodデプロイ前に依存パッケージ不要の静的テストを実行する。
- devの自動公開、本番の手動公開という既存の公開条件・認証方式は変更しない。
- 検証: 静的テストと差分確認。
- 既存の `test/release/release_workflows_test.dart` の監視パス契約も `web/**` に更新し、FVMで検証する。

## Task 4: ローカル配信の検証

- Firebase Hosting Emulatorを `demo-physilog-hosting` で起動する。実Firebaseへの書き込み・デプロイはしない。
- トップ、サポート、既存6ページ、CSS・画像の200と、架空URL・開発資料の404を確認する。
- ブラウザでLPの表示、サポートへの移動、FAQを確認する。

## 初期計画での対象外

- コミット、push、PR作成、実環境へのデプロイ。
- GitHub Pagesの変更・停止、旧LPリポジトリのアーカイブ。
- 独自ドメイン接続、ストアURLの変更、登録フォーム・課金仕様の実装。
- 正式ドメイン未確定のcanonical/sitemap追加や、別作業であるSEO環境分離。

本番公開前に正式URL、LPの機能・プラン表現、スクリーンショット、旧Pagesの移行案内を確認する。

## 2026-09-09の追加承認

- dev / prodのFirebaseカスタムドメイン登録、本番Hosting初期設定、ConoHaへの指定DNSレコード追加を実施する。
- 検証に問題がなければコミット、push、PR作成と `dev` へのマージまで進める。マージ後のdev自動公開も確認する。
- 本番コンテンツ公開は引き続き手動運用とし、ドメイン設定と分けて扱う。
- 接続先と運用上の確認項目は `docs/web-hosting.md` に記録する。
