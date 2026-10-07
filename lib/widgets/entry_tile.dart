import 'package:flutter/material.dart';

import '../core/cn_date.dart';
import '../data/models/entry.dart';
import '../data/tag_scope.dart';

/// 时间线上的一篇日记。
///
/// 左侧固定日期轴，右侧卡片；卡片高度约 84~100px，
/// 保证一屏能看 4~5 条——信息密度够，但不至于挤成一坨。
class EntryTimelineTile extends StatelessWidget {
  const EntryTimelineTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    this.isFirst = false,
    this.isLast = false,
    this.showDate = true,
  });

  final Entry entry;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;
  final bool isFirst;
  final bool isLast;
  final bool showDate;

  static const double _gutter = 52;
  static const double _dotCenterX = _gutter / 2;
  static const double _dotTop = 15;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
    );

    return Dismissible(
      key: ValueKey<int?>(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: cs.errorContainer,
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Stack(
            children: <Widget>[
              // 连接线用 Positioned 拉伸，避免 IntrinsicHeight 的开销
              if (!isLast)
                Positioned(
                  left: _dotCenterX - 0.5,
                  top: isFirst ? _dotTop : 0,
                  bottom: 10,
                  width: 1,
                  child: ColoredBox(color: theme.dividerColor),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: _gutter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: _dotTop - 4),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: dot,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: showDate ? _withDate(theme, cs) : _card(theme, cs),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withDate(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            children: <Widget>[
              Text(
                CnDate.friendly(entry.date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CnDate.weekday(entry.date),
                style: TextStyle(fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _card(theme, cs),
      ],
    );
  }

  Widget _card(ThemeData theme, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              entry.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: entry.hasTitle ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              entry.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                if (Moods.face(entry.mood) != null) ...<Widget>[
                  Text(Moods.face(entry.mood)!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                ],
                if (entry.weather != null)
                  Text(_weatherIcon(entry.weather!),
                      style: const TextStyle(fontSize: 12)),
                if (entry.weather != null) const SizedBox(width: 8),
                Text(
                  '${entry.wordCount} 字',
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                ...entry.tags.take(2).map(
                      (String t) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _TagChip(tag: t),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _weatherIcon(String name) {
    final int i = Weathers.names.indexOf(name);
    if (i >= 0 && i < Weathers.icons.length) return Weathers.icons[i];
    return name;
  }
}

/// 带颜色的标签 chip。颜色由 [TagScope] 从 tag 表取，未登记时回落到主色。
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final Color base = TagScope.chipColor(context, tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 11, height: 1.5, color: base),
      ),
    );
  }
}

/// 列表为空时的占位：一行说明 + 一个明确的下一步。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: cs.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: cs.onSurfaceVariant),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}