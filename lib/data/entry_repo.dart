import 'dart:async';

import 'package:sqflite_common/sqlite_api.dart';

import '../core/cn_date.dart';
import 'db.dart';
import 'models/entry.dart';
import 'tag_repo.dart';

/// 列表/导出时的查询条件。
class EntryQuery {
  const EntryQuery({
    this.month,
    this.from,
    this.to,
    this.tag,
    this.mood,
    this.keyword = '',
    this.includeDeleted = false,
    this.limit,
  });

  /// 只看某个月（与 from/to 二选一使用）
  final DateTime? month;
  final DateTime? from;
  final DateTime? to;
  final String? tag;
  final int? mood;
  final String keyword;
  final bool includeDeleted;
  final int? limit;
}

class EntryRepo {
  EntryRepo._();

  static Future<List<Entry>> query(EntryQuery q) async {
    final Database db = await AppDb.instance;
    final List<String> where = <String>[];
    final List<Object?> args = <Object?>[];

    where.add('is_deleted = ?');
    args.add(q.includeDeleted ? 1 : 0);

    if (q.month != null) {
      final DateTime m = q.month!;
      where.add('entry_date >= ? AND entry_date <= ?');
      args
        ..add('${m.year}-${CnDate.p2(m.month)}-01')
        ..add('${m.year}-${CnDate.p2(m.month)}-31');
    }
    if (q.from != null) {
      where.add('entry_date >= ?');
      args.add(CnDate.ymd(q.from!));
    }
    if (q.to != null) {
      where.add('entry_date <= ?');
      args.add(CnDate.ymd(q.to!));
    }
    if (q.mood != null) {
      where.add('mood = ?');
      args.add(q.mood);
    }
    if (q.tag != null && q.tag!.trim().isNotEmpty) {
      where.add("(',' || tags || ',') LIKE ?");
      args.add('%,${q.tag!.trim()},%');
    }
    final String kw = q.keyword.trim();
    if (kw.isNotEmpty) {
      where.add('(title LIKE ? OR content LIKE ? OR tags LIKE ?)');
      final String like = '%$kw%';
      args
        ..add(like)
        ..add(like)
        ..add(like);
    }

    final List<Map<String, Object?>> rows = await db.query(
      'entry',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'entry_date DESC, created_at DESC',
      limit: q.limit,
    );
    return rows.map(Entry.fromMap).toList(growable: false);
  }

