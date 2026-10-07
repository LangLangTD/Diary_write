import 'package:flutter/material.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'db.dart';

/// 设置项存进数据库的 `app_setting` 表，省掉一个偏好存储依赖。
class KvStore {
  KvStore._();

  static Future<String?> get(String key) async {
    final Database db = await AppDb.instance;
    final List<Map<String, Object?>> rows = await db.query(
      'app_setting',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static Future<void> set(String key, String value) async {
    final Database db = await AppDb.instance;
    await db.insert(
      'app_setting',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// 全局可变的应用设置。改动后通过 [AppScope] 广播给 widget 树。
class AppSettings extends ChangeNotifier {
  AppSettings({required this.themeMode, required this.fontScale});

  ThemeMode themeMode;
  double fontScale;

  static const String _kTheme = 'theme_mode';
  static const String _kFont = 'font_scale';

  static Future<AppSettings> load() async {
    final String? theme = await KvStore.get(_kTheme);
    final String? font = await KvStore.get(_kFont);
    return AppSettings(
      themeMode: _decodeTheme(theme),
      fontScale: double.tryParse(font ?? '') ?? 1.0,
    );
  }

  static ThemeMode _decodeTheme(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _encodeTheme(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static String themeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    if (m == themeMode) return;
    themeMode = m;
    notifyListeners();
    await KvStore.set(_kTheme, _encodeTheme(m));
  }

  Future<void> setFontScale(double v) async {
    final double clamped = v.clamp(0.85, 1.35);
    if ((clamped - fontScale).abs() < 0.001) return;
    fontScale = clamped;
    notifyListeners();
    await KvStore.set(_kFont, clamped.toStringAsFixed(2));
  }
}

/// 把 [AppSettings] 注入 widget 树。
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 不在 widget 树中');
    return scope!.notifier!;
  }
}