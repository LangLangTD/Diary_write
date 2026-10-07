import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/cn_date.dart';
import '../data/models/entry.dart';

enum ExportFormat {
  txt('TXT', 'txt', '纯文本，任何设备都能打开', Icons.text_snippet_outlined),
  docx('Word', 'docx', 'Word 文档，可继续编辑', Icons.description_outlined),
  pdf('PDF', 'pdf', '排版固定，适合打印存档', Icons.picture_as_pdf_outlined);

  const ExportFormat(this.label, this.ext, this.hint, this.icon);

  final String label;
  final String ext;
  final String hint;
  final IconData icon;
}

class ExportOptions {
  const ExportOptions({
    this.includeMeta = true,
    this.coverPage = true,
    this.tocPage = true,
  });

  /// 是否输出心情 / 天气 / 标签
  final bool includeMeta;

  /// PDF 封面页
  final bool coverPage;

  /// PDF 目录页
  final bool tocPage;

  ExportOptions copyWith({bool? includeMeta, bool? coverPage, bool? tocPage}) {
    return ExportOptions(
      includeMeta: includeMeta ?? this.includeMeta,
      coverPage: coverPage ?? this.coverPage,
      tocPage: tocPage ?? this.tocPage,
    );
  }
}

/// 导出失败时抛出，UI 层转成提示文案。
class ExportException implements Exception {
  ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExportService {
  ExportService._();

  /// PDF 必须内嵌中文字体。PDF 标准 14 字体不含中文字形，
  /// 不内嵌的话导出来是一页方框。
  static const String cjkFontAsset = 'assets/fonts/NotoSansSC-Regular.ttf';
  static pw.Font? _cachedFont;

  static Future<Uint8List> build(
    ExportFormat format,
    List<Entry> entries,
    ExportOptions options,
  ) {
    switch (format) {
      case ExportFormat.txt:
        return Future<Uint8List>.value(_buildTxt(entries, options));
      case ExportFormat.docx:
        return _buildDocx(entries, options);
      case ExportFormat.pdf:
        return _buildPdf(entries, options);
    }
  }

  /// 生成并让用户选择保存位置。返回 null 表示用户取消。
  static Future<String?> save(
    ExportFormat format,
    List<Entry> entries,
    ExportOptions options,
  ) async {
    final Uint8List bytes = await build(format, entries, options);
    final Uri? uri = await FilePicker.saveFile(
      dialogTitle: '导出日记',
      fileName: '日记_${_stamp(entries)}.${format.ext}',
      bytes: bytes,
      mimeType: _mimeOf(format),
    );
    return uri?.toString();
  }

  static String _mimeOf(ExportFormat f) {
    switch (f) {
      case ExportFormat.txt:
        return 'text/plain';
      case ExportFormat.docx:
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }

  /// 整库 JSON 备份，返回保存结果路径，null 表示取消。
  static Future<String?> saveBackupJson(
    List<Entry> entries,
    List<int> bytes,
  ) async {
    final Uri? uri = await FilePicker.saveFile(
      dialogTitle: '导出备份',
      fileName: '日记备份_${entries.length}篇.json',
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/json',
    );
    return uri?.toString();
  }

  static String _stamp(List<Entry> entries) {
    if (entries.isEmpty) return CnDate.ymd(DateTime.now());
    return '${CnDate.ymd(entries.first.date)}_${CnDate.ymd(entries.last.date)}';
  }

  // ---------------------------------------------------------------- TXT

  static Uint8List _buildTxt(List<Entry> entries, ExportOptions o) {
    final StringBuffer sb = StringBuffer()
      ..writeln('我的日记')
      ..writeln('共 ${entries.length} 篇　·　导出于 ${CnDate.cnFull(DateTime.now())}')
      ..writeln('=' * 44);

    for (final Entry e in entries) {
      sb
        ..writeln()
        ..writeln(_metaLine(e, o))
        ..writeln('-' * 44);
      if (e.hasTitle) sb.writeln(e.title.trim());
      if (e.content.trim().isNotEmpty) sb.writeln(e.content.trimRight());
      if (o.includeMeta && e.tags.isNotEmpty) {
        sb
          ..writeln()
          ..writeln('#${e.tags.join('  #')}');
      }
      sb.writeln();
    }
    // BOM：让 Windows 记事本正确识别 UTF-8 中文
    return Uint8List.fromList(utf8.encode('\uFEFF$sb'));
  }

  static String _metaLine(Entry e, ExportOptions o) {
    final StringBuffer sb = StringBuffer()
      ..write(CnDate.cnFull(e.date))
      ..write('  ${CnDate.weekday(e.date)}');
    if (o.includeMeta) {
      final String? w = e.weather;
      final String? m = Moods.label(e.mood);
      if (w != null) sb.write('  $w');
      if (m != null) sb.write('  心情:$m');
      if (e.wordCount > 0) sb.write('  ${e.wordCount}字');
    }
    return sb.toString();
  }

  // --------------------------------------------------------------- DOCX

  static Future<Uint8List> _buildDocx(
    List<Entry> entries,
    ExportOptions o,
  ) async {
    final DocxDocumentBuilder b = DocxDocumentBuilder()
      ..h1('我的日记')
      ..p('共 ${entries.length} 篇　·　导出于 ${CnDate.cnFull(DateTime.now())}')
      ..hr();

    for (final Entry e in entries) {
      b.h2('${CnDate.cnFull(e.date)}　${CnDate.weekday(e.date)}');

      final List<String> meta = _metaParts(e, o);
      if (meta.isNotEmpty) b.p(meta.join('　·　'));

      if (e.hasTitle) {
        b.add(
          DocxParagraph(
            children: <DocxInline>[
              DocxText(
                e.title.trim(),
                fontWeight: DocxFontWeight.bold,
                fontSize: 26,
              ),
            ],
          ),
        );
      }

      for (final String line in _contentLines(e.content)) {
        b.p(line);
      }

      if (o.includeMeta && e.tags.isNotEmpty) b.p('#${e.tags.join('  #')}');
      b.hr();
    }

    return DocxExporter().exportToBytes(b.build());
  }

  // ---------------------------------------------------------------- PDF

  static Future<Uint8List> _buildPdf(
    List<Entry> entries,
    ExportOptions o,
  ) async {
    final pw.Font font = await _loadCjkFont();

    final pw.ThemeData theme =
        pw.ThemeData.withFont(base: font, bold: font, italic: font, boldItalic: font);

    final pw.TextStyle bodyStyle =
        pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 3);
    final pw.TextStyle dateStyle = pw.TextStyle(font: font, fontSize: 15);
    final pw.TextStyle metaStyle = pw.TextStyle(
      font: font,
      fontSize: 9,
      color: PdfColors.grey700,
    );

    final double mm = PdfPageFormat.mm;
    final pw.EdgeInsets margin = pw.EdgeInsets.fromLTRB(20 * mm, 18 * mm, 20 * mm, 18 * mm);

    final pw.Document doc = pw.Document(
      title: '我的日记',
      author: 'date_write',
      theme: theme,
    );

    // 页脚只显示当前页号：pagesCount 是「已生成页数」，
    // 边生成边显示总数会得到错误的 "1/1"。
    pw.Widget footer(pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('第 ${context.pageNumber} 页', style: metaStyle),
        );

    pw.MultiPage page({
      required List<pw.Widget> children,
      pw.Widget? header,
    }) {
      return pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: margin,
        theme: theme,
        maxPages: 999,
        header: header == null ? null : (pw.Context ctx) => header,
        footer: footer,
        build: (pw.Context ctx) => children,
      );
    }

    if (o.coverPage) {
      doc.addPage(
        page(
          children: <pw.Widget>[
            pw.Container(
              height: 640,
              alignment: pw.Alignment.center,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: <pw.Widget>[
                  pw.Text('我的日记', style: pw.TextStyle(font: font, fontSize: 32)),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    '${_rangeText(entries)}　共 ${entries.length} 篇',
                    style: metaStyle,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('导出于 ${CnDate.cnFull(DateTime.now())}', style: metaStyle),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (o.tocPage) {
      doc.addPage(
        page(
          children: <pw.Widget>[
            pw.SizedBox(height: 40),
            pw.Text('目　录', style: pw.TextStyle(font: font, fontSize: 20)),
            pw.SizedBox(height: 16),
            ...entries.map(
              (Entry e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Text(
                  '${CnDate.cnFull(e.date)}　${e.displayTitle}',
                  style: metaStyle,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 每篇单独起一页：各自一个 MultiPage，
    // 单篇超过一页时它内部自己会续页。
    for (final Entry e in entries) {
      final List<pw.Widget> block = <pw.Widget>[
        pw.Text(
          '${CnDate.cnFull(e.date)}　${CnDate.weekday(e.date)}',
          style: dateStyle,
        ),
        pw.SizedBox(height: 4),
      ];

      final List<String> meta = _metaParts(e, o);
      if (meta.isNotEmpty) {
        block
          ..add(pw.Text(meta.join('　·　'), style: metaStyle))
          ..add(pw.SizedBox(height: 4));
      }

      if (e.hasTitle) {
        block
          ..add(pw.SizedBox(height: 6))
          ..add(
            pw.Text(e.title.trim(), style: pw.TextStyle(font: font, fontSize: 12.5)),
          )
          ..add(pw.SizedBox(height: 6));
      }

      for (final String line in _contentLines(e.content)) {
        // 空行用空格占位，否则行距会塌掉
        block.add(pw.Text(line.isEmpty ? ' ' : line, style: bodyStyle));
      }

      if (o.includeMeta && e.tags.isNotEmpty) {
        block
          ..add(pw.SizedBox(height: 8))
          ..add(pw.Text('#${e.tags.join('  #')}', style: metaStyle));
      }

      doc.addPage(
        page(
          children: block,
          header: pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(CnDate.cnMonthDay(e.date), style: metaStyle),
          ),
        ),
      );
    }

    if (entries.isEmpty && !o.coverPage && !o.tocPage) {
      doc.addPage(
        page(
          children: <pw.Widget>[
            pw.Container(
              height: 640,
              alignment: pw.Alignment.center,
              child: pw.Text('没有可导出的日记', style: pw.TextStyle(font: font)),
            ),
          ],
        ),
      );
    }

    return doc.save();
  }

  static String _rangeText(List<Entry> entries) {
    if (entries.isEmpty) return '暂无记录';
    final Entry first = entries.first;
    final Entry last = entries.last;
    if (first.date.year == last.date.year) {
      return '${CnDate.cnMonthDay(first.date)} — ${CnDate.cnMonthDay(last.date)}';
    }
    return '${CnDate.cnFull(first.date)} — ${CnDate.cnFull(last.date)}';
  }

  static Future<pw.Font> _loadCjkFont() async {
    final pw.Font? cached = _cachedFont;
    if (cached != null) return cached;
    try {
      final ByteData data = await rootBundle.load(cjkFontAsset);
      final pw.Font font = pw.Font.ttf(data);
      _cachedFont = font;
      return font;
    } catch (_) {
      throw ExportException(
        '缺少中文字体资源 $cjkFontAsset，PDF 无法显示中文。\n'
        '请把中文字体放到 assets/fonts/ 后重新构建。',
      );
    }
  }

  // ------------------------------------------------------------ 备份 JSON

  /// 整库导出为 JSON，用于备份和换机迁移。
  static Uint8List buildBackupJson(List<Entry> entries) {
    final List<Map<String, Object?>> data =
        entries.map((Entry e) => e.toMap()).toList(growable: false);
    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'app': 'date_write',
          'schema': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'count': data.length,
          'entries': data,
        }),
      ),
    );
  }

  // ---------------------------------------------------------------- 内部

  static List<String> _metaParts(Entry e, ExportOptions o) {
    if (!o.includeMeta) return const <String>[];
    final List<String> parts = <String>[];
    if (e.weather != null) parts.add('天气 ${e.weather}');
    if (Moods.label(e.mood) != null) parts.add('心情 ${Moods.label(e.mood)}');
    if (e.wordCount > 0) parts.add('${e.wordCount} 字');
    return parts;
  }

  /// 保留用户原始换行，只去掉首尾多余空行
  static List<String> _contentLines(String content) {
    final List<String> raw = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    while (raw.isNotEmpty && raw.first.trim().isEmpty) {
      raw.removeAt(0);
    }
    while (raw.isNotEmpty && raw.last.trim().isEmpty) {
      raw.removeLast();
    }
    return raw;
  }
}