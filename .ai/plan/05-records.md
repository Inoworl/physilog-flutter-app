# 05: 記録管理機能 実装計画

## 概要

計測結果を保存・閲覧・編集・削除・エクスポートする機能。Firestoreをメインストレージとし、オフライン対応のためローカルDBも併用する。

---

## 対応する機能要件

| 要件ID | 内容 | 優先度 |
|--------|------|--------|
| F-20 | 記録の保存（選手名、種目、タイム、日付、メモ、動画参照） | 必須 |
| F-21 | 記録一覧（新しい順） | 必須 |
| F-22 | 記録の編集 | 必須 |
| F-23 | 記録の削除 | 必須 |
| F-24 | CSVエクスポート | MVP+ |

### 関連する非機能要件

| 要件ID | 内容 |
|--------|------|
| N-20 | オフライン時もローカルに記録保存可能 |
| N-21 | オンライン復帰時にFirestoreと自動同期 |

---

## データモデル

### Record エンティティ

```dart
@freezed
class Record with _$Record {
  const factory Record({
    required String id,              // ドキュメントID
    required String athleteName,     // 選手名
    required String event,           // 種目（50m走、シャトルラン等）
    required double timeMs,          // 計測タイム（ミリ秒）
    required DateTime measuredAt,    // 計測日時
    required double fps,             // 計測時のFPS
    required double precisionMs,     // 計測精度（±ms）
    String? memo,                    // メモ
    String? videoPath,               // ローカル動画パス
    String? videoUrl,                // クラウド動画URL（将来）
    required Duration startPosition, // 開始位置
    required Duration endPosition,   // 終了位置
    required DateTime createdAt,     // 作成日時
    required DateTime updatedAt,     // 更新日時
    @Default(false) bool isSynced,   // Firestore同期済みフラグ
  }) = _Record;

  factory Record.fromJson(Map<String, dynamic> json) =>
      _$RecordFromJson(json);
}
```

### Firestoreドキュメント構造

```
users/{userId}/records/{recordId}
{
  "athleteName": "田中太郎",
  "event": "50m走",
  "timeMs": 7234,
  "measuredAt": Timestamp,
  "fps": 60.0,
  "precisionMs": 16.67,
  "memo": "3回目の計測、風速1.2m",
  "videoPath": null,
  "videoUrl": null,
  "startPositionUs": 1234000,
  "endPositionUs": 8468000,
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### 種目マスターデータ

```dart
/// よく使われる種目のプリセット
/// ユーザーがカスタム種目を追加することも可能
const defaultEvents = [
  '50m走',
  '100m走',
  '20mシャトルラン',
  '50m走（折り返し）',
  '反復横跳び',
  'その他',
];
```

---

## リポジトリパターン

### インターフェース

```dart
abstract class RecordRepository {
  /// 記録を保存（作成）
  Future<Record> create(Record record);

  /// 記録を取得（ID指定）
  Future<Record?> getById(String id);

  /// 記録一覧を取得（ページネーション対応）
  Future<List<Record>> getList({
    int limit = 20,
    Record? lastRecord,         // カーソルベースページネーション
    String? athleteNameFilter,  // 選手名フィルタ
    String? eventFilter,        // 種目フィルタ
    DateTime? dateFrom,         // 日付範囲（開始）
    DateTime? dateTo,           // 日付範囲（終了）
    RecordSortKey sortKey = RecordSortKey.measuredAtDesc,
  });

  /// 記録を更新
  Future<Record> update(Record record);

  /// 記録を削除
  Future<void> delete(String id);

  /// 全記録を取得（CSVエクスポート用）
  Future<List<Record>> getAll();

  /// 未同期の記録を取得
  Future<List<Record>> getUnsyncedRecords();

  /// 同期済みフラグを更新
  Future<void> markAsSynced(String id);
}