  /// 导出用：按时间正序拿全部
  static Future<List<Entry>> all({bool includeDeleted = false}) async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> rows = await db.query(
      'entry',
      where: 'is_deleted = ?',
      whereArgs: <Object?>[includeDeleted ? 1 : 0],
      orderBy: 'entry_date ASC, created_at ASC',
    );
    return rows.map(Entry.fromMap).toList(growable: false);
  }

  static Future<List<Entry>> byMonth(DateTime month) =>
      query(EntryQuery(month: month));

  static Future<Entry?> byId(int id) async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> rows =
        await db.query('entry', where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return Entry.fromMap(rows.first);
  }

  static Future<int> insert(Entry e) async {
    final Database db = await AppDb.instance;
    final Map<String, Object?> map = e.toMap()..remove('id');
    final int id = await db.insert('entry', map);
    unawaited(TagRepo.ensure(e.tags));
    return id;
  }

  static Future<void> update(Entry e) async {
    assert(e.id != null, '更新时必须带 id');
    final Database db = await AppDb.instance;
    await db.update('entry', e.toMap(), where: 'id = ?', whereArgs: <Object?>[e.id]);
    unawaited(TagRepo.ensure(e.tags));
  }

  static Future<void> save(Entry e) async {
    if (e.id == null) {
      await insert(e);
    } else {
      await update(e);
    }
  }

  /// 软删除 → 进回收站
  static Future<void> softDelete(int id) async {
    final Database db = await AppDb.instance;
    await db.update(
      'entry',
      <String, Object?>{
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  static Future<void> restore(int id) async {
    final Database db = await AppDb.instance;
    await db.update(
      'entry',
      <String, Object?>{
        'is_deleted': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  static Future<void> hardDelete(int id) async {
    final Database db = await AppDb.instance;
    await db.delete('entry', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  static Future<void> hardDeleteAll(List<int> ids) async {
    if (ids.isEmpty) return;
    final Database db = await AppDb.instance;
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    await db.delete('entry', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  static Future<int> countDeleted() async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM entry WHERE is_deleted = 1',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// 清理回收站中删除超过 [days] 天的记录，返回清理条数
  static Future<int> purgeOlderThan({int days = 30}) async {
    final Database db = await AppDb.instance;
    final int threshold =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return db.delete(
      'entry',
      where: 'is_deleted = 1 AND updated_at < ?',
      whereArgs: <Object?>[threshold],
    );
  }

  /// 所有使用过的标签，按出现频次排序
  static Future<List<String>> allTags() async {
    final List<Entry> entries = await all();
    final Map<String, int> counter = <String, int>{};
    for (final Entry e in entries) {
      for (final String t in e.tags) {
        counter[t] = (counter[t] ?? 0) + 1;
      }
    }
    final List<String> tags = counter.keys.toList();
    tags.sort((String a, String b) {
      final int byCount = counter[b]!.compareTo(counter[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
    return tags;
  }

  /// 有日记的月份列表，新的在前
  static Future<List<DateTime>> monthsWithEntries() async {
    final List<Entry> entries = await all();
    final Set<String> seen = <String>{};
    final List<DateTime> out = <DateTime>[];
    for (final Entry e in entries) {
      final String key = CnDate.monthKey(e.date);
      if (seen.add(key)) out.add(e.date);
    }
    out.sort((DateTime a, DateTime b) => b.compareTo(a));
    return out;
  }

  /// 统计概览：总篇数、总字数、当前连续记录天数
  static Future<DiaryStats> stats() async {
    final List<Entry> entries = await all();
    int words = 0;
    final Set<String> dates = <String>{};
    for (final Entry e in entries) {
      words += e.wordCount;
      dates.add(CnDate.ymd(e.date));
    }
    return DiaryStats(
      totalEntries: entries.length,
      totalWords: words,
      streak: _computeStreak(dates),
      writtenDays: dates.length,
    );
  }

  static int _computeStreak(Set<String> dates) {
    if (dates.isEmpty) return 0;
    DateTime cursor = CnDate.dayOnly(DateTime.now());
    // 今天没写不算断签，从昨天开始回溯
    if (!dates.contains(CnDate.ymd(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (dates.contains(CnDate.ymd(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ------------------------------------------------------------ 恢复备份

  /// 从 JSON 备份批量恢复。
  ///
  /// [mode] 为 [ImportMode.merge] 时按「日期」去重后追加，
  /// 为 [ImportMode.replace] 时先清空再写入。
  static Future<int> importEntries(
    List<Entry> entries,
    ImportMode mode,
  ) async {
    final Database db = await AppDb.instance;
    final Batch batch = db.batch();

    if (mode == ImportMode.replace) {
      batch.delete('entry');
      batch.delete('tag');
    }

    // 合并模式下已存在的「同一天」视为已恢复过，直接跳过
    final Set<String> existing = <String>{};
    if (mode == ImportMode.merge) {
      final List<Map<String, Object?>> rows = await db.query('entry', columns: <String>['entry_date']);
      for (final Map<String, Object?> r in rows) {
        existing.add(r['entry_date'] as String);
      }
    }

    int written = 0;
    for (final Entry e in entries) {
      if (mode == ImportMode.merge && existing.contains(CnDate.ymd(e.date))) continue;
      // 恢复时丢弃原 id，避免和本地已有记录主键冲突
      final Map<String, Object?> map = e.toMap()..remove('id');
      batch.insert('entry', map);
      written++;
    }

    await batch.commit(noResult: true);

    final Set<String> allTags = <String>{};
    for (final Entry e in entries) {
      allTags.addAll(e.tags);
    }
    await TagRepo.ensure(allTags);
    return written;
  }
}

enum ImportMode { merge, replace }

class DiaryStats {
  const DiaryStats({
    required this.totalEntries,
    required this.totalWords,
    required this.streak,
    required this.writtenDays,
  });

  final int totalEntries;
  final int totalWords;
  final int streak;
  final int writtenDays;
}