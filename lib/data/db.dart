import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// 数据库入口。
///
/// Android 走 `sqflite`（系统 SQLite），Windows 走 `sqflite_common_ffi`
/// （进程内 SQLite），上层拿到的都是同一个 [Database] 接口。
class AppDb {
  AppDb._();

  static const String dbName = 'date_write.db';
  static const int _version = 2;

  static Database? _instance;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static DatabaseFactory _factory() {
    if (_isMobile) return sqflite.databaseFactory;
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }

  static Future<Database> get instance async {
    final Database? cached = _instance;
    if (cached != null) return cached;
    final DatabaseFactory f = _factory();
    final String dir = await _databasesDir(f);
    final Database db = await f.openDatabase(
      p.join(dir, dbName),
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await _createSchema(db);
        },
        onUpgrade: (Database db, int from, int to) async {
          // v1 -> v2：标签独立成表，用于保存颜色
          if (from < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS tag (
                name       TEXT PRIMARY KEY,
                color      TEXT NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''');
          }
        },
      ),
    );
    _instance = db;
    return db;
  }

  /// 数据库所在目录。
  ///
  /// `sqflite_common_ffi` 的默认路径是**当前工作目录**下的 `.dart_tool/`，
  /// 打包后这意味着「换个目录启动 exe 就看不到日记」。这里在桌面端
  /// 显式固定到应用支持目录（Windows 下是 %APPDATA%\date_write）。
  static Future<String> _databasesDir(DatabaseFactory f) async {
    if (_isMobile) return f.getDatabasesPath();
    final Directory dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL DEFAULT '',
        content     TEXT    NOT NULL DEFAULT '',
        entry_date  TEXT    NOT NULL,
        mood        INTEGER,
        weather     TEXT,
        tags        TEXT    NOT NULL DEFAULT '',
        word_count  INTEGER NOT NULL DEFAULT 0,
        is_deleted  INTEGER NOT NULL DEFAULT 0,
        created_at  INTEGER NOT NULL,
        updated_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_entry_date ON entry(entry_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_entry_deleted ON entry(is_deleted)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tag (
        name       TEXT PRIMARY KEY,
        color      TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 轻量设置表，避免为了几个偏好值再引一个依赖
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_setting (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// 仅供测试注入使用
  static void debugSetInstance(Database? db) => _instance = db;
}