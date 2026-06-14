import 'package:package_info_plus/package_info_plus.dart';
import 'package:asset_management/version.dart';

class AppInfoService {
  AppInfoService._();

  static PackageInfo? _packageInfo;

  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static String get version => AppVersion.version;

  static String get appName => _packageInfo?.appName ?? 'Asset Management';

  static String get packageName => _packageInfo?.packageName ?? '';

  static String get fullVersion => AppVersion.fullVersion;
}