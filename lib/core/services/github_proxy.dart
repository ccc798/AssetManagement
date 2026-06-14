import 'dart:io';
import 'package:dio/dio.dart';

class GithubProxyService {
  static const List<String> _defaultProxies = [
    'https://gh.b52m.cn/',
    'https://github.xxlab.tech/',
    'https://github.chenc.dev/',
    'https://github.cnxiaobai.com/',
    'https://proxy.yaoyaoling.net/',
    'https://ghproxy.053000.xyz/',
    'https://g.blfrp.cn/',
    'https://gh-proxy.com/',
    'https://gh.halonice.com/',
    'https://ghproxy.mirror.skybyte.me/',
    'https://30006000.xyz/',
    'https://gp.zkitefly.eu.org/',
    'https://gh.padao.fun/',
    'https://git.40609891.xyz/',
    'https://git.yylx.win/',
  ];

  static List<String> get proxies => _defaultProxies;

  final Dio _dio = Dio();

  Future<List<String>> testAndSortProxies() async {
    final results = <_ProxyResult>[];

    for (final proxy in _defaultProxies) {
      final latency = await _testLatency(proxy);
      if (latency >= 0) {
        results.add(_ProxyResult(proxy: proxy, latency: latency));
      }
    }

    results.sort((a, b) => a.latency.compareTo(b.latency));
    
    return results.map((r) => r.proxy).toList();
  }

  Future<int> _testLatency(String proxy) async {
    try {
      final url = '${proxy}https://github.com/favicon.ico';
      final stopwatch = Stopwatch()..start();
      
      await _dio.head(
        url,
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  Future<String?> downloadWithProxy(
    String originalUrl,
    String savePath,
    List<String> sortedProxies, {
    void Function(int, int)? onProgress,
  }) async {
    for (final proxy in sortedProxies) {
      final proxiedUrl = '$proxy$originalUrl';
      try {
        final result = await _downloadFile(proxiedUrl, savePath, onProgress);
        if (result != null) {
          return result;
        }
      } catch (_) {
        continue;
      }
    }

    try {
      return await _downloadFile(originalUrl, savePath, onProgress);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _downloadFile(
    String url,
    String savePath,
    void Function(int, int)? onProgress,
  ) async {
    await _dio.download(
      url,
      savePath,
      options: Options(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
      onReceiveProgress: onProgress,
    );

    if (File(savePath).existsSync()) {
      return savePath;
    }
    return null;
  }
}

class _ProxyResult {
  final String proxy;
  final int latency;

  _ProxyResult({
    required this.proxy,
    required this.latency,
  });
}