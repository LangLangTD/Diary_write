import 'package:flutter/material.dart';

/// 视觉基调：暖白纸感 + 低饱和赤陶主色。
///
/// 设计原则是「每屏都要有信息」，因此行高、字距、卡片密度都偏紧凑，
/// 留白只留给长文阅读，不用于撑画面。
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFFC77B4A);
  static const Color paperLight = Color(0xFFFAF8F5);
  static const Color paperDark = Color(0xFF141311);

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light)
            .copyWith(surface: Colors.white),
        paperLight,
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark).copyWith(
          surface: const Color(0xFF1E1C1A),
        ),
        paperDark,
      );

  static ThemeData _build(ColorScheme scheme, Color background) {
    final bool isLight = scheme.brightness == Brightness.light;
    // 浅色下页面底是暖白、卡片是纯白，边框要够明显才分得开两块区域
    final Color border =
        isLight ? const Color(0x1F1A1512) : const Color(0x24FFFFFF);
    final Color subtle =
        isLight ? const Color(0x8A3A332C) : const Color(0xB3D8D2CB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: scheme.surface,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 52,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity(horizontal: 0, vertical: -2),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? const Color(0xFFF3F0EB) : const Color(0xFF26231F),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.24),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.24),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: subtle,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  /// 正文排版参数（阅读页用）。[scale] 为全局字号缩放。
  static TextStyle body(BuildContext context, {double scale = 1.0}) {
    return TextStyle(
      fontSize: 16 * scale,
      height: 1.75,
      color: Theme.of(context).colorScheme.onSurface,
      letterSpacing: 0.1,
    );
  }
}