enum RecordSortKey {
  measuredAtDesc,  // 日付降順（デフォルト）
  measuredAtAsc,   // 日付昇順
  timeAsc,         // タイム昇順（速い順）
  timeDesc,        // タイム降順
  athleteName,     // 選手名順
}
```

### Firestore実装

```dart
class FirestoreRecordRepository implements RecordRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference get _collection =>
      _firestore.collection('users').doc(_userId).collection('records');

  @override
  Future<List<Record>> getList({
    int limit = 20,
    Record? lastRecord,
    String? athleteNameFilter,
    String? eventFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
    RecordSortKey sortKey = RecordSortKey.measuredAtDesc,
  }) async {
    Query query = _collection;

    // フィルタ適用
    if (athleteNameFilter != null) {
      query = query.where('athleteName', isEqualTo: athleteNameFilter);
    }
    if (eventFilter != null) {
      query = query.where('event', isEqualTo: eventFilter);
    }
    if (dateFrom != null) {
      query = query.where('measuredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFrom));
    }
    if (dateTo != null) {
      query = query.where('measuredAt',
          isLessThanOrEqualTo: Timestamp.fromDate(dateTo));
    }

    // ソート適用
    query = _applySortKey(query, sortKey);

    // ページネーション（カーソルベース）
    if (lastRecord != null) {
      query = query.startAfterDocument(/* lastRecordのDocumentSnapshot */);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Record.fromJson(doc.data())).toList();
  }

  // ... 他のメソッド実装
}
```

### ローカルDB実装（オフライン用）

```dart
/// ローカルストレージにはsqfliteまたはIsarを使用
/// MVPではsqfliteを採用（シンプルさ重視）
class LocalRecordRepository implements RecordRepository {
  final Database _db;

