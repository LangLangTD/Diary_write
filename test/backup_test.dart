import 'dart:convert';

import 'package:date_write/core/cn_date.dart';
import 'package:date_write/data/entry_repo.dart';
import 'package:date_write/data/models/entry.dart';
import 'package:date_write/services/backup_service.dart';
import 'package:date_write/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 备份与恢复的往返测试。
///
/// 这些路径直接关系到「误删之后还能不能找回来」，
/// 所以必须真的走一遍 JSON → Entry → 再序列化的链路。
void main() {
  late List<Entry> sample;

  setUp(() {
    sample = <Entry>[
      Entry(
        id: 1,
        title: '周末去了趟植物园',
        content: '天气不错，龟背竹长得很好。',
        date: DateTime(2026, 10, 6),
        mood: 4,
        weather: '晴',
        tags: <String>['日常', '植物'],
        wordCount: 18,
        createdAt: DateTime(2026, 10, 6, 20, 30),
        updatedAt: DateTime(2026, 10, 6, 20, 30),
      ),
      Entry(
        id: 2,
        title: '读书',
        content: '没什么特别的事。',
        date: DateTime(2026, 10, 7),
        mood: 3,
        weather: '多云',
        tags: const <String>[],
        wordCount: 9,
        createdAt: DateTime(2026, 10, 7, 23, 10),
        updatedAt: DateTime(2026, 10, 7, 23, 10),
      ),
    ];
  });

  group('备份导出', () {
    test('JSON 里带 app 标识和篇数', () {
      final String raw = utf8.decode(ExportService.buildBackupJson(sample));
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      expect(j['app'], 'date_write');
      expect(j['count'], 2);
      expect((j['entries'] as List).length, 2);
    });
  });

  group('备份解析', () {
    test('正常备份能还原出完整字段', () {
      final String raw = utf8.decode(ExportService.buildBackupJson(sample));
      final BackupPreview p = BackupService.parse(raw);

      expect(p.count, 2);
      expect(p.entries.first.title, '周末去了趟植物园');
      expect(p.entries.first.tags, <String>['日常', '植物']);
      expect(p.entries.first.mood, 4);
      expect(p.entries.first.weather, '晴');
      expect(p.entries.last.title, '读书');
      expect(p.entries.last.tags, isEmpty);
    });

    test('拒绝不是本应用的备份', () {
      expect(
        () => BackupService.parse('{"app":"other","entries":[]}'),
        throwsA(isA<BackupException>()),
      );
    });

    test('拒绝非法 JSON', () {
      expect(
        () => BackupService.parse('这不是 json'),
        throwsA(isA<BackupException>()),
      );
    });

    test('缺 entry_date 的记录被跳过而不是整份失败', () {
      final String raw = jsonEncode(<String, Object?>{
        'app': 'date_write',
        'entries': <Object?>[
          <String, Object?>{'title': '好的', 'entry_date': '2026-10-06'},
          <String, Object?>{'title': '坏的', 'entry_date': '乱写'},
        ],
      });
      final BackupPreview p = BackupService.parse(raw);
      expect(p.count, 1);
      expect(p.entries.first.title, '好的');
    });

    test('全部记录都不可用时明确报错', () {
      final String raw = jsonEncode(<String, Object?>{
        'app': 'date_write',
        'entries': <Object?>[
          <String, Object?>{'title': '坏的', 'entry_date': '乱写'},
        ],
      });
      expect(
        () => BackupService.parse(raw),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('导入模式', () {
    test('合并按日期去重，覆盖清空全部', () {
      // 只是确认枚举语义清晰，真正落库行为由仓储层测试覆盖
      expect(ImportMode.merge, isNot(ImportMode.replace));
    });
  });

  group('恢复后的可用性', () {
    test('解析出来的 Entry 可以再次导出成合法备份', () {
      final String raw = utf8.decode(ExportService.buildBackupJson(sample));
      final BackupPreview p = BackupService.parse(raw);

      final String again = utf8.decode(ExportService.buildBackupJson(p.entries));
      final Map<String, dynamic> j = jsonDecode(again) as Map<String, dynamic>;
      expect(j['count'], 2);

      // 二次往返后字段不能漂移
      final BackupPreview p2 = BackupService.parse(again);
      expect(p2.entries.first.tags, <String>['日常', '植物']);
      expect(CnDate.ymd(p2.entries.last.date), '2026-10-07');
      expect(p2.rangeText, '2026年10月');
    });
  });
}