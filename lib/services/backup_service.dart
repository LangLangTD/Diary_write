import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../core/cn_date.dart';
import '../data/models/entry.dart';

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 备份文件的解析结果，用于在写入前先让用户确认。
class BackupPreview {
  const BackupPreview({
    required this.entries,
    required this.exportedAt,
    required this.sourceName,
  });

  final List<Entry> entries;
  final DateTime? exportedAt;
  final String sourceName;

  int get count => entries.length;

  String get rangeText {
    if (entries.isEmpty) return '空备份';
    final DateTime a = entries.first.date;
    final DateTime b = entries.last.date;
    if (CnDate.sameMonth(a, b)) return CnDate.cnMonth(a);
    if (a.year == b.year) return '${a.year}年 ${a.month}月 — ${b.month}月';
    return '${a.year}年${a.month}月 — ${b.year}年${b.month}月';
  }
}

/// 备份的读取与解析。写入由 [EntryRepo.restore] 负责。
class BackupService {
  BackupService._();

  /// 让用户选一个备份文件并解析。返回 null 表示用户取消。
  static Future<BackupPreview?> pick() async {
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: '选择日记备份',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (file == null) return null;

    // file_picker 13 起 PlatformFile 不再暴露 bytes 字段，
    // 改用 readAsBytes()，Android 的 content:// URI 也能正常读
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw BackupException('这个备份文件是空的');
    }

    String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      throw BackupException('文件不是 UTF-8 编码的文本，可能选错了文件');
    }
    return parse(raw, sourceName: file.name);
  }

  static BackupPreview parse(String raw, {String sourceName = '备份'}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw BackupException('这不是合法的 JSON 文件');
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupException('备份文件结构不对');
    }
    if (decoded['app'] != 'date_write') {
      throw BackupException('这不是日记本导出的备份文件');
    }
    final Object? rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw BackupException('备份文件里没有日记数据');
    }

    final List<Entry> entries = <Entry>[];
    int skipped = 0;
    for (final Object? item in rawEntries) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final Map<String, Object?> m = <String, Object?>{
        for (final MapEntry<Object?, Object?> kv in item.entries)
          kv.key.toString(): kv.value,
      };
      // 缺 entry_date 的记录没法确定归属日期，只能跳过
      if (CnDate.tryParseYmd(m['entry_date'] as String?) == null) {
        skipped++;
        continue;
      }
      try {
        entries.add(Entry.fromMap(m));
      } catch (_) {
        skipped++;
      }
    }

    if (entries.isEmpty && skipped > 0) {
      throw BackupException('备份里的 $skipped 条记录都无法识别');
    }

    final String? ts = decoded['exportedAt'] as String?;
    return BackupPreview(
      entries: entries,
      exportedAt: ts == null ? null : DateTime.tryParse(ts),
      sourceName: sourceName,
    );
  }
}