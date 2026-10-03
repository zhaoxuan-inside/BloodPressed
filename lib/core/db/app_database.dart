import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 数据库（应用唯一数据源）。
///
/// 设计要点（为未来云同步保留能力）：
/// * 主键一律为 UUID 或自增 + 实体 UUID；
/// * 记录表带 created_at / updated_at / deleted_at（软删除）；
/// * 每次写操作同步写入 sync_outbox 变更日志，任何云平台接入后按 outbox 推送即可。
class AppDatabase {
  AppDatabase._(this.db);

  static const int _dbVersion = 1;
  static AppDatabase? _instance;

  final Database db;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    final dir = await getDatabasesPathSafe();
    final db = await openDatabase(
      p.join(dir, 'blood_pressed.db'),
      version: _dbVersion,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }

  /// 供测试注入内存数据库。
  static Future<AppDatabase> openForTest(Database database) async {
    _instance = AppDatabase._(database);
    await _onCreate(database, _dbVersion);
    return _instance!;
  }

  static void resetInstanceForTest() => _instance = null;

  static Future<String> getDatabasesPathSafe() async {
    try {
      return await getDatabasesPath();
    } catch (_) {
      // sqflite_common_ffi 测试环境外也可用默认目录
      return '.';
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bp_records (
        id TEXT PRIMARY KEY,
        systolic INTEGER NOT NULL,
        diastolic INTEGER NOT NULL,
        pulse INTEGER,
        measured_at INTEGER NOT NULL,
        arm TEXT NOT NULL DEFAULT 'left',
        posture TEXT,
        note TEXT,
        photo_path TEXT,
        source TEXT NOT NULL DEFAULT 'manual',
        device_id TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_state TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_records_measured_at ON bp_records (measured_at DESC)');
    await db.execute(
        'CREATE INDEX idx_records_sync_state ON bp_records (sync_state)');

    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_outbox_created ON sync_outbox (created_at)');

    await db.execute('''
      CREATE TABLE llm_profiles (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        config TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_chat_created ON chat_messages (created_at)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // 后续版本在此按 oldVersion 逐级迁移。
  }
}
