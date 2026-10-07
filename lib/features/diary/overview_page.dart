import 'package:flutter/material.dart';

import '../../core/cn_date.dart';
import '../../data/entry_repo.dart';
import '../../data/models/entry.dart';
import 'detail_page.dart';

/// 总览：一屏看完全部写过的日记。
///
/// 列表页一次只看一个月，这里把跨年份、跨月份的内容全部摊开，
/// 并按「年 → 月 → 篇」三级分组，配一个全局搜索。
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  List<Entry> _all = <Entry>[];
  String _keyword = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final List<Entry> entries = await EntryRepo.all();
    if (!mounted) return;
    setState(() {
      _all = entries;
      _loading = false;
    });
  }

  /// 把结果摊平成「分组标题 + 条目」的一维列表，交给 ListView.builder
  List<_Row> _buildRows(List<Entry> entries) {
    final List<_Row> rows = <_Row>[];
    int? curYear;
    int? curMonth;
    for (final Entry e in entries) {
      final int y = e.date.year;
      if (y != curYear) {
        curYear = y;
        curMonth = null;
        rows.add(_Row.yearHeader(y, _countOf(entries, year: y)));
      }
      if (e.date.month != curMonth) {
        final int m = e.date.month;
        curMonth = m;
        rows.add(_Row.monthHeader(y, m, _countOf(entries, year: y, month: m)));
      }
      rows.add(_Row.entry(e));
    }
    return rows;
  }

  int _countOf(List<Entry> entries, {int? year, int? month}) {
    return entries.where((Entry e) {
      if (year != null && e.date.year != year) return false;
      if (month != null && e.date.month != month) return false;
      return true;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final String kw = _keyword.trim();
    final List<Entry> shown = kw.isEmpty
        ? _all
        : _all
            .where((Entry e) =>
                e.title.contains(kw) ||
                e.content.contains(kw) ||
                e.tags.any((String t) => t.contains(kw)))
            .toList();

    final List<_Row> rows = _buildRows(shown);
    int words = 0;
    for (final Entry e in shown) {
      words += e.wordCount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('总览'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (String v) => setState(() => _keyword = v),
              decoration: InputDecoration(
                hintText: '搜索全部日记',
                prefixIcon: const Icon(Icons.search, size: 19),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _keyword = ''),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      kw.isEmpty ? '还没有写过日记' : '没有匹配「$kw」的日记',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${shown.length} 篇',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            '　·　$words 字',
                            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                          ),
                          if (kw.isNotEmpty) ...<Widget>[
                            Text('　·　筛选中',
                                style: TextStyle(fontSize: 12.5, color: cs.primary)),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: rows.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final _Row r = rows[i];
                          if (r.kind == _RowKind.yearHeader) {
                            return _yearHeader(ctx, r);
                          }
                          if (r.kind == _RowKind.monthHeader) {
                            return _monthHeader(ctx, r);
                          }
                          return _entryTile(ctx, r.entry!);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _yearHeader(BuildContext ctx, _Row r) {
    final ColorScheme cs = Theme.of(ctx).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.onSurface.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        '${r.year} 年　·　${r.count} 篇',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _monthHeader(BuildContext ctx, _Row r) {
    final ColorScheme cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.calendar_today, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '${r.year}年${r.month}月',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text('${r.count} 篇',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: Theme.of(ctx).dividerColor)),
        ],
      ),
    );
  }

  Widget _entryTile(BuildContext ctx, Entry e) {
    final ColorScheme cs = Theme.of(ctx).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      leading: SizedBox(
        width: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${e.date.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: cs.onSurface,
              ),
            ),
            Text(
              CnDate.weekdayShort(e.date),
              style: TextStyle(fontSize: 10.5, height: 1.4, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      title: Text(
        e.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: e.hasTitle ? cs.onSurface : cs.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        e.summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
      ),
      trailing: Moods.face(e.mood) == null
          ? Text('${e.wordCount} 字',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
          : Text(Moods.face(e.mood)!,
              style: const TextStyle(fontSize: 14)),
      onTap: () async {
        await EntryDetailView.open(ctx, e);
        if (mounted) reload();
      },
    );
  }
}

enum _RowKind { yearHeader, monthHeader, entry }

class _Row {
  _Row.yearHeader(this.year, this.count)
      : month = 0,
        entry = null,
        kind = _RowKind.yearHeader;

  _Row.monthHeader(this.year, this.month, this.count)
      : entry = null,
        kind = _RowKind.monthHeader;

  _Row.entry(this.entry)
      : year = 0,
        month = 0,
        count = 0,
        kind = _RowKind.entry;

  final _RowKind kind;
  final int year;
  final int month;
  final int count;
  final Entry? entry;
}