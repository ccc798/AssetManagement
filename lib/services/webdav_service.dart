import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import '../data/database/config_dao.dart';
import '../core/i18n/translations.dart';

/// WebDAV backup service
class WebDavService {
  final ConfigDao _configDao = ConfigDao();

  WebDavService();

  Future<Dio> _authDio() async {
    final config = await _configDao.getConfig();

    var baseUrl = config.webdavUrl.trim();
    baseUrl = baseUrl.replaceAll(',', '.').replaceAll('，', '.');
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }
    baseUrl = baseUrl.replaceFirstMapped(
      RegExp(r'^https?://www\.jianguoyun\.com', caseSensitive: false),
      (m) => '${m.input.substring(0, m.start)}https://dav.jianguoyun.com',
    );
    baseUrl = baseUrl.replaceAll(RegExp(r'/*$'), '');
    baseUrl = '$baseUrl/';

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      validateStatus: (_) => true,
      baseUrl: baseUrl,
      followRedirects: true,
      maxRedirects: 5,
    ));

    if (config.webdavUsername.isNotEmpty && config.webdavPassword.isNotEmpty) {
      final basicAuth = base64Encode(utf8.encode('${config.webdavUsername}:${config.webdavPassword}'));
      dio.options.headers['Authorization'] = 'Basic $basicAuth';
    }

    return dio;
  }

  String _fileUrl(String fileName, {String? path}) {
    final buf = StringBuffer();
    if (path != null && path.isNotEmpty) {
      buf.write(path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/*$'), ''));
      buf.write('/');
    }
    buf.write(fileName);
    return buf.toString();
  }

  Future<bool> isConfigured() async {
    final config = await _configDao.getConfig();
    return config.webdavUrl.isNotEmpty;
  }

  /// PROPFIND 请求体
  static const String _propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <resourcetype/>
    <displayname/>
    <getlastmodified/>
    <getcontentlength/>
  </prop>
</propfind>''';

  /// 测试 WebDAV 连接
  Future<String?> testConnection({String locale = 'zh'}) async {
    final config = await _configDao.getConfig();
    
    // 检查配置
    if (config.webdavUrl.isEmpty) {
      return '${t('error.loadFailed', locale)}: WebDAV URL not set';
    }

    final dio = await _authDio();

    // 尝试 PROPFIND
    final propfindResult = await _tryPropfind(dio, locale);
    if (propfindResult != null) {
      // PROPFIND 成功或返回明确错误
      if (propfindResult.isEmpty) return null;
      if (propfindResult != 'fallback') return propfindResult;
    }

    // PROPFIND 失败，降级到 OPTIONS
    return await _tryOptions(dio, locale);
  }

  /// 尝试 PROPFIND 请求
  /// 返回: null=成功, 'fallback'=需要降级, 其他=错误消息
  Future<String?> _tryPropfind(Dio dio, String locale) async {
    try {
      final resp = await dio.request(
        '',
        data: _propfindBody,
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
        return null; // 成功
      }

      // 501 → PROPFIND 不支持，需要降级到 OPTIONS
      if (resp.statusCode == 501) {
        return 'fallback';
      }

      // 其他状态码返回错误
      return _handlePropfindError(resp.statusCode ?? 0, locale);
    } on DioException catch (_) {
      // PROPFIND 异常，降级到 OPTIONS
      return 'fallback';
    }
  }

  /// 处理 PROPFIND 错误状态码
  String _handlePropfindError(int statusCode, String locale) {
    if (statusCode == 401) return t('webdav.errAuth', locale);
    if (statusCode == 404) return t('webdav.errNotFound', locale);
    return t('webdav.errPropfind', locale).replaceAll('{code}', '$statusCode');
  }

  /// 尝试 OPTIONS 请求（降级方案）
  Future<String?> _tryOptions(Dio dio, String locale) async {
    try {
      final resp = await dio.request('', options: Options(method: 'OPTIONS'));
      return _handleOptionsResponse(resp, locale);
    } on DioException catch (e) {
      return _handleDioException(e, locale);
    }
  }

  /// 处理 OPTIONS 响应
  String? _handleOptionsResponse(Response resp, String locale) {
    final statusCode = resp.statusCode ?? 0;
    
    if (statusCode == 200 || statusCode == 204 || statusCode == 207) {
      final dav = resp.headers.value('DAV') ?? '';
      final allow = resp.headers.value('Allow') ?? '';
      if (dav.isNotEmpty || allow.contains('PROPFIND') || allow.contains('PUT')) {
        return null; // 支持 WebDAV
      }
      return t('webdav.errNoWebdav', locale);
    }

    if (statusCode == 401) return t('webdav.errAuth', locale);
    if (statusCode == 404) return t('webdav.errNotFound', locale);
    return t('webdav.errOptions', locale).replaceAll('{code}', '$statusCode');
  }

  /// 处理 Dio 异常
  String _handleDioException(DioException e, String locale) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return t('webdav.errTimeout', locale);
    }
    if (e.type == DioExceptionType.connectionError) {
      return t('webdav.errCantConnect', locale).replaceAll('{msg}', '${e.message}');
    }
    return t('webdav.errRequest', locale).replaceAll('{msg}', '${e.message}');
  }

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

  Future<Map<String, dynamic>> uploadBackup({String? customFileName}) async {
    try {
      final config = await _configDao.getConfig();
      if (config.webdavUrl.isEmpty) return {'success': false, 'error': 'WebDAV not configured'};

      await ensureDirectory();

      final dir = await getApplicationDocumentsDirectory();
      var dataPath = '${dir.path}/asset_management_data.json';
      if (!File(dataPath).existsSync()) {
        final old = '${dir.path}/asset_keeper_data.json';
        if (File(old).existsSync()) {
          dataPath = old;
        } else {
          return {'success': false, 'error': 'Local data file not found'};
        }
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
      return {'success': false, 'error': 'Upload failed, server returned ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Backup upload failed: $e'};
    }
  }

  Future<Map<String, dynamic>> downloadBackup(String fileName) async {
    try {
      final config = await _configDao.getConfig();
      if (config.webdavUrl.isEmpty) return {'success': false, 'error': 'WebDAV not configured'};

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
      return {'success': false, 'error': 'Download failed: ${resp.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Backup download failed: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final config = await _configDao.getConfig();
    if (config.webdavUrl.isEmpty) throw Exception('webdav.errEmptyUrl');

    final dirPath = config.webdavPath.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/*$'), '');
    final dio = await _authDio();
    final baseUrl = dio.options.baseUrl;

    final fullUrl = dirPath.isEmpty ? baseUrl : '$baseUrl$dirPath/';
    if (!fullUrl.startsWith('http')) throw Exception('webdav.errInvalidUrl:$fullUrl');

    const body = '''<?xml version="1.0" encoding="utf-8"?>
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
      throw Exception('webdav.errPropfind:${resp.statusCode}');
    }

    final rawXml = resp.data.toString();
    if (rawXml.trim().isEmpty) {
      throw Exception('webdav.errEmptyResponse');
    }

    return _parsePropfindResponse(rawXml);
  }

  /// 解析 PROPFIND 响应，提取文件列表
  List<Map<String, dynamic>> _parsePropfindResponse(String rawXml) {
    final doc = XmlDocument.parse(rawXml);
    const dav = 'd:';

    XmlElement? firstProp(XmlElement parent) => parent
        .findElements('${dav}propstat').firstOrNull
        ?.findElements('${dav}prop').firstOrNull;

    final allResponses = doc.findAllElements('${dav}response');
    final totalResponses = allResponses.length;

    if (totalResponses == 0) {
      throw Exception('webdav.errNoXmlResponse');
    }

    final files = <Map<String, dynamic>>[];
    int skippedDir = 0;
    int skippedProps = 0;

    for (final r in allResponses) {
      final href = r.findElements('${dav}href').firstOrNull?.innerText ?? '(no href)';

      // 跳过目录
      final resType = firstProp(r)?.findElements('${dav}resourcetype').firstOrNull;
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
      throw Exception('webdav.errNoFilesParsed:$totalResponses:$skippedDir:$skippedProps');
    }

    files.sort((a, b) => (b['lastModified'] as String).compareTo(a['lastModified'] as String));
    return files;
  }

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

  String _formatTimestamp(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}_${pad(dt.hour)}-${pad(dt.minute)}-${pad(dt.second)}';
  }
}