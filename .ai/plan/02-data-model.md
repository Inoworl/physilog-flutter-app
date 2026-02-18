# 02. データモデル設計

## 概要

PhysiLog のデータモデル設計。Firestore をプライマリストレージとし、オフライン対応のためローカルDB（Hive/Isar）をキャッシュとして併用する。

---

## 1. Firestore コレクション設計

### 1.1 `records` コレクション

体力測定の計測記録を保存するメインコレクション。

```
records/{recordId}
{
  id: string (auto),            // ドキュメントID（自動生成）
  userId: string,               // 認証ユーザーID（Firebase Auth uid）
  athleteName: string,          // 選手名
  eventType: string,            // 種目名 "50m走", "100m走" 等（自由入力 + サジェスト）
  startMs: number,              // 開始タイムスタンプ（ミリ秒）※動画内の位置
  endMs: number,                // 終了タイムスタンプ（ミリ秒）※動画内の位置
  durationMs: number,           // 算出タイム（ミリ秒）= endMs - startMs
  measuredAt: timestamp,        // 測定日時（実際に計測を行った日時）
  memo: string,                 // メモ（計測ルール、天候、コンディション等）
  videoRef: string | null,      // 動画ローカルパス or null（端末内保持のため）
  fps: number | null,           // 動画のFPS（精度表示用、例: 30, 60, 120, 240）
  createdAt: timestamp,         // レコード作成日時
  updatedAt: timestamp,         // レコード更新日時
}
```

#### フィールド詳細

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | string | Yes | Firestoreの自動生成ID |
| `userId` | string | Yes | Firebase Auth の uid。データのオーナーを特定 |
| `athleteName` | string | Yes | 選手名。空文字不可 |
| `eventType` | string | Yes | 種目名。自由入力だがサジェスト機能あり |
| `startMs` | number | Yes | 動画内の開始フレーム位置（ミリ秒） |
| `endMs` | number | Yes | 動画内の終了フレーム位置（ミリ秒） |
| `durationMs` | number | Yes | 算出タイム（ミリ秒）。endMs - startMs で計算 |
| `measuredAt` | timestamp | Yes | 実際の測定日時 |
| `memo` | string | No | 自由記述メモ。デフォルト空文字 |
| `videoRef` | string \| null | No | 動画ファイルのローカルパス。削除済みの場合 null |
| `fps` | number \| null | No | 動画のFPS。精度の参考情報として保持 |
| `createdAt` | timestamp | Yes | サーバータイムスタンプ使用 |
| `updatedAt` | timestamp | Yes | サーバータイムスタンプ使用 |

#### eventType のサジェスト候補（初期値）

```dart
const defaultEventTypes = [
  '50m走',
  '100m走',
  '200m走',
  '400m走',
  'シャトルラン',
  '反復横跳び',
  'その他',
];
```

### 1.2 `users` コレクション（Firebase Auth 導入時）

ユーザーのプロフィール情報を保存するコレクション。Auth 導入時に追加。

```
users/{uid}
{
  id: string (uid),             // Firebase Auth の uid
  displayName: string | null,   // 表示名（任意）
  createdAt: timestamp,         // アカウント作成日時
}
```

#### フィールド詳細

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | string | Yes | Firebase Auth の uid をそのまま使用 |
| `displayName` | string \| null | No | 表示名。未設定の場合 null |
| `createdAt` | timestamp | Yes | サーバータイムスタンプ使用 |

---

## 2. ローカルDB設計（Hive/Isar）

### 2.1 目的

- オフライン時でも計測記録の閲覧・作成が可能
- ネットワーク復帰時に Firestore と同期

### 2.2 ローカルキャッシュ構造

ローカルDBには Firestore と同じスキーマのデータを保持する。追加で同期管理用のメタデータを付与する。

```
LocalMeasurementRecord {
  // Firestoreと同一フィールド
  id: string,
  userId: string,
  athleteName: string,
  eventType: string,
  startMs: int,
  endMs: int,
  durationMs: int,
  measuredAt: DateTime,
  memo: string,
  videoRef: string?,
  fps: double?,
  createdAt: DateTime,
  updatedAt: DateTime,

  // 同期管理用メタデータ
  syncStatus: SyncStatus,       // synced | pendingCreate | pendingUpdate | pendingDelete
  lastSyncedAt: DateTime?,      // 最後にFirestoreと同期した日時
}
```

#### SyncStatus の定義

```dart
enum SyncStatus {
  synced,         // Firestoreと同期済み
  pendingCreate,  // ローカルで作成、Firestore未反映
  pendingUpdate,  // ローカルで更新、Firestore未反映
  pendingDelete,  // ローカルで削除マーク、Firestore未反映
}
```

