import 'package:flutter/material.dart';

import '../../data/entry_repo.dart';
import '../../services/export_service.dart';

/// 导出页：先选格式和选项，再生成文件。
class ExportPage extends StatefulWidget {
  const ExportPage({super.key, this.compact = false});

  /// true 时不套 Scaffold，供“我的”页内嵌显示
  final bool compact;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  ExportOptions _options = const ExportOptions();
  int _count = 0;
  int _trashCount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<dynamic> all = await EntryRepo.all();
    final int deleted = await EntryRepo.countDeleted();
    if (!mounted) return;
    setState(() {
      _count = all.length;
      _trashCount = deleted;
    });
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String? path = await action();
      if (!mounted) return;
      if (path == null) {
        _toast('已取消导出');
      } else {
        _toast('已保存到\n$path', long: true);
      }
    } on ExportException catch (e) {
      if (mounted) _toast(e.message, long: true);
    } catch (e) {
      if (mounted) _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, {bool long = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: long
            ? SelectableText(message, style: const TextStyle(fontSize: 12))
            : Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _export(ExportFormat f) async {
    await _run(() async {
      final entries = await EntryRepo.all();
      if (entries.isEmpty) throw ExportException('还没有可以导出的日记');
      return ExportService.save(f, entries, _options);
    });
  }

  Future<void> _backup() async {
    await _run(() async {
      final entries = await EntryRepo.all();
      return ExportService.saveBackupJson(
        entries,
        ExportService.buildBackupJson(entries),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: <Widget>[
        Text(
          '当前共 $_count 篇日记${_trashCount > 0 ? '，回收站还有 $_trashCount 篇' : ''}',
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _sectionLabel('导出格式'),
        const SizedBox(height: 8),
        ...ExportFormat.values.map(
          (ExportFormat f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Icon(f.icon),
                title: Text(f.label),
                subtitle: Text(f.hint),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _export(f),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('导出内容'),
        SwitchListTile(
          value: _options.includeMeta,
          onChanged: (bool v) =>
              setState(() => _options = _options.copyWith(includeMeta: v)),
          title: const Text('包含心情、天气和标签', style: TextStyle(fontSize: 14)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 18),
        _sectionLabel('PDF 版式'),
        const SizedBox(height: 4),
        SwitchListTile(
          value: _options.coverPage,
          onChanged: (bool v) =>
              setState(() => _options = _options.copyWith(coverPage: v)),
          title: const Text('封面页', style: TextStyle(fontSize: 14)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: _options.tocPage,
          onChanged: (bool v) =>
              setState(() => _options = _options.copyWith(tocPage: v)),
          title: const Text('目录页', style: TextStyle(fontSize: 14)),
          subtitle: const Text('按时间倒序列出所有日记标题', style: TextStyle(fontSize: 11.5)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 20),
        _sectionLabel('备份'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('导出整库 JSON'),
            subtitle: const Text('用于换机迁移或本地备份', style: TextStyle(fontSize: 11.5)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _backup,
          ),
        ),
        if (_busy) ...<Widget>[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );

    if (widget.compact) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('导出日记')),
      body: body,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}