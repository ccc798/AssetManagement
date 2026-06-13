import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import '../data/database/config_dao.dart';
import '../data/models/backup_config.dart';

/// WebDAV 澶囦唤鏈嶅姟
class WebDavService {
  final ConfigDao _configDao = ConfigDao();

  WebDavService();

  /// 鏋勫缓甯?Basic 璁よ瘉鐨?Dio 瀹炰緥
  Future<Dio> _authDio() async {
    final config = await _configDao.getConfig();

    // 鏍囧噯鍖?base URL 鈥?鐩綍 URL 蹇呴』浠?/ 缁撳熬
    var baseUrl = config.webdavUrl.trim();
    // 淇甯歌绗旇锛氶€楀彿鈫掔偣鍙枫€佸叏瑙掔偣鈫掔偣鍙?    baseUrl = baseUrl.replaceAll(',', '.').replaceAll('，', '.');
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }
    // 鑷姩淇甯歌鐨?www.jianguoyun.com 鈫?dav.jianguoyun.com
    baseUrl = baseUrl.replaceFirstMapped(
      RegExp(r'^https?://www\.jianguoyun\.com', caseSensitive: false),
      (m) => '${m.input.substring(0, m.start)}https://dav.jianguoyun.com',
    );
    baseUrl = baseUrl.replaceAll(RegExp(r'/*$'), '') + '/';

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      validateStatus: (_) => true,
      baseUrl: baseUrl,
      followRedirects: true,
      maxRedirects: 5,
    ));

    // Basic 璁よ瘉
    if (config.webdavUsername.isNotEmpty &&
        config.webdavPassword.isNotEmpty) {
      final basicAuth = base64Encode(
        utf8.encode('${config.webdavUsername}:${config.webdavPassword}'),
      );
      dio.options.headers['Authorization'] = 'Basic $basicAuth';
    }

    return dio;
  }

  /// 拼接远程文件路径（相对于 base URL）
  String _fileUrl(String fileName, {String? path}) {
    final buf = StringBuffer();
    if (path != null && path.isNotEmpty) {
      buf.write(path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/*$'), ''));
      buf.write('/');
    }
    buf.write(fileName);
    return buf.toString();
  }

  /// 获取 WebDAV 配置是否有效
  Future<bool> isConfigured() async {
    final config = await _configDao.getConfig();
    return config.webdavUrl.isNotEmpty;
  }

  /// 娴嬭瘯 WebDAV 杩炴帴
  ///
  /// 杩斿洖 null = 鎴愬姛锛岄潪 null = 閿欒淇℃伅
  Future<String?> testConnection() async {
    try {
      final config = await _configDao.getConfig();
      if (config.webdavUrl.isEmpty) return 'WebDAV 地址未填写';

      final dio = await _authDio();
      // baseUrl 宸插寘鍚畬鏁寸洰褰曡矾寰勶紝璇锋眰鐢?'' 鍗冲彲

      // ---------- 1. 鍏堣瘯 PROPFIND ----------
      try {
        final body = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <resourcetype/>
    <displayname/>
    <getlastmodified/>
    <getcontentlength/>
  </prop>
</propfind>''';

        final resp = await dio.request(
          '',
          data: body,
          options: Options(
            method: 'PROPFIND',
            headers: {
              'Depth': '0',
              'Content-Type': 'application/xml; charset=utf-8',
            },
            responseType: ResponseType.plain,
          ),
        );

        if (resp.statusCode == 207 || resp.statusCode == 200) {
          return null; // ✓ 成功
        }

        // 501 → 不支持 PROPFIND，降级到 OPTIONS
        if (resp.statusCode != 501) {
          if (resp.statusCode == 401) return '认证失败（请检查用户名和密码）';
          if (resp.statusCode == 404) return '地址不存在（请检查 WebDAV URL）';
          return 'PROPFIND 杩斿洖: ${resp.statusCode}';
        }
      } on DioException catch (_) {
        // PROPFIND 异常 → 继续试 OPTIONS
      }

      // ---------- 2. 澶囬€夛細OPTIONS ----------
      try {
        final resp = await dio.request('', options: Options(method: 'OPTIONS'));

        if (resp.statusCode == 200 || resp.statusCode == 204 || resp.statusCode == 207) {
          final dav = resp.headers.value('DAV') ?? '';
          final allow = resp.headers.value('Allow') ?? '';
          if (dav.isNotEmpty || allow.contains('PROPFIND') || allow.contains('PUT')) {
            return null; // ✓ 服务器支持 WebDAV
          }
          return '服务器可连，但未检测到 WebDAV 支持';
        }
        if (resp.statusCode == 401) return '认证失败';
        if (resp.statusCode == 404) return '地址不存在';
        return 'OPTIONS 杩斿洖: ${resp.statusCode}';
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionTimeout) return '连接超时';
        if (e.type == DioExceptionType.connectionError) return '无法连接服务器（${e.message}）';
        return '璇锋眰澶辫触: ${e.message}';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) return '连接超时';
      if (e.type == DioExceptionType.connectionError) return '无法连接服务器（${e.message}）';
      return '璇锋眰澶辫触: ${e.message}';
    } catch (e) {
      return '鏈煡閿欒: $e';
    }
  }

  /// 确保远程目录存在（创建如果不存在）
  Future<bool> ensureDirectory() async {
    try {
      final config = await _configDao.getConfig();
      final dio = await _authDio();
      final dir = config.webdavPath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/*$'), '');
      if (dir.isEmpty) return true;

      final dirUrl = '$dir/';
      try {
        await dio.request(dirUrl, options: Options(method: 'MKCOL'));
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 上传备份到 WebDAV
  Future<Map<String, dynamic>> uploadBackup({String? customFileName}) async {
    try {
      final config = await _configDao.getConfig();
      if (config.webdavUrl.isEmpty) return {'success': false, 'error': 'WebDAV 未配置'};

      await ensureDirectory();

      // 找本地数据文件
      final dir = await getApplicationDocumentsDirectory();
      var dataPath = '${dir.path}/asset_management_data.json';
      if (!File(dataPath).existsSync()) {
        // 鍏煎鏃х増鏈枃浠跺悕
        final old = '${dir.path}/asset_keeper_data.json';
        if (File(old).existsSync()) dataPath = old;
        else return {'success': false, 'error': '本地数据文件不存在'};
      }

      final fileName = customFileName ?? 'asset_management_backup_${_formatTimestamp(DateTime.now())}.json';
      final remotePath = _fileUrl(fileName, path: config.webdavPath);

      final fileBytes = await File(dataPath).readAsBytes();
      final dio = await _authDio();
      final resp = await dio.put(
        remotePath,
        data: fileBytes,
        options: Options(headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileBytes.length.toString(),
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) {
        await _configDao.updateLastBackupTime(DateTime.now());
        return {'success': true, 'fileName': fileName, 'fileSize': File(dataPath).lengthSync(), 'uploadTime': DateTime.now().toIso8601String()};
      }
      return {'success': false, 'error': '上传失败，服务器返回 ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': '澶囦唤涓婁紶澶辫触: $e'};
    }
  }

  /// 下载备份
  Future<Map<String, dynamic>> downloadBackup(String fileName) async {
    try {
      final config = await _configDao.getConfig();
      if (config.webdavUrl.isEmpty) return {'success': false, 'error': 'WebDAV 未配置'};

      final remotePath = _fileUrl(fileName, path: config.webdavPath);
      final dio = await _authDio();
      final resp = await dio.get(remotePath, options: Options(responseType: ResponseType.bytes));

      if (resp.statusCode == 200 && resp.data is List<int>) {
        final dir = await getApplicationDocumentsDirectory();
        final suffix = fileName.endsWith('.json') ? '.json' : '.bak';
        final localPath = '${dir.path}/restore_temp$suffix';
        await File(localPath).writeAsBytes(resp.data as List<int>);
        return {'success': true, 'localPath': localPath, 'fileSize': (resp.data as List<int>).length};
      }
      return {'success': false, 'error': '下载失败: ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': '澶囦唤涓嬭浇澶辫触: $e'};
    }
  }

  /// 列出远程备份文件
  ///
  /// 异常直接向上抛，由 UI 层显示错误信息
  Future<List<Map<String, dynamic>>> listBackups() async {
    final config = await _configDao.getConfig();
    if (config.webdavUrl.isEmpty) throw Exception('WebDAV 地址为空，请先保存配置');

    final dirPath = config.webdavPath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/*$'), '');
    final dio = await _authDio();
    final baseUrl = dio.options.baseUrl;

    // 显式构建完整URL（避免依赖Dio的URL解析）
    final fullUrl = dirPath.isEmpty ? baseUrl : '$baseUrl$dirPath/';
    if (!fullUrl.startsWith('http')) throw Exception('URL格式错误: $fullUrl');

    final body = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <displayname/>
    <getlastmodified/>
    <getcontentlength/>
    <resourcetype/>
  </prop>
</propfind>''';

    final resp = await dio.request(
      fullUrl,
      data: body,
      options: Options(
        method: 'PROPFIND',
        responseType: ResponseType.plain,
        headers: {
          'Depth': '1',
          'Content-Type': 'application/xml; charset=utf-8',
        },
      ),
    );

    if (resp.statusCode != 207) {
      throw Exception('PROPFIND 杩斿洖 HTTP ${resp.statusCode}锛岃姹傚湴鍧€: $fullUrl');
    }

    final rawXml = resp.data.toString();
    if (rawXml.trim().isEmpty) {
      throw Exception('服务器返回了空响应');
    }

    final doc = XmlDocument.parse(rawXml);

    // 注意：坚果云服务器返回的 XML 带 d: 命名空间前缀（DAV:）
    // 因此 findElements('response') 找不到元素，必须用 findElements('d:response')
    const dav = 'd:';
    XmlElement? firstProp(XmlElement parent) => parent
        .findElements('${dav}propstat').firstOrNull
        ?.findElements('${dav}prop').firstOrNull;

    final allResponses = doc.findAllElements('${dav}response');
    final totalResponses = allResponses.length;

    if (totalResponses == 0) {
      throw Exception('XML 涓病鏈夋壘鍒颁换浣?<d:response> 鍏冪礌');
    }

    final files = <Map<String, dynamic>>[];
    int skippedDir = 0;
    int skippedProps = 0;

    for (final r in allResponses) {
      final href = r.findElements('${dav}href').firstOrNull?.innerText ?? '(鏃爃ref)';

      // 璺宠繃鐩綍
      final resType = firstProp(r)
          ?.findElements('${dav}resourcetype').firstOrNull;
      if (resType != null && resType.findElements('${dav}collection').isNotEmpty) {
        skippedDir++;
        continue;
      }

      final props = firstProp(r);
      if (props == null) {
        skippedProps++;
        continue;
      }

      files.add({
        'fileName': Uri.decodeComponent(href.split('/').last),
        'fileSize': int.tryParse(props.findElements('${dav}getcontentlength').firstOrNull?.innerText ?? '0') ?? 0,
        'lastModified': props.findElements('${dav}getlastmodified').firstOrNull?.innerText ?? '',
      });
    }

    if (files.isEmpty) {
      throw Exception('共 $totalResponses 个 response，跳过 $skippedDir 个目录、$skippedProps 个无 props，剩余 0 个文件');
    }

    files.sort((a, b) => (b['lastModified'] as String).compareTo(a['lastModified'] as String));
    return files;
  }

  /// 鍒犻櫎杩滅▼澶囦唤
  Future<bool> deleteBackup(String fileName) async {
    try {
      final config = await _configDao.getConfig();
      final remotePath = _fileUrl(fileName, path: config.webdavPath);
      final dio = await _authDio();
      await dio.delete(remotePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 鏍煎紡鍖栨椂闂存埑鐢ㄤ簬鏂囦欢鍚嶏細2026-06-11_14-30-00
  String _formatTimestamp(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}_${pad(dt.hour)}-${pad(dt.minute)}-${pad(dt.second)}';
  }
}
