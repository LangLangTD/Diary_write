import 'dart:convert';

import 'package:date_write/core/cn_date.dart';
import 'package:date_write/data/models/entry.dart';
import 'package:date_write/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 这组测试会真正跑一遍三种导出，作用是把「中文 PDF 不显示方框」
/// 这个问题在 CI/本地就拦下来，而不是等到导出时才发现字体没打进去。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateTime day = DateTime(2026, 10, 6);

  List<Entry> sample() => <Entry>[
        Entry(
          id: 1,
          title: '周末去了趟植物园',
          content: '天气不错，龟背竹长得很好。\n\n拍了些照片，晚上再修一下。',
          date: day,
          mood: 4,
          weather: '晴',
          tags: <String>['日常', '植物'],
          wordCount: 26,
          createdAt: DateTime(2026, 10, 6, 20, 30),
          updatedAt: DateTime(2026, 10, 6, 20, 30),
        ),
        Entry(
          id: 2,
          title: '',
          content: '没什么特别的事，就是读了会儿书。',
          date: DateTime(2026, 10, 7),
          mood: 3,
          weather: '多云',
          tags: const <String>[],
          wordCount: 13,
          createdAt: DateTime(2026, 10, 7, 23, 10),
          updatedAt: DateTime(2026, 10, 7, 23, 10),
        ),
      ];

  group('导出', () {
    test('TXT 带 BOM 且包含中文正文', () async {
      final Uint8ListLike bytes = await ExportService.build(
        ExportFormat.txt,
        sample(),
        const ExportOptions(),
      );
      final String text = utf8.decode(bytes);
      // BOM：没有它 Windows 记事本会把中文显示成乱码。
      // 注意 utf8.decode 自身会吃掉 BOM，所以只能查原始字节。
      expect(<int>[bytes[0], bytes[1], bytes[2]], <int>[0xEF, 0xBB, 0xBF]);
      expect(text.startsWith('我的日记'), isTrue);
      expect(text.contains('周末去了趟植物园'), isTrue);
      expect(text.contains('2026年10月6日'), isTrue);
      expect(text.contains('#日常'), isTrue);
    });

    test('DOCX 生成的是合法 zip 包', () async {
      final Uint8ListLike bytes = await ExportService.build(
        ExportFormat.docx,
        sample(),
        const ExportOptions(),
      );
      expect(bytes.length, greaterThan(1000));
      // ZIP 本地文件头魔数 PK\x03\x04
      expect(<int>[bytes[0], bytes[1], bytes[2], bytes[3]],
          <int>[0x50, 0x4B, 0x03, 0x04]);
    });

    test('PDF 生成合法 PDF 并内嵌了中文字体', () async {
      final Uint8ListLike bytes = await ExportService.build(
        ExportFormat.pdf,
        sample(),
        const ExportOptions(),
      );
      final String asLatin = latin1.decode(bytes, allowInvalid: true);
      expect(asLatin.startsWith('%PDF-'), isTrue);
      // pdf 包会把内嵌字体裁剪成只含用到的字形，所以文件不大；
      // 判断字体有没有真的打进去，要看有没有 FontFile 流。
      expect(asLatin, contains('FontFile'));
      expect(bytes.length, greaterThan(10000));
    });

    test('关闭封面和目录后 PDF 仍可生成', () async {
      final Uint8ListLike bytes = await ExportService.build(
        ExportFormat.pdf,
        sample(),
        const ExportOptions(coverPage: false, tocPage: false),
      );
      expect(latin1.decode(bytes, allowInvalid: true).startsWith('%PDF-'), isTrue);
    });

    test('不输出元信息时 TXT 里没有心情标签', () async {
      final Uint8ListLike bytes = await ExportService.build(
        ExportFormat.txt,
        sample(),
        const ExportOptions(includeMeta: false),
      );
      final String text = utf8.decode(bytes);
      expect(text.contains('心情:'), isFalse);
      expect(text.contains('#日常'), isFalse);
      expect(text.contains('周末去了趟植物园'), isTrue);
    });
  });

  group('JSON 备份', () {
    test('可完整还原每一篇日记', () {
      final Uint8ListLike bytes = ExportService.buildBackupJson(sample());
      final Map<String, dynamic> decoded =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(decoded['count'], 2);
      final List<dynamic> entries = decoded['entries'] as List<dynamic>;
      expect(entries.length, 2);

      final Entry restored = Entry.fromMap(
        Map<String, Object?>.from(entries.first as Map),
      );
      expect(restored.title, '周末去了趟植物园');
      expect(restored.tags, <String>['日常', '植物']);
      expect(restored.mood, 4);
      expect(CnDate.ymd(restored.date), '2026-10-06');
    });
  });
}

/// 避免每处都写 dart:typed_data 的 import。
typedef Uint8ListLike = List<int>;