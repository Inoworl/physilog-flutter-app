# Final Release Gate

## Scope

App Store Review 提出または Google Play production 公開の前に、dev/prod x iOS/Android の最終検証結果を記録するための Go/No-Go 台帳です。

この文書が完了し、人間の明示承認が出るまで、App Store Review 提出、Google Play production 公開、staged rollout 開始は行わないでください。

## Required Local Verification

| 項目 | コマンド | 結果 | 実行者 | 日時 |
| --- | --- | --- | --- | --- |
| 静的解析 | `fvm flutter analyze` | TBD | TBD | TBD |
| 全テスト | `fvm flutter test` | TBD | TBD | TBD |
| 生成差分 | `fvm flutter pub run build_runner build --delete-conflicting-outputs` 後に意図しない差分なし | TBD | TBD | TBD |
| Git 差分 | `git diff --check` | TBD | TBD | TBD |

## Environment Matrix

| 環境 | Bundle ID / Package ID | Firebase | 表示名 | アイコン | 配布経路 | 結果 |
| --- | --- | --- | --- | --- | --- | --- |
| iOS dev | `com.physilog.physiLog.dev` | dev | PhysiLog Dev | dev | TestFlight | TBD |
| iOS prod | `com.physilog.physiLog` | prod | PhysiLog | prod | TestFlight / App Store Review | TBD |
| Android dev | `com.physilog.physi_log.dev` | dev | PhysiLog Dev | dev | 内部テスト / closed testing | TBD |
| Android prod | `com.physilog.physi_log` | prod | PhysiLog | prod | 内部テスト / production | TBD |

## Device Smoke Tests

各環境で以下の主要導線を確認してください。

| 導線 | iOS dev | iOS prod | Android dev | Android prod |
| --- | --- | --- | --- | --- |
| 初回起動と匿名サインイン | TBD | TBD | TBD | TBD |
| ホーム表示 | TBD | TBD | TBD | TBD |
| 動画撮影 | TBD | TBD | TBD | TBD |
| 動画選択 | TBD | TBD | TBD | TBD |
| 動画圧縮と計測画面遷移 | TBD | TBD | TBD | TBD |
| 開始 / 終了位置指定 | TBD | TBD | TBD | TBD |
| 記録保存 | TBD | TBD | TBD | TBD |
| 記録一覧 / 詳細 / 編集 | TBD | TBD | TBD | TBD |
| CSV 出力または共有導線 | TBD | TBD | TBD | TBD |
| 権限拒否時の表示 | TBD | TBD | TBD | TBD |

## Build Artifacts

提出またはテスト配布に使う artifact path と SHA-256 を記録してください。

| 環境 | artifact path | SHA-256 | Git commit | CI run |
| --- | --- | --- | --- | --- |
| iOS dev IPA | TBD | TBD | TBD | TBD |
| iOS prod IPA | TBD | TBD | TBD | TBD |
| Android dev AAB | TBD | TBD | TBD | TBD |
| Android prod AAB | TBD | TBD | TBD | TBD |

SHA-256 の例:

```sh
shasum -a 256 path/to/artifact
```

## Store Consistency

| 項目 | 確認内容 | 結果 |
| --- | --- | --- |
| ストア文案 | 実装済み機能だけを説明している | TBD |
| スクリーンショット | 本番個人データ、未実装機能、権利未確認素材がない | TBD |
| 法務URL | プライバシーポリシーURL、利用規約URL、サポートURL が公開されている | TBD |
| ポリシー申告 | Google Play のデータセーフティ、対象年齢、コンテンツレーティング、健康アプリ該当性が実態と一致 | TBD |
| App Store Review 情報 | 連絡先、デモ情報、暗号化、サインイン要否が正しい | TBD |

## Blocking Dependencies

以下が完了していない場合、この Final Gate は No-Go です。

- iOS dev TestFlight 準備完了。
- Android dev Play Console / 内部テスト準備完了。
- iOS prod App Store Connect レコード、Bundle ID、証明書、Provisioning Profile 準備完了。
- Android prod Play Console アプリ、Package ID、署名鍵、Firebase prod 設定準備完了。
- Firebase dev/prod 設定、GitHub Environments、Secrets 登録完了。
- ストア文案、スクリーンショット、法務URL、Play ポリシー申告の人間承認完了。

## Human Approval

| 承認対象 | 承認者 | 日時 | 結果 |
| --- | --- | --- | --- |
| App Store Review 提出 | TBD | TBD | TBD |
| Google Play production 公開 | TBD | TBD | TBD |
| staged rollout 開始 | TBD | TBD | TBD |

承認コメントには、対象環境、artifact SHA-256、Git commit、CI run、公開範囲を明記してください。
