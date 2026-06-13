import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/i18n/translations.dart';
import 'services/backup_scheduler.dart';
import 'ui/providers/theme_provider.dart';
import 'ui/pages/home/home_page.dart';

/// Asset Management App 入口 Widget
class AssetManagementApp extends ConsumerStatefulWidget {
  const AssetManagementApp({super.key});

  @override
  ConsumerState<AssetManagementApp> createState() => _AssetManagementAppState();
}

class _AssetManagementAppState extends ConsumerState<AssetManagementApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App 从后台恢复时检查自动备份
      BackupScheduler.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 等待主题 + 语言初始化完成
    ref.watch(themeInitProvider);
    ref.watch(localeInitProvider);

    final loc = ref.watch(localeCodeProvider);
    final themePair = ref.watch(appThemeProvider);

    // 根据当前明暗模式设置状态栏
    final isDark = themePair.mode == ThemeMode.dark ||
        (themePair.mode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'Asset Management',
      debugShowCheckedModeBanner: false,

      // 动态主题
      theme: themePair.light,
      darkTheme: themePair.dark,
      themeMode: themePair.mode,

      // 本地化支持
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh'),
        Locale('en', 'US'),
        Locale('en'),
      ],
      locale: Locale(loc),

      // 首页
      home: const HomePage(),
    );
  }
}