### 2.3 Firestore との同期戦略

#### 基本方針

- **ローカルファースト**: 書き込みは常にローカルDBを先に更新
- **バックグラウンド同期**: ネットワーク接続時にバックグラウンドでFirestoreへ反映
- **コンフリクト解決**: 最終更新日時（updatedAt）ベースで新しい方を採用（Last Write Wins）

#### 同期フロー

```
[書き込み時]
1. ローカルDBに書き込み（syncStatus = pending*）
2. ネットワーク接続確認
3. 接続あり → Firestoreに書き込み → syncStatus = synced に更新
4. 接続なし → そのまま保持（後続の同期処理で反映）

[読み込み時]
1. ローカルDBから即座に返却（UIに表示）
2. バックグラウンドでFirestoreから最新を取得
3. 差分があればローカルDBを更新 → UIに反映

[アプリ起動時]
1. pending* のレコードをFirestoreに反映
2. Firestoreの最新データでローカルDBを更新
```

#### 同期タイミング

- アプリ起動時
- ネットワーク接続復帰時（connectivity_plus で検知）
- レコード作成/更新/削除操作時（即時）
- 一覧画面のプルトゥリフレッシュ時

---

## 3. Dart モデルクラス設計

### 3.1 パッケージ選定

- **freezed**: イミュータブルなモデルクラスの自動生成
- **json_serializable**: JSON シリアライズ/デシリアライズの自動生成
- **cloud_firestore**: Firestore との型変換に使用

### 3.2 MeasurementRecord クラス

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'measurement_record.freezed.dart';
part 'measurement_record.g.dart';

@freezed
class MeasurementRecord with _$MeasurementRecord {
  const MeasurementRecord._();