  // テーブル定義
  static const String tableName = 'records';
  static const String createTableSql = '''
    CREATE TABLE $tableName (
      id TEXT PRIMARY KEY,
      athleteName TEXT NOT NULL,
      event TEXT NOT NULL,
      timeMs REAL NOT NULL,
      measuredAt INTEGER NOT NULL,
      fps REAL NOT NULL,
      precisionMs REAL NOT NULL,
      memo TEXT,
      videoPath TEXT,
      startPositionUs INTEGER NOT NULL,
      endPositionUs INTEGER NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isSynced INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // ... CRUD実装
}
```

---

## 一覧画面の設計

### レイアウト

```
┌──────────────────────────────────┐
│  PhysiLog          [フィルタ] [↕]  │  ← AppBar（ソート切替）
├──────────────────────────────────┤
│  ┌────────────────────────────┐  │
│  │ 田中太郎 - 50m走           │  │
│  │ 7.234秒  2026/02/15       │  │
│  │ ±16.7ms (60fps)           │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ 鈴木花子 - 100m走          │  │
│  │ 13.891秒  2026/02/14      │  │
│  │ ±33.3ms (30fps)           │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ ...                        │  │
│  └────────────────────────────┘  │
│                                  │
│                         [+ FAB]  │  ← 新規計測
└──────────────────────────────────┘
```

### 無限スクロール（ページネーション）

```dart
@riverpod
class RecordListNotifier extends _$RecordListNotifier {
  static const _pageSize = 20;
  bool _hasMore = true;
  Record? _lastRecord;

  @override
  Future<List<Record>> build() async {
    return _fetchPage();
  }

  Future<List<Record>> _fetchPage() async {
    final repository = ref.read(recordRepositoryProvider);
    final records = await repository.getList(
      limit: _pageSize,
      lastRecord: _lastRecord,
    );
    _hasMore = records.length == _pageSize;
    if (records.isNotEmpty) {
      _lastRecord = records.last;
    }
    return records;
  }

  /// 次のページを読み込み
  Future<void> loadMore() async {
    if (!_hasMore) return;
    final newRecords = await _fetchPage();
    state = AsyncData([...state.value ?? [], ...newRecords]);
  }
}
```

### フィルタ

```dart
@freezed
class RecordFilter with _$RecordFilter {
  const factory RecordFilter({
    String? athleteName,   // 選手名
    String? event,         // 種目
    DateTime? dateFrom,    // 日付範囲（開始）
    DateTime? dateTo,      // 日付範囲（終了）
  }) = _RecordFilter;
}

@riverpod
class RecordFilterNotifier extends _$RecordFilterNotifier {
  @override
  RecordFilter build() => const RecordFilter();

  void setAthleteName(String? name) =>
      state = state.copyWith(athleteName: name);

  void setEvent(String? event) =>
      state = state.copyWith(event: event);

  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(dateFrom: from, dateTo: to);

  void clear() => state = const RecordFilter();
}
```

### ソート

- デフォルト: 計測日時降順（新しい順）
- 切り替え可能: タイム昇順、選手名順

---

## CRUD操作

### 作成（Create）: 計測画面から保存

```dart
/// 計測完了後の保存フロー
Future<void> saveRecord({
  required MeasurementState measurement,
  required String athleteName,
  required String event,
  String? memo,
  String? videoPath,
}) async {
  final record = Record(
    id: const Uuid().v4(),
    athleteName: athleteName,
    event: event,
    timeMs: measurement.calculatedTime!.inMilliseconds.toDouble(),
    measuredAt: DateTime.now(),
    fps: measurement.fps,
    precisionMs: 1000.0 / measurement.fps,
    memo: memo ?? measurement.memo,
    videoPath: videoPath,
    startPosition: measurement.startPosition!,
    endPosition: measurement.endPosition!,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // ローカルに即時保存
  await localRepository.create(record);

  // Firestoreにも保存（オンライン時）
  try {
    await firestoreRepository.create(record);
    await localRepository.markAsSynced(record.id);
  } catch (e) {
    // オフライン時は同期待ちとして保持
    debugPrint('Firestore保存失敗（オフライン）: $e');
  }
}
```

### 読取（Read）: 一覧 + 詳細表示

- 一覧: 上記ページネーション対応リスト
- 詳細: タップで記録詳細画面に遷移
  - 全フィールドの表示
  - 動画再生（動画が残っている場合）
  - 開始/終了位置のマーカー表示

### 更新（Update）: 編集

- 編集可能フィールド: 選手名、種目、メモ
- タイムの再確定: 計測画面へ戻って再計測

```dart
/// 記録の編集
Future<void> updateRecord(Record record, {
  String? athleteName,
  String? event,
  String? memo,
}) async {
  final updated = record.copyWith(
    athleteName: athleteName ?? record.athleteName,
    event: event ?? record.event,
    memo: memo ?? record.memo,
    updatedAt: DateTime.now(),
    isSynced: false, // 再同期が必要
  );

  await localRepository.update(updated);

  try {
    await firestoreRepository.update(updated);
    await localRepository.markAsSynced(updated.id);
  } catch (e) {
    debugPrint('Firestore更新失敗（オフライン）: $e');
  }
}
```

### 削除（Delete）

```dart
/// 削除フロー
/// 1. 確認ダイアログを表示
/// 2. 確認後に削除実行
/// 3. Snackbarで「元に戻す」オプションを提供

Future<void> deleteRecord(String id) async {
  await localRepository.delete(id);

  try {
    await firestoreRepository.delete(id);
  } catch (e) {
    debugPrint('Firestore削除失敗（オフライン）: $e');
    // 同期時に削除を反映する仕組みが必要
  }
}
```

### 削除UIパターン

- **方法1**: リスト項目をスワイプして削除（Dismissible）
- **方法2**: 詳細画面のメニューから削除
- いずれも確認ダイアログ付き

```dart
/// 削除確認ダイアログ
Future<bool> showDeleteConfirmation(BuildContext context, Record record) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('記録の削除'),
      content: Text(
        '${record.athleteName}の${record.event}（${_formatTime(record.timeMs)}）を削除しますか？\n'
        'この操作は元に戻せません。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('削除'),
        ),
      ],
    ),
  ) ?? false;
}
```

---

## オフライン対応

### N-20: ローカルへの即時書き込み

- 全てのCRUD操作はまずローカルDBに書き込む
- UIはローカルDBの状態を即座に反映
- ユーザーはネットワーク状態を意識しない

### N-21: Firestore同期

```dart
/// 同期サービス
class SyncService {
  final LocalRecordRepository _local;
  final FirestoreRecordRepository _remote;

  /// オンライン復帰時に未同期の記録を同期
  Future<void> syncPendingRecords() async {
    final unsynced = await _local.getUnsyncedRecords();
    for (final record in unsynced) {
      try {
        await _remote.create(record);
        await _local.markAsSynced(record.id);
      } catch (e) {
        debugPrint('同期失敗: ${record.id} - $e');
        // 次回の同期で再試行
      }
    }
  }

  /// 接続状態を監視して自動同期
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingRecords();
      }
    });
  }
}
```

### 同期戦略

- **書き込み**: ローカルファースト → 非同期でFirestore同期
- **読み込み**: ローカルDBから読み込み（高速）
- **競合解決**: `updatedAt` が新しい方を採用（ラストライトウィン）
- **初回ログイン**: Firestoreからローカルへ全データダウンロード

---

## CSVエクスポート（MVP+: F-24）

### エクスポートフォーマット

```csv
選手名,種目,タイム(秒),計測日,FPS,精度(±ms),メモ
田中太郎,50m走,7.234,2026-02-15,60,16.67,3回目の計測
鈴木花子,100m走,13.891,2026-02-14,30,33.33,
佐藤次郎,50m走,7.512,2026-02-13,60,16.67,風速1.2m
```

### 実装

```dart
/// CSVエクスポート
class CsvExporter {
  /// 記録リストをCSV文字列に変換
  String export(List<Record> records) {
    final buffer = StringBuffer();

    // ヘッダー行
    buffer.writeln('選手名,種目,タイム(秒),計測日,FPS,精度(±ms),メモ');

    // データ行
    for (final record in records) {
      buffer.writeln([
        _escape(record.athleteName),
        _escape(record.event),
        (record.timeMs / 1000).toStringAsFixed(3),
        DateFormat('yyyy-MM-dd').format(record.measuredAt),
        record.fps.toStringAsFixed(0),
        record.precisionMs.toStringAsFixed(2),
        _escape(record.memo ?? ''),
      ].join(','));
    }

    return buffer.toString();
  }

  /// CSV特殊文字のエスケープ
  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// share_plusパッケージでの共有
Future<void> exportAndShare(List<Record> records) async {
  final csv = CsvExporter().export(records);
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/physilog_export.csv');
  await file.writeAsString(csv, encoding: utf8);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'PhysiLog 計測記録',
  );
}
```

---

## ファイル構成（予定）

```
lib/
├── features/
│   └── records/
│       ├── domain/
│       │   ├── record.dart               # Recordエンティティ
│       │   ├── record_filter.dart         # フィルタモデル
│       │   └── record_repository.dart     # リポジトリインターフェース
│       ├── data/
│       │   ├── firestore_record_repository.dart  # Firestore実装
│       │   ├── local_record_repository.dart      # ローカルDB実装
│       │   └── sync_service.dart                 # 同期サービス
│       ├── application/
│       │   ├── record_list_notifier.dart   # 一覧状態管理
│       │   ├── record_filter_notifier.dart # フィルタ状態管理
│       │   └── csv_exporter.dart           # CSVエクスポート
│       └── presentation/
│           ├── record_list_screen.dart     # 一覧画面
│           ├── record_detail_screen.dart   # 詳細画面
│           ├── record_edit_screen.dart     # 編集画面
│           └── widgets/
│               ├── record_list_tile.dart   # リスト項目
│               ├── record_filter_sheet.dart # フィルタシート
│               └── delete_confirmation_dialog.dart
```

---

## 実装順序

1. **Phase 1**: Recordエンティティとリポジトリインターフェース定義
2. **Phase 2**: ローカルDB実装（sqflite）
3. **Phase 3**: 記録保存フロー（計測画面→保存）
4. **Phase 4**: 記録一覧画面（F-21）
5. **Phase 5**: 記録詳細画面
6. **Phase 6**: 記録編集機能（F-22）
7. **Phase 7**: 記録削除機能（F-23）
8. **Phase 8**: Firestore実装と同期サービス
9. **Phase 9**: CSVエクスポート（F-24, MVP+）

---

## テスト方針

### ユニットテスト

- `Record` モデルのシリアライゼーション/デシリアライゼーション
- `CsvExporter` の出力フォーマット
- ソート/フィルタロジック
- 同期サービスのロジック

### リポジトリテスト

- ローカルDBのCRUD操作
- ページネーションの動作
- フィルタの組み合わせ

### ウィジェットテスト

- 一覧画面の表示
- 削除確認ダイアログ
- フィルタUIの動作

### 統合テスト

- 計測→保存→一覧表示→詳細→編集→削除の一連のフロー
- オフライン時の保存→オンライン復帰後の同期
