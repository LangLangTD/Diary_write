import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/cn_date.dart';
import '../../data/entry_repo.dart';
import '../../data/models/entry.dart';
import '../../data/tag_scope.dart';
import 'edit_page.dart';

/// 阅读视图。窄窗口作为独立页面，宽窗口嵌在右侧栏。
class EntryDetailView extends StatelessWidget {
  const EntryDetailView({
    super.key,
    required this.entry,
    this.scale = 1.0,
    this.onEdit,
    this.onChanged,
  });

  final Entry entry;
  final double scale;
  final VoidCallback? onEdit;
  final ValueChanged<Entry>? onChanged;

  static Future<void> open(BuildContext context, Entry entry) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => EntryDetailPage(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      child: Center(
        // 正文最大行宽约 42 个汉字，再宽就很难读了
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _dateRow(context, cs),
              const SizedBox(height: 10),
              if (entry.hasTitle)
                Text(
                  entry.title.trim(),
                  style: TextStyle(
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: cs.onSurface,
                  ),
                ),
              const SizedBox(height: 12),
              _metaRow(context, cs),
              const SizedBox(height: 18),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              const SizedBox(height: 18),
              // 正文按 Markdown 渲染；写的时候不用管语法，纯文本也能正常显示
              MarkdownBody(
                data: entry.content,
                selectable: true,
                shrinkWrap: true,
                fitContent: false,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 16 * scale,
                    height: 1.75,
                    color: cs.onSurface,
                  ),
                  listBullet: TextStyle(color: cs.primary),
                  blockquoteDecoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquote: TextStyle(
                    fontSize: 15 * scale,
                    height: 1.7,
                    color: cs.onSurfaceVariant,
                  ),
                  code: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14 * scale,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                  ),
                  h1: TextStyle(fontSize: 21 * scale, fontWeight: FontWeight.w700, height: 1.5),
                  h2: TextStyle(fontSize: 19 * scale, fontWeight: FontWeight.w700, height: 1.5),
                  h3: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w600, height: 1.5),
                ),
              ),
              const SizedBox(height: 30),
              _footer(context, cs),
              if (onEdit != null) ...<Widget>[
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('编辑这篇'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateRow(BuildContext context, ColorScheme cs) {
    return Row(
      children: <Widget>[
        Text(
          CnDate.cnFull(entry.date),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          CnDate.weekday(entry.date),
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _metaRow(BuildContext context, ColorScheme cs) {
    final List<Widget> chips = <Widget>[];
    final String? face = Moods.face(entry.mood);
    if (face != null) chips.add(_chip(context, face, Moods.label(entry.mood) ?? ''));
    if (entry.weather != null) {
      chips.add(_chip(context, _weatherIcon(entry.weather!), entry.weather!));
    }
    if (entry.wordCount > 0) chips.add(_chip(context, null, '${entry.wordCount} 字'));
    for (final String t in entry.tags) {
      chips.add(_tagChip(context, t));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(BuildContext context, String? icon, String label) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(BuildContext context, String tag) {
    final Color base = TagScope.chipColor(context, tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(fontSize: 12, height: 1.5, color: base),
      ),
    );
  }

  Widget _footer(BuildContext context, ColorScheme cs) {
    final bool edited = entry.updatedAt.millisecondsSinceEpoch -
            entry.createdAt.millisecondsSinceEpoch >
        10000;
    return Row(
      children: <Widget>[
        Text(
          '创建于 ${CnDate.cnFull(entry.createdAt)}',
          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
        ),
        if (edited) ...<Widget>[
          const SizedBox(width: 14),
          Text(
            '编辑于 ${CnDate.cnMonthDay(entry.updatedAt)}',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  static String _weatherIcon(String name) {
    final int i = Weathers.names.indexOf(name);
    if (i >= 0 && i < Weathers.icons.length) return Weathers.icons[i];
    return name;
  }
}

/// 独立页面形态（窄窗口）。
class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.entry, this.scale = 1.0});

  final Entry entry;
  final double scale;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late Entry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _edit() async {
    final Entry? saved = await EntryEditPage.open(context, entry: _entry);
    if (saved != null && mounted) setState(() => _entry = saved);
  }

  Future<void> _confirmDelete() async {
    final int? id = _entry.id;
    if (id == null) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('移到回收站？'),
        content: Text('「${_entry.displayTitle}」会进入回收站，30 天后自动清除。'),
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
    if (ok != true) return;
    await EntryRepo.softDelete(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(CnDate.friendly(_entry.date)),
        actions: <Widget>[
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (String v) {
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_outline, size: 19, color: cs.error),
                    const SizedBox(width: 10),
                    const Text('移到回收站'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: EntryDetailView(
        entry: _entry,
        scale: widget.scale,
      ),
    );
  }
}