  const factory MeasurementRecord({
    required String id,
    required String userId,
    required String athleteName,
    required String eventType,
    required int startMs,
    required int endMs,
    required int durationMs,
    required DateTime measuredAt,
    @Default('') String memo,
    String? videoRef,
    double? fps,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MeasurementRecord;

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) =>
      _$MeasurementRecordFromJson(json);

  /// Firestore ドキュメントからの変換
  factory MeasurementRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeasurementRecord(
      id: doc.id,
      userId: data['userId'] as String,
      athleteName: data['athleteName'] as String,
      eventType: data['eventType'] as String,
      startMs: data['startMs'] as int,
      endMs: data['endMs'] as int,
      durationMs: data['durationMs'] as int,
      measuredAt: (data['measuredAt'] as Timestamp).toDate(),
      memo: data['memo'] as String? ?? '',
      videoRef: data['videoRef'] as String?,
      fps: (data['fps'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Firestore 書き込み用の Map 変換
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'athleteName': athleteName,
      'eventType': eventType,
      'startMs': startMs,
      'endMs': endMs,
      'durationMs': durationMs,
      'measuredAt': Timestamp.fromDate(measuredAt),
      'memo': memo,
      'videoRef': videoRef,
      'fps': fps,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// タイムの表示用フォーマット（例: "6.85秒"）
  String get formattedDuration {
    final seconds = durationMs / 1000;
    return '${seconds.toStringAsFixed(2)}秒';
  }

  /// FPS に基づく精度の表示（例: "±16.7ms (60fps)"）
  String? get accuracyInfo {
    if (fps == null || fps == 0) return null;
    final accuracy = 1000 / fps!;
    return '±${accuracy.toStringAsFixed(1)}ms (${fps!.toInt()}fps)';
  }
}
```

### 3.3 バリデーションルール

```dart
class MeasurementRecordValidator {
  /// バリデーション実行。エラーがあればエラーメッセージのリストを返す
  static List<String> validate(MeasurementRecord record) {
    final errors = <String>[];

    // 選手名: 空でないこと
    if (record.athleteName.trim().isEmpty) {
      errors.add('選手名は必須です');
    }

    // 選手名: 最大50文字
    if (record.athleteName.length > 50) {
      errors.add('選手名は50文字以内で入力してください');
    }

    // 種目名: 空でないこと
    if (record.eventType.trim().isEmpty) {
      errors.add('種目名は必須です');
    }

    // 開始/終了: 開始 < 終了
    if (record.startMs >= record.endMs) {
      errors.add('開始タイムは終了タイムより前である必要があります');
    }

    // タイムスタンプ: 0以上
    if (record.startMs < 0 || record.endMs < 0) {
      errors.add('タイムスタンプは0以上である必要があります');
    }

    // durationMs の整合性チェック
    if (record.durationMs != record.endMs - record.startMs) {
      errors.add('算出タイムが開始・終了タイムと一致しません');
    }

    // メモ: 最大500文字
    if (record.memo.length > 500) {
      errors.add('メモは500文字以内で入力してください');
    }

    // FPS: 正の数であること（設定されている場合）
    if (record.fps != null && record.fps! <= 0) {
      errors.add('FPSは正の数である必要があります');
    }

    return errors;
  }
}
```

### 3.4 UserProfile クラス（Auth 導入時）

```dart
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    String? displayName,
    required DateTime createdAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      displayName: data['displayName'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
```

---

## 4. インデックス設計

### 4.1 Firestore 複合インデックス

Firestore コンソールまたは `firestore.indexes.json` で設定する。

```json
{
  "indexes": [
    {
      "collectionGroup": "records",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "measuredAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "records",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "athleteName", "order": "ASCENDING" },
        { "fieldPath": "measuredAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

### 4.2 インデックスの用途

| インデックス | 用途 | クエリ例 |
|---|---|---|
| `userId` + `measuredAt` (DESC) | 一覧画面: ユーザーの計測記録を新しい順に取得 | `where('userId', ==).orderBy('measuredAt', descending: true)` |
| `userId` + `athleteName` + `measuredAt` (DESC) | 選手別フィルタ: 特定選手の記録を新しい順に取得 | `where('userId', ==).where('athleteName', ==).orderBy('measuredAt', descending: true)` |

### 4.3 クエリ例

```dart
// ユーザーの全記録を新しい順に取得（ページネーション対応）
final query = FirebaseFirestore.instance
    .collection('records')
    .where('userId', isEqualTo: currentUserId)
    .orderBy('measuredAt', descending: true)
    .limit(20);

// 選手別フィルタ
final query = FirebaseFirestore.instance
    .collection('records')
    .where('userId', isEqualTo: currentUserId)
    .where('athleteName', isEqualTo: selectedAthlete)
    .orderBy('measuredAt', descending: true);
```

---

## 5. マイグレーション方針

### 5.1 基本方針

Firestore はスキーマレスであるため、RDB のような厳密なマイグレーションは不要。ただし、アプリ側で後方互換性を保つための方針を定める。

### 5.2 フィールド追加時のルール

1. **新規フィールドは常にオプショナル（nullable）で追加**
   - 既存ドキュメントに新フィールドは存在しないため、null 許容にする
   - デフォルト値が必要な場合は、アプリ側の fromFirestore で対応

2. **読み込み時のフォールバック**
   ```dart
   // 例: 新フィールド "category" を追加した場合
   category: data['category'] as String? ?? 'uncategorized',
   ```

3. **既存フィールドの型変更は禁止**
   - 型変更が必要な場合は新フィールドを追加し、旧フィールドは非推奨とする
   - アプリ側で両方のフィールドを読めるようにする

4. **フィールド削除は行わない**
   - 不要になったフィールドはアプリ側で無視するだけにする
   - Firestore のデータは残しておく（将来の参照用）

### 5.3 バージョン管理

```dart
// レコードにスキーマバージョンを持たせる（将来の大規模変更に備える）
const currentSchemaVersion = 1;

// Firestore ドキュメントに schemaVersion フィールドを含める
Map<String, dynamic> toFirestore() {
  return {
    ...existingFields,
    'schemaVersion': currentSchemaVersion,
  };
}

// 読み込み時にバージョンに応じた変換を行う
factory MeasurementRecord.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final version = data['schemaVersion'] as int? ?? 1;

  switch (version) {
    case 1:
      return _fromV1(doc.id, data);
    default:
      return _fromV1(doc.id, data); // フォールバック
  }
}
```

### 5.4 ローカルDB のマイグレーション

- Hive の場合: TypeAdapter のバージョン番号で管理
- Isar の場合: スキーマ変更は自動マイグレーション対応

```dart
// Hive の例
@HiveType(typeId: 0)
class LocalMeasurementRecord {
  @HiveField(0) String id;
  @HiveField(1) String userId;
  // ... 既存フィールド

  // 新フィールドは新しい番号で追加（既存番号は変更しない）
  @HiveField(20) String? newField;
}
```

---

## 6. セキュリティルール

### 6.1 Firestore セキュリティルール

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // records コレクション: 自分のデータのみ読み書き可能
    match /records/{recordId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
                    && request.auth.uid == request.resource.data.userId;
    }

    // users コレクション: 自分のプロフィールのみ読み書き可能
    match /users/{uid} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }
  }
}
```
