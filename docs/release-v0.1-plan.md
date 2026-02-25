# PhysiLog v0.1 リリース計画（MVP固定）

## リリース方針
- 配布: iOS TestFlight
- スコープ: ローカル完結（クラウド同期なし）

## MVPスコープ（IN）
- 動画取り込み（カメラ撮影 / アルバム選択）
- 手動計測（開始/終了確定、タイム算出）
- 記録保存（ローカル）
- 記録一覧 / 詳細 / 編集 / 削除

## MVPスコープ（OUT）
- Firebase同期
- 匿名認証の厳密運用（UIDベースのクラウド識別）
- アカウント昇格（Google / Apple / Email）
- 選手/種目マスタ管理
- 記録シート（表形式）
- CSVエクスポート

## 実装タスク
1. MVP外導線の凍結（RecordListScreenのショートカット整理）
2. 表示文言の調整（未実装機能を期待させない）
3. iOS権限文言の整備（Info.plist）
4. 品質ゲート実施（analyze / test）

## TestFlight前チェックリスト
- [ ] `fvm flutter analyze` が成功
- [ ] `fvm flutter test` が成功
- [ ] 実機で記録作成→一覧反映→編集→削除を確認
- [ ] 実機で再起動後のローカルデータ残存を確認
- [ ] 権限ダイアログ文言が適切（カメラ・写真）
- [ ] `version` / `build number` をリリース値に更新

## 受け入れ条件（Go/No-Go）
- 主要機能の手動確認でブロッカー不具合が0件
- クラッシュ再現がない
- Internal TestFlightでインストール・起動が可能
