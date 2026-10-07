import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/app_settings.dart';
import 'data/entry_repo.dart';
import 'features/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppSettings settings = await AppSettings.load();

  // 启动时顺手清理回收站里超过 30 天的记录
  await EntryRepo.purgeOlderThan();

  runApp(AppScope(settings: settings, child: const DateWriteApp()));
}

class DateWriteApp extends StatelessWidget {
  const DateWriteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = AppScope.of(context);

    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: '日记本',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const <Locale>[Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomePage(),
        );
      },
    );
  }
}