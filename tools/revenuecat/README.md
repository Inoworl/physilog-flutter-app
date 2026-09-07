# RevenueCat catalog sync

`revenuecat_catalog.yaml` をRevenueCat API v2へ反映するための運用ツールです。

## Projects / Apps

| Environment | RevenueCat project | Project ID | Store | App ID |
| --- | --- | --- | --- | --- |
| dev | Physilog Dev | `b9208054` | Test Store | `app4d5c71b3b2` |
| dev | Physilog Dev | `b9208054` | App Store | `appf453300e51` |
| dev | Physilog Dev | `b9208054` | Google Play | `appbbd1f7da16` |
| prod | Physilog | `ec10fe6b` | App Store | `appcf636b29a7` |
| prod | Physilog | `ec10fe6b` | Google Play | `app07c4ac722f` |

prodのProjectは既存の `Physilog` を使います。名前は変更しません。
dev／prodのApp StoreとGoogle PlayのApp IDは
`revenuecat_catalog.yaml` の `environments.<env>.apps` で個別に管理します。
App IDが空の場合、dry-run／applyのどちらも外部APIを呼ぶ前に失敗します。

## Product identifiers

アプリはRevenueCat Package IDを安定キーとして扱い、ストア固有Product IDを直接判定しません。
各PackageにはiOSとAndroidの同等商品を関連付けます。

| Environment | Package ID | App Store Product ID | Google Play Subscription / Base Plan |
| --- | --- | --- | --- |
| dev | `personal_family_monthly` | `com.inoworl.physilog.dev.personal_family.monthly` | `personal_family:monthly` |
| dev | `personal_family_yearly` | `com.inoworl.physilog.dev.personal_family.yearly` | `personal_family:yearly` |
| dev | `team_monthly` | `com.inoworl.physilog.dev.team.monthly` | `team:monthly` |
| dev | `team_yearly` | `com.inoworl.physilog.dev.team.yearly` | `team:yearly` |
| prod | `personal_family_monthly` | `com.inoworl.physilog.personal_family.monthly` | `personal_family:monthly` |
| prod | `personal_family_yearly` | `com.inoworl.physilog.personal_family.yearly` | `personal_family:yearly` |
| prod | `team_monthly` | `com.inoworl.physilog.team.monthly` | `team:monthly` |
| prod | `team_yearly` | `com.inoworl.physilog.team.yearly` | `team:yearly` |

Google Play側のコロンより前はSubscription ID、後ろはBase Plan IDです。

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
  --env-file "$REVENUECAT_ENV_FILE" \
  --dry-run
```

devへ反映:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env dev \
  --env-file "$REVENUECAT_ENV_FILE" \
  --apply
```

prodの差分確認:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog.rb \
  --env prod \
  --env-file "$REVENUECAT_ENV_FILE" \
  --dry-run
```

テスト:

```bash
ruby tools/revenuecat/sync_revenuecat_catalog_test.rb
ruby tools/revenuecat/configure_public_sdk_key_test.rb
```

## Known manual steps

RevenueCat Test StoreのProduct作成APIには、価格通貨を指定するフィールドがありません。
このため、YAMLの `intended_price` はストア価格の正本メモとして扱います。
App Store／Google Play商品の価格とトライアルは各ストアコンソールで設定します。
Google Playで定期購入を作成する前に、デベロッパーアカウントのGoogle Payments
販売アカウントを設定する必要があります。

Teamプランの1ヶ月無料トライアルも、本番ではApp Store Connect / Google Play Console側の
introductory offerとして設定してください。設定・検証手順は
`docs/revenuecat_production_store_runbook.md`を参照してください。
