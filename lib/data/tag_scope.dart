import 'package:flutter/material.dart';

import 'tag_repo.dart';

/// 标签配色的全局提供者。
///
/// 颜色存在 tag 表里，这里只是一层缓存；新增或改名标签后调用 [reload] 即可。
class TagPaletteNotifier extends ChangeNotifier {
  Map<String, int> _colors = <String, int>{};

  Map<String, int> get colors => _colors;

  Future<void> reload() async {
    _colors = await TagRepo.colorMap();
    notifyListeners();
  }

  /// 取标签颜色；没登记过就返回一个稳定的兜底色
  Color colorOf(String name, Color fallback) {
    final int? raw = _colors[name];
    if (raw != null) return Color(raw);
    return fallback;
  }
}

class TagScope extends InheritedNotifier<TagPaletteNotifier> {
  const TagScope({
    super.key,
    required TagPaletteNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static TagPaletteNotifier of(BuildContext context) {
    final TagScope? scope = context.dependOnInheritedWidgetOfExactType<TagScope>();
    return scope!.notifier!;
  }

  /// 标签 chip 的统一取色（没登记时用主色的淡色）
  static Color chipColor(BuildContext context, String tag) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TagScope.of(context).colorOf(tag, cs.primary);
  }
}