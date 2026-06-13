import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  AppInfoService._();

  static PackageInfo? _packageInfo;

  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static String get version => _packageInfo?.version ?? '0.0.0';

  static String get buildNumber => _packageInfo?.buildNumber ?? '0';

  static String get appName => _packageInfo?.appName ?? 'Asset Management';

  static String get packageName => _packageInfo?.packageName ?? '';

  static String get fullVersion => '$version ($buildNumber)';
}