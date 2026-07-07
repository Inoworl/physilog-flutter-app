# RevenueCat catalog sync

`revenuecat_catalog.yaml` をRevenueCat API v2へ反映するための運用ツールです。

## Projects

| Environment | RevenueCat project | Project ID | App ID |
| --- | --- | --- | --- |
| dev | Physilog Dev | `b9208054` | `app4d5c71b3b2` |
| prod | Physilog | `ec10fe6b` | 未設定 |

prodのProjectは既存の `Physilog` を使います。名前は変更しません。
prodへProductを同期するには、App StoreまたはGoogle Play用のRevenueCat App IDを
`revenuecat_catalog.yaml` の `environments.prod.app_id` に設定してください。

## API key

RevenueCat DashboardのProject Settings > API keysで、API v2 secret keyを作成します。
Flutter SDK用のpublic API keyではなく、Dashboard/API操作用のsecret API keyです。

必要権限:

- `project_configuration:entitlements:read_write`
- `project_configuration:products:read_write`
- `project_configuration:offerings:read_write`
- `project_configuration:packages:read_write`

`.env` で管理する場合の変数名:

```env
REVENUECAT_DEV_SECRET_API_KEY=sk_...
REVENUECAT_PROD_SECRET_API_KEY=sk_...
```

## Commands

APIキーなしの設定検証:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb --env dev --dry-run
```

RevenueCat上の現在値との差分確認:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env dev \
  --env-file '/Users/keisukeshimizu/Library/CloudStorage/GoogleDrive-keisukeshimizu.inoworl@gmail.com/マイドライブ/Obsidian/my-work-vault/ci-cd/secrets/.env' \
  --dry-run
```

devへ反映:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env dev \
  --env-file '/Users/keisukeshimizu/Library/CloudStorage/GoogleDrive-keisukeshimizu.inoworl@gmail.com/マイドライブ/Obsidian/my-work-vault/ci-cd/secrets/.env' \
  --apply
```

prodの差分確認:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env prod \
  --env-file '/Users/keisukeshimizu/Library/CloudStorage/GoogleDrive-keisukeshimizu.inoworl@gmail.com/マイドライブ/Obsidian/my-work-vault/ci-cd/secrets/.env' \
  --dry-run
```

テスト:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog_test.rb
```

## Known manual steps

RevenueCat Test StoreのProduct作成APIには、現時点で価格通貨を指定するフィールドがありません。
このため、YAMLの `intended_price` はストア価格の正本メモとして扱います。

Teamプランの2週間無料トライアルも、本番ではApp Store Connect / Google Play Console側の
introductory offerとして設定してください。
