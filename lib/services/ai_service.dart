import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../core/i18n/translations.dart';
import '../data/database/config_dao.dart';
import '../data/models/backup_config.dart';

/// AI Service — OpenAI-compatible interface
///
/// Supports:
/// 1. Screenshot recognition (vision) — extract item info from receipt images
/// 2. Data enrichment (text) — structured classification / tag suggestions
class AiService {
  final Dio _dio = Dio();
  final ConfigDao _configDao = ConfigDao();
  
  /// AI 识别结果缓存（key: 图片MD5哈希, value: 识别结果）
  static final Map<String, List<Map<String, dynamic>>> _recognitionCache = {};
  static const int _maxCacheSize = 50;

  AiService() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (_) => true,
      followRedirects: true,
      maxRedirects: 5,
    );
  }

  /// 计算图片数据的 MD5 哈希值作为缓存键
  String _computeImageHash(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  /// 从缓存获取识别结果
  List<Map<String, dynamic>>? _getFromCache(List<int> imageBytes) {
    final hash = _computeImageHash(imageBytes);
    return _recognitionCache[hash];
  }

  /// 将识别结果存入缓存
  void _addToCache(List<int> imageBytes, List<Map<String, dynamic>> result) {
    final hash = _computeImageHash(imageBytes);
    _recognitionCache[hash] = result;
    
    // 清理过期缓存，保持最大缓存数量
    while (_recognitionCache.length > _maxCacheSize) {
      _recognitionCache.remove(_recognitionCache.keys.first);
    }
  }

  /// 清除缓存（用于配置变更时）
  void clearCache() {
    _recognitionCache.clear();
  }

  /// 获取缓存大小
  int get cacheSize => _recognitionCache.length;

  Future<BackupConfig> _getConfig() async {
    return _configDao.getConfig();
  }

  String _normalizeBaseUrl(String url) {
    var u = url.trim();
    u = u.replaceAll(',', '.').replaceAll('，', '.');
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    u = u.replaceAll(RegExp(r'/*$'), '');
    if (!RegExp(r'/v\d+$').hasMatch(u)) u = '$u/v1';
    return u;
  }

  Future<Map<String, String>> _headers() async {
    final config = await _getConfig();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.aiApiKey}',
    };
  }

  String _buildUrl(String baseUrl, String path) {
    return '${_normalizeBaseUrl(baseUrl)}$path';
  }

  Future<Response> _retryPost(String url, {required Options options, required dynamic data}) async {
    try {
      return await _dio.post(url, options: options, data: data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError &&
          e.message != null &&
          e.message!.contains('Connection refused')) {
        await Future.delayed(const Duration(milliseconds: 1500));
        return await _dio.post(url, options: options, data: data);
      }
      rethrow;
    }
  }

  /// OCR 提示词常量
  static const String _ocrPrompt = '''
You are a shopping receipt OCR assistant. Extract all purchased item information from this receipt screenshot.

Return a JSON array of items. Each item must follow this structure:

[
  {
    "name": "Item name (required)",
    "category": "electronics/clothing/food/home/books/sports/beauty/transportation/medical/gifts/pets/other",
    "brand": "Brand name",
    "price": Actual paid price as number (required, no currency symbol),
    "quantity": Quantity (default 1),
    "purchaseDate": "Purchase date in YYYY-MM-DD format",
    "tags": ["tag1", "tag2"]
  }
]

Important price extraction rules:
1. Receipts often show multiple amounts: original price, discount, final payment, etc.
2. Use the actual payment amount (final price, total, amount paid, checkout total)
3. Do NOT use original price, crossed-out price, list price, or suggested retail price
4. Do NOT use discount/saved amounts (these are savings, not payment)
5. If you see "x到手价/券后价/活动价/促销价", use that amount
6. For multi-item orders (e.g., Taobao/JD):
   a) Each item's displayed price next to it is its individual price
   b) The bottom "total/order total" is the sum for the whole order
   c) Extract each item's own price label independently
   d) Prefer individual item prices over the order total
7. If only the order total is visible with no individual prices, estimate as "total/quantity" and add tag "estimated"

Additional rules:
- If only one item, still return an array containing one element
- If multiple items (e.g., phone + earphones), each is a separate element
- If multiple identical items (e.g., 3x T-shirts), set quantity to 3 and price to unit price
- Return ONLY the JSON array, no additional explanation
- Leave uncertain fields as empty string or null
''';

  /// 构建图片识别请求数据
  Map<String, dynamic> _buildImageRecognitionRequest(
    String model,
    String base64Image,
    int maxTokens,
    double temperature,
  ) {
    return {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': _ocrPrompt,
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
                'detail': 'high',
              },
            },
          ],
        },
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }

  /// 解析 AI 响应内容
  String? _parseResponseContent(dynamic responseData) {
    return responseData?['choices']?[0]?['message']?['content']?.toString().trim();
  }

  /// 格式化识别结果
  List<Map<String, dynamic>> _formatRecognitionResult(String jsonStr) {
    final parsed = jsonDecode(jsonStr);
    
    if (parsed is List) {
      final items = parsed.cast<Map<String, dynamic>>();
      for (final item in items) {
        item['aiRawData'] = jsonEncode(items);
        item['quantity'] = (item['quantity'] as num?)?.toInt() ?? 1;
      }
      return items;
    }
    
    if (parsed is Map) {
      final single = Map<String, dynamic>.from(parsed);
      single['aiRawData'] = jsonEncode(single);
      single['quantity'] = (single['quantity'] as num?)?.toInt() ?? 1;
      return [single];
    }
    
    return [];
  }

  /// 从购物截图识别物品信息
  Future<List<Map<String, dynamic>>> recognizeFromScreenshot(
    List<int> imageBytes, {
    String? fileName,
    String locale = 'zh',
    bool skipCache = false,
  }) async {
    final config = await _getConfig();
    
    // 检查 API Key
    final validationError = _validateConfig(config, locale);
    if (validationError != null) {
      return [validationError];
    }

    // 检查缓存
    if (!skipCache) {
      final cached = _getFromCache(imageBytes);
      if (cached != null) {
        return cached;
      }
    }

    try {
      // 构建请求
      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final base64Image = base64Encode(imageBytes);
      final requestData = _buildImageRecognitionRequest(
        config.aiModel,
        base64Image,
        config.aiMaxTokens,
        config.aiTemperature,
      );

      // 发送请求
      final response = await _retryPost(
        url,
        options: Options(headers: await _headers()),
        data: requestData,
      );

      // 解析响应
      final content = _parseResponseContent(response.data);
      if (content == null || content.isEmpty) {
        return [_createErrorResponse(t('ai.testFailed', locale))];
      }

      // 提取并格式化 JSON
      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final formatted = _formatRecognitionResult(jsonStr);
        if (formatted.isNotEmpty) {
          // 存入缓存
          _addToCache(imageBytes, formatted);
          return formatted;
        }
      }

      return [_createErrorResponse(t('ai.testFailed', locale), rawContent: content)];
    } on DioException catch (e) {
      return [_createErrorResponse('${t('ai.testFailed', locale)}: ${e.message}', rawContent: e.response?.toString())];
    } catch (e) {
      return [_createErrorResponse('${t('ai.testFailed', locale)}: $e')];
    }
  }

  /// 验证配置
  Map<String, dynamic>? _validateConfig(BackupConfig config, String locale) {
    if (config.aiApiKey.isEmpty) {
      return {'error': t('ai.errNoApiKey', locale)};
    }
    return null;
  }

  /// 创建错误响应
  Map<String, dynamic> _createErrorResponse(String error, {String? rawContent}) {
    final response = {'error': error};
    if (rawContent != null && rawContent.isNotEmpty) {
      response['rawContent'] = rawContent;
    }
    return response;
  }

  Future<Map<String, dynamic>> enrichItemInfo(
    Map<String, dynamic> itemInfo,
  ) async {
    final config = await _getConfig();
    if (config.aiApiKey.isEmpty) {
      return itemInfo;
    }

    final url = _buildUrl(config.aiBaseUrl, '/chat/completions');

    final prompt = '''
You are a personal asset management assistant. The user provided raw item information, please enrich and improve it.

Raw information:
${jsonEncode(itemInfo)}

Return the enriched JSON with the following fields:
- name: Standardized item name
- category: Best matching category
- brand: Brand name
- tags: Suggested tags array (3-5 items)
- suggestions: Usage/care suggestions (one sentence)

Return ONLY the JSON, no additional explanation.
''';

    try {
      final response = await _dio.post(
        url,
        options: Options(headers: await _headers()),
        data: {
          'model': config.aiModel,
          'messages': [
            {
              'role': 'system',
              'content': prompt,
            },
            {
              'role': 'user',
              'content': 'Please help me enrich this item info',
            },
          ],
          'max_tokens': config.aiMaxTokens,
          'temperature': config.aiTemperature,
        },
      );

      final result = response.data;
      final content = result['choices']?[0]?['message']?['content'] ?? '';

      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final enriched = jsonDecode(jsonStr) as Map<String, dynamic>;
        return {...itemInfo, ...enriched};
      }
    } catch (_) {}

    return itemInfo;
  }

  String? _extractJson(String text) {
    try {
      jsonDecode(text);
      return text;
    } catch (_) {}

    final jsonBlock = RegExp(r'```(?:json)?\n?(.*?)\n?```', dotAll: true);
    final match = jsonBlock.firstMatch(text);
    if (match != null) {
      try {
        jsonDecode(match.group(1)!);
        return match.group(1);
      } catch (_) {}
    }

    final braceStart = text.indexOf('{');
    if (braceStart >= 0) {
      final braceEnd = text.lastIndexOf('}');
      if (braceEnd > braceStart) {
        try {
          jsonDecode(text.substring(braceStart, braceEnd + 1));
          return text.substring(braceStart, braceEnd + 1);
        } catch (_) {}
      }
    }

    final bracketStart = text.indexOf('[');
    if (bracketStart >= 0) {
      final bracketEnd = text.lastIndexOf(']');
      if (bracketEnd > bracketStart) {
        try {
          jsonDecode(text.substring(bracketStart, bracketEnd + 1));
          return text.substring(bracketStart, bracketEnd + 1);
        } catch (_) {}
      }
    }

    return null;
  }

  /// 测试 AI 连接
  Future<String?> testConnection({String locale = 'zh'}) async {
    try {
      final config = await _getConfig();
      if (config.aiApiKey.isEmpty) return t('ai.testFailed', locale);

      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final headers = await _headers();

      // Step 1: Basic connection test
      final baseResp = await _retryPost(
        url,
        options: Options(headers: headers),
        data: {
          'model': config.aiModel,
          'messages': [{'role': 'user', 'content': 'Hi'}],
          'max_tokens': 10,
        },
      );

      final baseError = _checkBasicResponse(baseResp, locale);
      if (baseError != null) return baseError;

      // Step 2: Multimodal image recognition test
      return await _testMultimodalCapability(url, headers, config.aiModel, locale);
    } on DioException catch (e) {
      return _handleDioException(e, locale);
    } catch (e) {
      return '${t('ai.testFailed', locale)}: $e';
    }
  }

  /// 检查基础连接响应
  String? _checkBasicResponse(Response response, String locale) {
    if (response.statusCode == 200) return null;
    
    if (response.statusCode == 401) return t('ai.errInvalidKey', locale);
    if (response.statusCode == 404) return t('ai.errNotFound', locale);
    if (response.statusCode == 429) return t('ai.errTooMany', locale);
    if (response.statusCode == 500) return t('ai.errServerError', locale);
    return 'HTTP ${response.statusCode}';
  }

  /// 测试多模态能力
  Future<String?> _testMultimodalCapability(
    String url,
    Map<String, String> headers,
    String model,
    String locale,
  ) async {
    const testPngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAnSURBVDhPY5Cb8P8/NTEDugCleNRAyvGogZTjUQMpx6MGUo4Hv4EA/cEs/Z9QHFEAAAAASUVORK5CYII=';

    try {
      final visionResp = await _retryPost(
        url,
        options: Options(headers: headers),
        data: {
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Describe this image'},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,$testPngBase64',
                    'detail': 'low',
                  },
                },
              ],
            },
          ],
          'max_tokens': 50,
        },
      );

      if (visionResp.statusCode == 200) return null;
      if (visionResp.statusCode == 400) return t('ai.errNoVision', locale);
      return t('ai.errVisionFailed', locale).replaceAll('{code}', '${visionResp.statusCode}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse && e.response?.statusCode == 400) {
        return t('ai.errNoVision', locale);
      }
      return t('ai.errVisionAbnormal', locale);
    }
  }

  /// 处理 Dio 异常
  String _handleDioException(DioException e, String locale) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return t('ai.errTimeout', locale);
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return t('ai.errReceiveTimeout', locale);
    }
    if (e.type == DioExceptionType.connectionError) {
      if (e.message != null && e.message!.contains('Connection refused')) {
        return t('ai.errConnectionRefused', locale);
      }
      return t('ai.errCantConnect', locale).replaceAll('{msg}', '${e.message}');
    }
    if (e.type == DioExceptionType.badResponse) {
      final code = e.response?.statusCode;
      if (code == 400) return t('ai.errBadRequest', locale);
      if (code == 401) return t('ai.errInvalidKey', locale);
      if (code == 404) return t('ai.errNotFound', locale);
      if (code == 429) return t('ai.errTooMany', locale);
      return t('ai.errServerError2', locale).replaceAll('{code}', '$code');
    }
    return '${t('ai.testFailed', locale)}: ${e.message}';
  }
}