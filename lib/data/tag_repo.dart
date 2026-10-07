import 'package:sqflite_common/sqlite_api.dart';

import 'db.dart';

class TagInfo {
  const TagInfo({required this.name, required this.color, this.usage = 0});

  final String name;

  /// 0xAARRGGBB
  final int color;

  /// 被多少篇日记引用
  final int usage;
}

/// 标签及其颜色。
///
/// 颜色在首次出现时自动分配并**持久化**到 tag 表，
/// 这样同一个标签在任何设备、任何时候都是同一个颜色。
class TagRepo {
  TagRepo._();

  /// 暖调低饱和，和纸感主题一致
  static const List<int> _palette = <int>[
    0xFFC77B4A, // 赤陶
    0xFF4A6C5B, // 墨绿
    0xFF8E6C8A, // 藕紫
    0xFF5B7C99, // 靛青
    0xFFA45A52, // 赭红
    0xFF6D8B74, // 松绿
    0xFF9C6644, // 棕橘
    0xFF7D8491, // 石灰蓝
    0xFFB08968, // 沙金
    0xFF6B7280, // 中灰
  ];

  /// 暴露给「标签管理」页做调色盘
  static List<int> get paletteForUi => _palette;

  /// 0xAARRGGBB → 'RRGGBB'，用于展示
  static String colorToHex(int color) =>
      color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  static int hexToColor(String hex) {
    final String v = hex.replaceAll('#', '').trim();
    final int? parsed = int.tryParse(v, radix: 16);
    if (parsed == null) return _palette.first;
    // 兼容不带 alpha 的 6 位写法
    if (v.length == 6) return 0xFF000000 | parsed;
    return parsed;
  }

  static String _colorToDb(int color) => color.toRadixString(16).padLeft(8, '0');

  static int _colorFromDb(String raw) => int.tryParse(raw, radix: 16) ?? _palette.first;

  /// 读取全部标签及使用次数（按使用次数降序）
  static Future<List<TagInfo>> all() async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT t.name AS name,
             t.color AS color,
             (SELECT COUNT(*) FROM entry e
               WHERE (',' || e.tags || ',') LIKE '%,' || t.name || ',%') AS usage
      FROM tag t
      ORDER BY usage DESC, t.name ASC
    ''');
    return rows
        .map((Map<String, Object?> r) => TagInfo(
              name: r['name'] as String,
              color: _colorFromDb(r['color'] as String),
              usage: (r['usage'] as int?) ?? 0,
            ))
        .toList(growable: false);
  }

  static Future<Map<String, int>> colorMap() async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> rows = await db.query('tag');
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        r['name'] as String: _colorFromDb(r['color'] as String),
    };
  }

  /// 串行化队列。保存日记后 [ensure] 是 fire-and-forget 调用的，
  /// 连续保存时多个 ensure 会同时「查已存在 → 插入」，导致同一个标签
  /// 被插两次（UNIQUE 约束冲突）。这里强制排队执行。
  static Future<void> _queue = Future<void>.value();

  /// 为尚未登记的标签自动分配一个未被占用的颜色。
  ///
  /// 在保存日记后调用，保证「标签列表页」和卡片上的颜色始终一致。
  static Future<void> ensure(Iterable<String> names) {
    _queue = _queue.then((_) => _ensureNow(names)).catchError((Object _) {});
    return _queue;
  }

  static Future<void> _ensureNow(Iterable<String> names) async {
    final List<String> wanted =
        names.map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
    if (wanted.isEmpty) return;

    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> existing = await db.query(
      'tag',
      columns: <String>['name'],
    );
    final Set<String> known = existing.map((Map<String, Object?> r) => r['name'] as String).toSet();

    final List<String> missing = wanted.where((String n) => !known.contains(n)).toList();
    if (missing.isEmpty) return;

    // 已占用的颜色不能再分配
    final List<Map<String, Object?>> rows = await db.query('tag', columns: <String>['color']);
    final Set<String> used = rows
        .map((Map<String, Object?> r) => r['color'] as String)
        .toSet();

    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = db.batch();
    int cursor = 0;
    for (final String name in missing) {
      String? chosen;
      for (int i = 0; i < _palette.length; i++) {
        final String hex = _colorToDb(_palette[(cursor + i) % _palette.length]);
        if (!used.contains(hex)) {
          chosen = hex;
          cursor = (cursor + i + 1) % _palette.length;
          break;
        }
      }
      // 调色板用满了，兜底按名字哈希取，保证同名字幕色恒定
      chosen ??= _colorToDb(_palette[_stableHash(name) % _palette.length]);
      used.add(chosen);
      batch.insert(
        'tag',
        <String, Object?>{
          'name': name,
          'color': chosen,
          'created_at': now,
        },
        // 兜底：万一竞态仍然发生，忽略重复而不是让整次保存失败
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> setColor(String name, int color) async {
    final Database db = await AppDb.instance;
    await db.insert(
      'tag',
      <String, Object?>{
        'name': name,
        'color': _colorToDb(color),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 改标签名：同步更新所有引用它的日记
  static Future<void> rename(String from, String to) async {
    final String next = to.trim();
    if (next.isEmpty || next == from) return;
    final Database db = await AppDb.instance;

    final List<Map<String, Object?>> rows =
        await db.query('entry', where: "(',' || tags || ',') LIKE ?",
            whereArgs: <Object?>['%,$from,%']);
    for (final Map<String, Object?> r in rows) {
      final String raw = (r['tags'] as String?) ?? '';
      final List<String> tags = raw
          .split(',')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList();
      if (!tags.remove(from)) continue;
      if (!tags.contains(next)) tags.add(next);
      await db.update(
        'entry',
        <String, Object?>{'tags': tags.join(',')},
        where: 'id = ?',
        whereArgs: <Object?>[r['id']],
      );
    }
    await db.delete('tag', where: 'name = ?', whereArgs: <Object?>[from]);
    await ensure(<String>[next]);
  }

  /// 删掉已经没有任何日记引用的标签
  static Future<void> pruneUnused() async {
    final Database db = await AppDb.instance;
    final Set<String> inUse = <String>{};
    final List<Map<String, Object?>> rows = await db.query('entry', columns: <String>['tags']);
    for (final Map<String, Object?> r in rows) {
      for (final String t in (r['tags'] as String? ?? '').split(',')) {
        final String v = t.trim();
        if (v.isNotEmpty) inUse.add(v);
      }
    }
    if (inUse.isEmpty) {
      await db.delete('tag');
      return;
    }
    final String placeholders = List<String>.filled(inUse.length, '?').join(',');
    await db.delete(
      'tag',
      where: 'name NOT IN ($placeholders)',
      whereArgs: inUse.toList(),
    );
  }

  /// FNV-1a：跨进程/跨版本稳定，和 Dart 自带的 hashCode 不同。
  static int _stableHash(String s) {
    int h = 0x811C9DC5;
    for (final int c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}