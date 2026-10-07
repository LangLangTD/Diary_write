import 'package:flutter/material.dart';

import '../../data/entry_repo.dart';
import '../../services/backup_service.dart';

/// 从 JSON 备份恢复。
///
/// 流程刻意做成「先看清再写入」：选文件 → 展示篇数与时间范围 → 选合并或覆盖，
/// 避免误点就把现有日记冲掉。
class RestorePage extends StatefulWidget {
  const RestorePage({super.key});

  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final BackupPreview? p = await BackupService.pick();
      if (!mounted) return;
      if (p == null) return;
      await _confirm(p);
    } on BackupException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('读取失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(BackupPreview p) async {
    final ImportMode? mode = await showDialog<ImportMode>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('选择恢复方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${p.sourceName}：${p.count} 篇，${p.rangeText}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            const Text('合并', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              '只补充本地没有的日期，已有日记保持不动。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            const Text('覆盖', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            const SizedBox(height: 4),
            const Text(
              '先清空本地全部日记，再写入备份里的内容。不可撤销。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ImportMode.merge),
            child: const Text('合并'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ImportMode.replace),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;

    setState(() => _busy = true);
    final int written = await EntryRepo.importEntries(p.entries, mode);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast('已恢复 $written 篇${mode == ImportMode.merge ? '（跳过已有日期）' : ''}');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('从备份恢复')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '备份文件是「我的 → 导出日记 → 导出整库 JSON」生成的那个文件。',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '换手机、换电脑，或者误删之后想找回，都可以靠它。',
                    style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(_busy ? '处理中…' : '选择备份文件'),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}