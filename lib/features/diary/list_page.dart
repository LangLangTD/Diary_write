import 'package:flutter/material.dart';

import '../../core/cn_date.dart';
import '../../data/entry_repo.dart';
import '../../data/models/entry.dart';
import '../../widgets/entry_tile.dart';
import 'overview_page.dart';

/// 日记列表页。
///
/// 布局刻意做得「密」：顶栏、统计条、筛选条、列表一屏排满，
/// 避免大片留白显得空旷。
class DiaryListPage extends StatefulWidget {
  const DiaryListPage({super.key, required this.onOpenEntry, this.selectedId});

  final ValueChanged<Entry> onOpenEntry;
  final int? selectedId;

  @override
  State<DiaryListPage> createState() => DiaryListPageState();
}

class DiaryListPageState extends State<DiaryListPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Entry> _entries = <Entry>[];
  List<String> _tags = <String>[];
  bool _loading = true;
  bool _searching = false;
  String _keyword = '';
  String? _tagFilter;

  bool get _filtering =>
      _keyword.trim().isNotEmpty || (_tagFilter != null && _tagFilter!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);

    // 有筛选条件时跨月份搜索，否则只看当前月
    final EntryQuery q = _filtering
        ? EntryQuery(keyword: _keyword, tag: _tagFilter)
        : EntryQuery(month: _month);
    final List<Entry> entries = await EntryRepo.query(q);
    final List<String> tags = await EntryRepo.allTags();

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _tags = tags;
      _loading = false;
      // 当前筛选的标签可能已经被删掉了
      if (_tagFilter != null && !tags.contains(_tagFilter)) _tagFilter = null;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _keyword = '';
      _tagFilter = null;
      _searching = false;
    });
    reload();
  }

  bool get _canGoForward {
    final DateTime now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  Future<bool> _confirmDelete(Entry e) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('移到回收站？'),
        content: Text('「${e.displayTitle}」会进入回收站，30 天后自动清除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移到回收站'),
          ),
        ],
      ),
    );
    if (ok != true || e.id == null) return false;
    await EntryRepo.softDelete(e.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${e.displayTitle}」已移到回收站'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => EntryRepo.restore(e.id!),
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _writeToday() async {
    final Entry draft = Entry.draft();
    final int id = await EntryRepo.insert(draft);
    await reload();
    if (!mounted) return;
    widget.onOpenEntry(draft.copyWith(id: id));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        _header(cs),
        _summaryStrip(),
        if (_searching || _tags.isNotEmpty) _filterBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildList(),
        ),
      ],
    );
  }

  Widget _header(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '上个月',
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickMonth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _filtering ? '全部月份' : CnDate.cnMonth(_month),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    _filtering ? '搜索结果' : '${CnDate.dayOnly(DateTime.now()).year} 年',
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _canGoForward ? '下个月' : '已经是本月',
            onPressed: _canGoForward ? () => _shiftMonth(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: '总览：看全部日记',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const OverviewPage()),
              );
              reload();
            },
            icon: const Icon(Icons.list_alt_outlined),
          ),
          IconButton(
            tooltip: '搜索',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _keyword = '';
            }),
            icon: Icon(_searching ? Icons.search_off : Icons.search),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '跳转到',
    );
    if (picked == null || !mounted) return;
    setState(() => _month = DateTime(picked.year, picked.month));
    reload();
  }

  Widget _summaryStrip() {
    if (_entries.isEmpty) return const SizedBox(height: 6);
    int words = 0;
    for (final Entry e in _entries) {
      words += e.wordCount;
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        '${_entries.length} 篇　·　$words 字',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _filterBar() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              autofocus: true,
              onChanged: (String v) {
                _keyword = v;
                reload();
              },
              decoration: InputDecoration(
                hintText: '搜索标题、正文或标签',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() => _keyword = '');
                          reload();
                        },
                      ),
              ),
            ),
          ),
        if (_tags.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: <Widget>[
                _tagChip(cs, null, '全部'),
                ..._tags.map((String t) => _tagChip(cs, t, '#$t')),
              ],
            ),
          ),
        if (_tags.isNotEmpty) const SizedBox(height: 8),
      ],
    );
  }

  Widget _tagChip(ColorScheme cs, String? value, String label) {
    final bool selected = _tagFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
        onSelected: (_) {
          setState(() => _tagFilter = value);
          reload();
        },
      ),
    );
  }

  Widget _buildList() {
    if (_entries.isEmpty) {
      return EmptyState(
        icon: _filtering ? Icons.search_off : Icons.auto_stories_outlined,
        title: _filtering ? '没有匹配的日记' : '这个月还没有日记',
        subtitle: _filtering
            ? '换个关键词或标签试试'
            : '写点什么吧，哪怕只有一句话。',
        action: _filtering
            ? TextButton(
                onPressed: () {
                  setState(() {
                    _keyword = '';
                    _tagFilter = null;
                  });
                  reload();
                },
                child: const Text('清除筛选'),
              )
            : OutlinedButton.icon(
                onPressed: _writeToday,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('写今天的'),
              ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: _entries.length,
      itemBuilder: (BuildContext context, int i) {
        final Entry e = _entries[i];
        return EntryTimelineTile(
          entry: e,
          isFirst: i == 0,
          isLast: i == _entries.length - 1,
          showDate: !_filtering,
          onTap: () => widget.onOpenEntry(e),
          onDelete: () => _confirmDelete(e),
        );
      },
    );
  }
}