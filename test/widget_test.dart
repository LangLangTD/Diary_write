import 'package:date_write/core/cn_date.dart';
import 'package:date_write/data/models/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CnDate', () {
    test('ymd 往返解析', () {
      final DateTime d = DateTime(2026, 10, 6);
      expect(CnDate.ymd(d), '2026-10-06');
      expect(CnDate.tryParseYmd('2026-10-06'), DateTime(2026, 10, 6));
    });

    test('非法日期返回 null', () {
      expect(CnDate.tryParseYmd('2026/10/06'), isNull);
      expect(CnDate.tryParseYmd('2026-13-40'), isNull);
      expect(CnDate.tryParseYmd(null), isNull);
    });

    test('星期按中文习惯从周一开始', () {
      expect(CnDate.weekday(DateTime(2026, 10, 5)), '星期一');
      expect(CnDate.weekday(DateTime(2026, 10, 11)), '星期日');
    });

    test('relative 今天/昨天/前天', () {
      final DateTime now = DateTime(2026, 10, 6, 15, 30);
      expect(CnDate.friendly(DateTime(2026, 10, 6), now: now), '今天');
      expect(CnDate.friendly(DateTime(2026, 10, 5), now: now), '昨天');
      expect(CnDate.friendly(DateTime(2026, 10, 4), now: now), '前天');
      // 昨天 23:00 写、今天 01:00 看，仍应算「今天」
      expect(CnDate.friendly(DateTime(2026, 10, 6, 1, 0), now: now), '今天');
    });
  });

  group('Entry', () {
    test('中文按字、英文按词计数', () {
      expect(Entry.countWords('今天天气不错'), 6);
      expect(Entry.countWords('hello world'), 2);
      expect(Entry.countWords(''), 0);
    });

    test('tags 以逗号存储并可还原', () {
      final Entry e = Entry(
        title: 't',
        date: _fixedDate,
        createdAt: _fixedDate,
        updatedAt: _fixedDate,
      );
      expect(e.toMap()['tags'], '');
      expect(
        Entry.fromMap(<String, Object?>{...e.toMap(), 'tags': 'a, b ,c'}).tags,
        <String>['a', 'b', 'c'],
      );
    });

    test('无标题时 displayTitle 回落到「无标题」', () {
      final Entry e = Entry.draft();
      expect(e.displayTitle, '无标题');
      expect(e.hasTitle, isFalse);
    });

    test('标题正文都为空才算空白', () {
      final Entry e = Entry.draft();
      expect(e.isBlank, isTrue);
      expect(e.copyWith(content: '写了一点').isBlank, isFalse);
      expect(e.copyWith(title: '标题').isBlank, isFalse);
    });
  });
}

/// 固定日期，供测试数据使用。
final DateTime _fixedDate = DateTime(2026, 10, 6);