import 'dart:convert';
import 'dart:io';
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

  AiService() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      validateStatus: (_) => true,
      followRedirects: true,
      maxRedirects: 5,
    );
  }

  /// 获取当前 AI 配置
  Future<BackupConfig> _getConfig() async {
    return _configDao.getConfig();
  }

  /// 标准化 AI API 基础 URL — 确保以 /v1 结尾
  /// 如果路径已包含版本段（/v1、/v2 等）则不再追加
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

  /// 构建请求头
  Future<Map<String, String>> _headers() async {
    final config = await _getConfig();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.aiApiKey}',
    };
  }

  /// 构建请求 URL（自动标准化 base URL）
  String _buildUrl(String baseUrl, String path) {
    return '${_normalizeBaseUrl(baseUrl)}$path';
  }

  /// 带自动重试的 POST 请求（连接类异常重试 1 次）
  Future<Response> _retryPost(String url, {required Options options, required dynamic data}) async {
    try {
      return await _dio.post(url, options: options, data: data);
    } on DioException catch (e) {
      // 连接被拒绝 → 等待 1.5 秒后重试一次
      if (e.type == DioExceptionType.connectionError &&
          e.message != null &&
          e.message!.contains('Connection refused')) {
        await Future.delayed(const Duration(milliseconds: 1500));
        return await _dio.post(url, options: options, data: data);
      }
      rethrow;
    }
  }

  /// 从购物截图识别物品信息
  ///
  /// [imageBytes] 图片的字节数据
  /// 返回物品列表（支持一笔订单多件物品）
  Future<List<Map<String, dynamic>>> recognizeFromScreenshot(
    List<int> imageBytes, {
    String? fileName,
    String locale = 'zh',
  }) async {
    final config = await _getConfig();
    if (config.aiApiKey.isEmpty) {
      return [{'error': '请先在设置中配置 AI API Key'}];
    }

    // 将图片转为 Base64
    final base64Image = base64Encode(imageBytes);

    final url = _buildUrl(config.aiBaseUrl, '/chat/completions');

    final prompt = '''
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

    try {
      final response = await _retryPost(
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
          'max_tokens': config.aiMaxTokens,
          'temperature': config.aiTemperature,
        },
      );

      final result = response.data;
      final content = result['choices']?[0]?['message']?['content'] ?? '';

      // 提取 JSON
      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final parsed = jsonDecode(jsonStr);

        // AI 可能返回数组（多物品）或单个对象（单物品），统一为列表
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
      }

      return [{
        'error': t('ai.testFailed', locale),
        'rawContent': content,
      }];
    } on DioException catch (e) {
      return [{
        'error': '${t('ai.testFailed', locale)}: ${e.message}',
        'rawContent': e.response?.toString() ?? '',
      }];
    } catch (e) {
      return [{
        'error': '${t('ai.testFailed', locale)}: $e',
      }];
    }
  }

  /// 由 AI 整理和补充物品信息
  ///
  /// [itemInfo] 包含部分物品信息的 Map
  /// 返回补充后的完整物品信息
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
    // 合并，以 AI 补充的覆盖原始信息
    return {...itemInfo, ...enriched};
      }
    } catch (_) {}

    return itemInfo;
  }

  /// 从文本中提取 JSON
  String? _extractJson(String text) {
    // 尝试直接解析
    try {
      jsonDecode(text);
      return text;
    } catch (_) {}

    // 查找 ```json ... ``` 块
    final jsonBlock = RegExp(r'```(?:json)?\n?(.*?)\n?```', dotAll: true);
    final match = jsonBlock.firstMatch(text);
    if (match != null) {
      try {
        jsonDecode(match.group(1)!);
        return match.group(1);
      } catch (_) {}
    }

    // 查找 `{ }` 包裹的最外层
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

    // 查找 `[ ]` 包裹
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

  /// 测试 AI 连接 + 多模态图片识别能力
  ///
  /// 返回 null = 全部正常，非 null = 错误或警告
  Future<String?> testConnection({String locale = 'zh'}) async {
    try {
      final config = await _getConfig();
      if (config.aiApiKey.isEmpty) return t('ai.testFailed', locale);

      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final headers = await _headers();

      // ---------- Step 1: Basic connection test ----------
      final baseResp = await _retryPost(
        url,
        options: Options(headers: headers),
        data: {
          'model': config.aiModel,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 10,
        },
      );

      if (baseResp.statusCode != 200) {
        if (baseResp.statusCode == 401) return t('ai.errInvalidKey', locale);
        if (baseResp.statusCode == 404) return t('ai.errNotFound', locale);
        if (baseResp.statusCode == 429) return t('ai.errTooMany', locale);
        if (baseResp.statusCode == 500) return t('ai.errServerError', locale);
        return 'HTTP ${baseResp.statusCode}';
      }

      // ---------- Step 2: Multimodal image recognition test ----------
      // 使用 20x20 像素的蓝色实心 PNG 测试多模态能力
      // 注意：1x1 像素图片会被部分模型拒绝（尺寸过小），因此使用 20x20
      final testPngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAnSURBVDhPY5Cb8P8/NTEDugCleNRAyvGogZTjUQMpx6MGUo4Hv4EA/cEs/Z9QHFEAAAAASUVORK5CYII=';

      try {
        final visionResp = await _retryPost(
          url,
          options: Options(headers: headers),
          data: {
            'model': config.aiModel,
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

        if (visionResp.statusCode == 200) {
          return null; // ✓ 模型支持多模态
        }
        if (visionResp.statusCode == 400) {
          return t('ai.errNoVision', locale);
        }
        return t('ai.errVisionFailed', locale).replaceAll('{code}', '${visionResp.statusCode}');
      } on DioException catch (e) {
        if (e.type == DioExceptionType.badResponse &&
            e.response?.statusCode == 400) {
          return t('ai.errNoVision', locale);
        }
        return t('ai.errVisionAbnormal', locale);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) return t('ai.errTimeout', locale);
      if (e.type == DioExceptionType.receiveTimeout) return t('ai.errReceiveTimeout', locale);
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
    } catch (e) {
      return '${t('ai.testFailed', locale)}: $e';
    }
  }
}
