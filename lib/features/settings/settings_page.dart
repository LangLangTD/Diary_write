import 'package:flutter/material.dart';

import '../../data/app_settings.dart';
import '../../data/entry_repo.dart';
import '../../data/tag_repo.dart';
import '../../data/tag_scope.dart';
import '../diary/overview_page.dart';
import '../diary/trash_page.dart';
import 'export_page.dart';
import 'restore_page.dart';

/// 标签管理：改颜色、改名、清理没用过的标签。
class TagManagerPage extends StatefulWidget {
  const TagManagerPage({super.key});

  @override
  State<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends State<TagManagerPage> {
  List<TagInfo> _tags = <TagInfo>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);
    final List<TagInfo> tags = await TagRepo.all();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _loading = false;
    });
  }

  Future<void> _rename(TagInfo tag) async {
    final TagPaletteNotifier palette = TagScope.of(context);
    final TextEditingController ctl = TextEditingController(text: tag.name);
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标签名'),
          onSubmitted: (String v) => Navigator.of(ctx).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (next == null || next.trim().isEmpty || next.trim() == tag.name) return;
    await TagRepo.rename(tag.name, next.trim());
    await reload();
    await palette.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: <Widget>[
          if (_tags.any((TagInfo t) => t.usage == 0))
            TextButton(
              onPressed: () async {
                // 先把 notifier 取出来，await 之后再碰 context 不安全
                final TagPaletteNotifier palette = TagScope.of(context);
                await TagRepo.pruneUnused();
                await reload();
                await palette.reload();
              },
              child: const Text('清理未使用'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const Center(child: Text('还没有标签。在写日记时用逗号分隔就能加标签'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _tags.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext ctx, int i) {
                    final TagInfo tag = _tags[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(tag.color),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      title: Text(tag.name),
                      subtitle: Text('${tag.usage} 篇', style: const TextStyle(fontSize: 11.5)),
                      trailing: PopupMenuButton<String>(
                        tooltip: '操作',
                        onSelected: (String v) async {
                          if (v == 'rename') {
                            await _rename(tag);
                          } else if (v == 'color') {
                            await _pickColor(tag);
                          }
                        },
                        itemBuilder: (BuildContext c) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'color',
                            child: Text('换个颜色'),
                          ),
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('重命名'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _tags.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _pickColor(_tags.first),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('调色'),
            ),
    );
  }

  Future<void> _pickColor(TagInfo tag) async {
    final TagPaletteNotifier palette = TagScope.of(context);
    int selected = tag.color;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('「${tag.name}」的颜色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: TagRepo.paletteForUi.map((int c) {
            return GestureDetector(
              onTap: () {
                selected = c;
                Navigator.of(ctx).pop();
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: c == selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (selected == tag.color) return;
    await TagRepo.setColor(tag.name, selected);
    await reload();
    await palette.reload();
  }
}

/// 「我的」页。窄屏作为第二个 Tab，宽屏作为侧栏第二项。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  DiaryStats? _stats;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final DiaryStats s = await EntryRepo.stats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppSettings settings = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: <Widget>[
        _label(cs, '概览'),
        const SizedBox(height: 8),
        _statsCard(cs),
        const SizedBox(height: 24),
        _label(cs, '外观'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('主题', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: ThemeMode.values
                      .map(
                        (ThemeMode m) => ButtonSegment<ThemeMode>(
                          value: m,
                          label: Text(AppSettings.themeLabel(m), style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  selected: <ThemeMode>{settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<ThemeMode> v) => settings.setThemeMode(v.first),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Text('正文字号', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                    const Spacer(),
                    Text(
                      '${(settings.fontScale * 100).round()}%',
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Slider(
                  value: settings.fontScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 10,
                  label: '${(settings.fontScale * 100).round()}%',
                  onChanged: (double v) => settings.setFontScale(v),
                ),
                const SizedBox(height: 4),
                Text(
                  '预览：今天天气不错，写了点东西。',
                  style: TextStyle(
                    fontSize: 16 * settings.fontScale,
                    height: 1.75,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _label(cs, '内容'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: <Widget>[
              _tile(
                icon: Icons.list_alt_outlined,
                title: '总览',
                subtitle: '按年 / 月查看全部日记',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const OverviewPage()),
                  );
                  await reload();
                },
              ),
              const Divider(height: 1, indent: 56),
              _tile(
                icon: Icons.sell_outlined,
                title: '标签管理',
                subtitle: '给标签配颜色、改名',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TagManagerPage()),
                  );
                  await reload();
                },
              ),
              const Divider(height: 1, indent: 56),
              _tile(
                icon: Icons.delete_outline,
                title: '回收站',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TrashPage()),
                  );
                  await reload();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label(cs, '数据'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: <Widget>[
              _tile(
                icon: Icons.ios_share,
                title: '导出日记',
                subtitle: 'TXT / Word / PDF',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ExportPage()),
                  );
                  await reload();
                },
              ),
              const Divider(height: 1, indent: 56),
              _tile(
                icon: Icons.restore,
                title: '从备份恢复',
                subtitle: '选择之前导出的 JSON',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RestorePage()),
                  );
                  await reload();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label(cs, '关于'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: <Widget>[
                Icon(Icons.auto_stories, color: cs.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('日记本', style: TextStyle(fontSize: 14, color: cs.onSurface)),
                      const SizedBox(height: 3),
                      Text(
                        '本地存储，数据只在这台设备上',
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Future<void> Function() onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 11.5)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _statsCard(ColorScheme cs) {
    final DiaryStats? s = _stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: <Widget>[
            _stat(cs, '${s?.totalEntries ?? 0}', '篇日记'),
            _divider(cs),
            _stat(cs, _formatWords(s?.totalWords ?? 0), '总字数'),
            _divider(cs),
            _stat(cs, '${s?.streak ?? 0}', '连续天数'),
            _divider(cs),
            _stat(cs, '${s?.writtenDays ?? 0}', '记录天数'),
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Container(
        width: 1,
        height: 30,
        color: Theme.of(context).dividerColor,
      );

  Widget _stat(ColorScheme cs, String value, String label) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  static String _formatWords(int n) {
    if (n < 10000) return '$n';
    return '${(n / 10000).toStringAsFixed(1)}万';
  }

  Widget _label(ColorScheme cs, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: cs.onSurfaceVariant,
        ),
      );
}