import 'package:flutter/material.dart';

import '../../core/cn_date.dart';
import '../../data/entry_repo.dart';
import '../../data/models/entry.dart';
import '../../widgets/entry_tile.dart';

/// 回收站。个人应用最大的风险不是功能缺失，是误删且找不回来。
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => TrashPageState();
}

class TrashPageState extends State<TrashPage> {
  List<Entry> _entries = <Entry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);
    final List<Entry> items = await EntryRepo.query(
      const EntryQuery(includeDeleted: true),
    );
    if (!mounted) return;
    setState(() {
      _entries = items;
      _loading = false;
    });
  }

  Future<void> _restore(Entry e) async {
    if (e.id == null) return;
    await EntryRepo.restore(e.id!);
    await reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${e.displayTitle}」已恢复')),
      );
    }
  }

  Future<void> _purgeAll() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清空回收站？'),
        content: const Text('这些日记会被彻底删除，无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EntryRepo.hardDeleteAll(
      _entries.map((Entry e) => e.id!).where((int id) => id > 0).toList(),
    );
    await reload();
  }

  Future<void> _purgeOne(Entry e) async {
    if (e.id == null) return;
    await EntryRepo.hardDelete(e.id!);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: <Widget>[
          if (_entries.isNotEmpty)
            TextButton(
              onPressed: _purgeAll,
              child: Text('清空', style: TextStyle(color: cs.error)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline,
                  title: '回收站是空的',
                  subtitle: '删掉的日记会先放到这里，30 天后自动清除。',
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Text(
                        '${_entries.length} 篇待清除',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _entries.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (BuildContext ctx, int i) {
                          final Entry e = _entries[i];
                          return ListTile(
                            title: Text(
                              e.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${CnDate.cnFull(e.date)}　${e.wordCount} 字',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: '恢复',
                                  icon: const Icon(Icons.restore, size: 20),
                                  onPressed: () => _restore(e),
                                ),
                                IconButton(
                                  tooltip: '彻底删除',
                                  icon: Icon(
                                    Icons.delete_forever,
                                    size: 20,
                                    color: cs.error,
                                  ),
                                  onPressed: () => _purgeOne(e),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}