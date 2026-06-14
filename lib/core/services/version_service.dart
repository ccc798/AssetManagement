import 'dart:io';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:asset_management/version.dart';
import 'github_proxy.dart';

class VersionService {
  static const String _githubApiUrl = 'https://api.github.com/repos/ccc798/AssetManagement/releases/latest';
  static const String _githubHomeUrl = 'https://github.com/ccc798/AssetManagement';

  static String get githubHomeUrl => _githubHomeUrl;

  static Future<VersionInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.get(_githubApiUrl);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return VersionInfo.fromJson(data);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static bool isNewVersion(String latestVersion) {
    const current = AppVersion.version;
    return compareVersions(latestVersion, current) > 0;
  }

  static int compareVersions(String v1, String v2) {
    final parts1 = v1.trim().replaceAll('v', '').split('.').map(int.parse).toList();
    final parts2 = v2.trim().replaceAll('v', '').split('.').map(int.parse).toList();
    
    final length = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < length; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  static Future<String?> downloadApkWithProxy(
    String downloadUrl,
    bool useProxy,
    void Function(int, int)? onProgress, {
    List<String> proxies = const [],
  }) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) return null;

    final fileName = downloadUrl.split('/').last;
    final savePath = '${dir.path}/$fileName';

    if (useProxy) {
      final proxyService = GithubProxyService();
      List<String> sortedProxies;
      
      if (proxies.isNotEmpty) {
        sortedProxies = proxies;
      } else {
        final results = await proxyService.testAndSortProxies();
        sortedProxies = results.map((r) => r.proxy).toList();
      }
      
      if (sortedProxies.isNotEmpty) {
        final result = await proxyService.downloadWithProxy(
          downloadUrl,
          savePath,
          sortedProxies,
          onProgress: onProgress,
        );
        if (result != null) {
          return result;
        }
      }
    }

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 120);

      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: onProgress,
      );
      return savePath;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> installApk(String apkPath) async {
    try {
      final file = File(apkPath);
      if (!file.existsSync()) {
        return false;
      }

      final uri = Uri.file(apkPath);
      if (await canLaunchUrlString(uri.toString())) {
        await launchUrlString(uri.toString(), mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cleanupOldApks() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;

      const currentVersion = AppVersion.version;
      final files = dir.listSync().where((entity) => 
        entity is File && entity.path.endsWith('.apk') && entity.path.contains('AssetManagement')
      ).toList();

      for (final file in files) {
        final filePath = file.path;
        final regex = RegExp(r'v(\d+\.\d+\.\d+)');
        final match = regex.firstMatch(filePath);
        
        if (match != null) {
          final fileVersion = match.group(1)!;
          if (compareVersions(currentVersion, fileVersion) > 0) {
            await (file as File).delete();
          }
        }
      }
    } catch (_) {
    }
  }

  static Future<void> cleanupOldApksOnStart() async {
    await cleanupOldApks();
  }
}

class VersionInfo {
  final String version;
  final String title;
  final String body;
  final String? downloadUrl;
  final DateTime publishedAt;

  VersionInfo({
    required this.version,
    required this.title,
    required this.body,
    this.downloadUrl,
    required this.publishedAt,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    String? apkUrl;
    final assets = json['assets'] as List?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset['name']?.toString().endsWith('.apk') ?? false) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return VersionInfo(
      version: json['tag_name'] as String? ?? '',
      title: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      downloadUrl: apkUrl,
      publishedAt: DateTime.parse(json['published_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}