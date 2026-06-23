﻿import 'dart:convert';
import 'dart:math';
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
/// 3. OCR invoice recognition — extract invoice/warranty card info
/// 4. Smart category suggestion — AI-powered category prediction
/// 5. Price trend prediction — depreciation and value forecasting
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

  /// 发票OCR识别提示词
  static const String _invoiceOcrPrompt = '''
You are an invoice OCR assistant. Extract key information from this invoice/receipt image.

Return a JSON object with the following structure:
{
  "merchant": "商家名称",
  "date": "YYYY-MM-DD 格式的日期",
  "amount": 金额数字（不含货币符号）,
  "itemName": "商品名称",
  "invoiceNumber": "发票号码",
  "taxAmount": 税额（可选）
}

Rules:
- Extract only visible information
- Leave uncertain fields as null or empty string
- Return ONLY the JSON object, no additional explanation
''';

  /// 识别发票信息
  Future<OcrResult> recognizeInvoice(List<int> imageBytes, {String locale = 'zh'}) async {
    final config = await _getConfig();
    
    if (config.aiApiKey.isEmpty) {
      return OcrResult(error: t('ai.errNoApiKey', locale));
    }

    try {
      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final base64Image = base64Encode(imageBytes);

      final response = await _retryPost(
        url,
        options: Options(headers: await _headers()),
        data: {
          'model': config.aiModel,
          'messages': [
            {
              'role': 'system',
              'content': _invoiceOcrPrompt,
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
          'temperature': 0.1,
        },
      );

      final content = _parseResponseContent(response.data);
      if (content == null || content.isEmpty) {
        return OcrResult(error: t('ai.testFailed', locale));
      }

      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return OcrResult.fromJson(data);
      }

      return OcrResult(error: t('ai.testFailed', locale));
    } catch (e) {
      return OcrResult(error: '${t('ai.testFailed', locale)}: $e');
    }
  }

  /// 保修卡OCR识别提示词
  static const String _warrantyOcrPrompt = '''
You are a warranty card OCR assistant. Extract key information from this warranty card image.

Return a JSON object with the following structure:
{
  "productName": "产品名称",
  "serialNumber": "序列号",
  "purchaseDate": "YYYY-MM-DD 格式的购买日期",
  "warrantyPeriod": "保修期限（如：2年、12个月）",
  "warrantyExpiry": "YYYY-MM-DD 格式的保修到期日期",
  "warrantyScope": "保修范围描述",
  "seller": "销售商名称"
}

Rules:
- Extract only visible information
- Leave uncertain fields as null or empty string
- Return ONLY the JSON object, no additional explanation
''';

  /// 识别保修卡信息
  Future<OcrResult> recognizeWarrantyCard(List<int> imageBytes, {String locale = 'zh'}) async {
    final config = await _getConfig();
    
    if (config.aiApiKey.isEmpty) {
      return OcrResult(error: t('ai.errNoApiKey', locale));
    }

    try {
      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final base64Image = base64Encode(imageBytes);

      final response = await _retryPost(
        url,
        options: Options(headers: await _headers()),
        data: {
          'model': config.aiModel,
          'messages': [
            {
              'role': 'system',
              'content': _warrantyOcrPrompt,
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
          'temperature': 0.1,
        },
      );

      final content = _parseResponseContent(response.data);
      if (content == null || content.isEmpty) {
        return OcrResult(error: t('ai.testFailed', locale));
      }

      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return OcrResult.fromJson(data);
      }

      return OcrResult(error: t('ai.testFailed', locale));
    } catch (e) {
      return OcrResult(error: '${t('ai.testFailed', locale)}: $e');
    }
  }

  /// 智能分类建议提示词
  static const String _categorySuggestionPrompt = '''
You are a product categorization expert. Suggest the best category for a given item name.

Available categories:
- electronics: 电子产品（手机、电脑、家电等）
- clothing: 服装鞋帽（衣服、鞋子、帽子等）
- food: 食品饮料（食品、饮料、零食等）
- home: 家居用品（家具、厨具、日用品等）
- books: 图书教育（书籍、文具、学习用品等）
- sports: 运动户外（运动器材、户外装备等）
- beauty: 美妆护肤（化妆品、护肤品等）
- transport: 交通工具（汽车配件、自行车等）
- medical: 医疗健康（药品、保健品、医疗设备等）
- gifts: 礼品玩具（礼品、玩具等）
- pets: 宠物用品（宠物食品、用品等）
- other: 其他（不属于以上分类的物品）

Return a JSON object with the following structure:
{
  "categoryId": "分类ID（如 electronics）",
  "categoryName": "分类名称（中文）",
  "confidence": 置信度（0-1之间的小数）,
  "reason": "分类理由"
}

Rules:
- Confidence should reflect how certain you are about the categorization
- Return ONLY the JSON object, no additional explanation
''';

  /// 智能分类建议
  Future<CategorySuggestion> suggestCategory(String itemName, {String locale = 'zh'}) async {
    final config = await _getConfig();
    
    if (config.aiApiKey.isEmpty) {
      return CategorySuggestion(
        categoryId: 'other',
        categoryName: locale == 'zh' ? '其他' : 'Other',
        confidence: 0.5,
        reason: '',
      );
    }

    try {
      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');

      final response = await _dio.post(
        url,
        options: Options(headers: await _headers()),
        data: {
          'model': config.aiModel,
          'messages': [
            {
              'role': 'system',
              'content': _categorySuggestionPrompt,
            },
            {
              'role': 'user',
              'content': 'Item: $itemName',
            },
          ],
          'max_tokens': config.aiMaxTokens,
          'temperature': 0.1,
        },
      );

      final content = _parseResponseContent(response.data);
      if (content == null || content.isEmpty) {
        return CategorySuggestion(
          categoryId: 'other',
          categoryName: locale == 'zh' ? '其他' : 'Other',
          confidence: 0.5,
          reason: '',
        );
      }

      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        return CategorySuggestion.fromJson(data);
      }

      return CategorySuggestion(
        categoryId: 'other',
        categoryName: locale == 'zh' ? '其他' : 'Other',
        confidence: 0.5,
        reason: '',
      );
    } catch (_) {
      return CategorySuggestion(
        categoryId: 'other',
        categoryName: locale == 'zh' ? '其他' : 'Other',
        confidence: 0.5,
        reason: '',
      );
    }
  }

  /// 价格预测提示词
  static const String _pricePredictionPrompt = '''
You are a price prediction expert for consumer electronics and household items.

Given an item name, original price, and purchase date, predict its current value, depreciation rate, and future value trend.

Return a JSON object with the following structure:
{
  "currentValue": 当前价值（数字）,
  "depreciationRate": 年折旧率（0-1之间的小数）,
  "futureValues": [
    {"date": "YYYY-MM-DD", "value": 价值},
    {"date": "YYYY-MM-DD", "value": 价值},
    {"date": "YYYY-MM-DD", "value": 价值}
  ],
  "bestSellDate": "最佳出售日期（YYYY-MM-DD格式，可选）",
  "notes": "备注说明"
}

Rules:
- Use realistic depreciation curves based on product category
- For electronics: faster depreciation in first year, slows down
- For durable goods: more linear depreciation
- futureValues should include predictions for next 6 months, 1 year, 2 years
- Return ONLY the JSON object, no additional explanation
''';

  /// 价格趋势预测
  Future<PricePrediction> predictPrice(
    String itemName,
    double originalPrice,
    DateTime purchaseDate, {
    String locale = 'zh',
  }) async {
    final config = await _getConfig();
    
    if (config.aiApiKey.isEmpty) {
      return _calculateDefaultPrediction(itemName, originalPrice, purchaseDate);
    }

    try {
      final url = _buildUrl(config.aiBaseUrl, '/chat/completions');
      final purchaseDateStr = purchaseDate.toIso8601String().split('T')[0];

      final response = await _dio.post(
        url,
        options: Options(headers: await _headers()),
        data: {
          'model': config.aiModel,
          'messages': [
            {
              'role': 'system',
              'content': _pricePredictionPrompt,
            },
            {
              'role': 'user',
              'content': 'Item: $itemName, Price: $originalPrice, Purchase Date: $purchaseDateStr',
            },
          ],
          'max_tokens': config.aiMaxTokens,
          'temperature': 0.3,
        },
      );

      final content = _parseResponseContent(response.data);
      if (content == null || content.isEmpty) {
        return _calculateDefaultPrediction(itemName, originalPrice, purchaseDate);
      }

      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final prediction = PricePrediction.fromJson(data);
        if (prediction.currentValue > 0) {
          return prediction;
        }
      }

      return _calculateDefaultPrediction(itemName, originalPrice, purchaseDate);
    } catch (_) {
      return _calculateDefaultPrediction(itemName, originalPrice, purchaseDate);
    }
  }

  /// 默认价格预测计算（当AI不可用时使用）
  PricePrediction _calculateDefaultPrediction(
    String itemName,
    double originalPrice,
    DateTime purchaseDate,
  ) {
    final now = DateTime.now();
    final ageDays = now.difference(purchaseDate).inDays;
    final ageYears = ageDays / 365;

    double depreciationRate;
    if (itemName.toLowerCase().contains(RegExp(r'phone|mobile|iphone|手机')) ||
        itemName.toLowerCase().contains(RegExp(r'laptop|computer|notebook|电脑'))) {
      depreciationRate = 0.35;
    } else if (itemName.toLowerCase().contains(RegExp(r'camera|相机|watch|手表'))) {
      depreciationRate = 0.25;
    } else {
      depreciationRate = 0.15;
    }

    final currentValue = originalPrice * pow(1 - depreciationRate, ageYears).toDouble();
    final clampedValue = currentValue > 0 ? currentValue : originalPrice * 0.1;

    final futureValues = <PricePoint>[];
    final dates = [
      now.add(const Duration(days: 180)),
      now.add(const Duration(days: 365)),
      now.add(const Duration(days: 730)),
    ];
    for (final date in dates) {
      final futureAgeYears = date.difference(purchaseDate).inDays / 365;
      final futureValue = originalPrice * pow(1 - depreciationRate, futureAgeYears).toDouble();
      futureValues.add(PricePoint(
        date: date,
        value: futureValue > 0 ? futureValue : originalPrice * 0.05,
      ));
    }

    return PricePrediction(
      currentValue: clampedValue,
      depreciationRate: depreciationRate,
      futureValues: futureValues,
      notes: '使用默认折旧模型计算',
    );
  }
}

/// OCR识别结果
class OcrResult {
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final String? itemName;
  final String? invoiceNumber;
  final double? taxAmount;
  final String? productName;
  final String? serialNumber;
  final String? warrantyPeriod;
  final DateTime? warrantyExpiry;
  final String? warrantyScope;
  final String? seller;
  final String? error;

  OcrResult({
    this.merchant,
    this.date,
    this.amount,
    this.itemName,
    this.invoiceNumber,
    this.taxAmount,
    this.productName,
    this.serialNumber,
    this.warrantyPeriod,
    this.warrantyExpiry,
    this.warrantyScope,
    this.seller,
    this.error,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }

    return OcrResult(
      merchant: json['merchant'] as String?,
      date: parseDate(json['date'] as String?),
      amount: (json['amount'] as num?)?.toDouble(),
      itemName: json['itemName'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      productName: json['productName'] as String?,
      serialNumber: json['serialNumber'] as String?,
      warrantyPeriod: json['warrantyPeriod'] as String?,
      warrantyExpiry: parseDate(json['warrantyExpiry'] as String?),
      warrantyScope: json['warrantyScope'] as String?,
      seller: json['seller'] as String?,
    );
  }
}

/// 分类建议
class CategorySuggestion {
  final String categoryId;
  final String categoryName;
  final double confidence;
  final String reason;

  CategorySuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.confidence,
    required this.reason,
  });

  factory CategorySuggestion.fromJson(Map<String, dynamic> json) {
    return CategorySuggestion(
      categoryId: json['categoryId'] as String? ?? 'other',
      categoryName: json['categoryName'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      reason: json['reason'] as String? ?? '',
    );
  }
}

/// 价格预测
class PricePrediction {
  final double currentValue;
  final double depreciationRate;
  final List<PricePoint> futureValues;
  final DateTime? bestSellDate;
  final String? notes;

  PricePrediction({
    required this.currentValue,
    required this.depreciationRate,
    required this.futureValues,
    this.bestSellDate,
    this.notes,
  });

  factory PricePrediction.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }

    final futureValuesJson = json['futureValues'] as List? ?? [];
    final futureValues = futureValuesJson
        .map((e) => PricePoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return PricePrediction(
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      depreciationRate: (json['depreciationRate'] as num?)?.toDouble() ?? 0.15,
      futureValues: futureValues,
      bestSellDate: parseDate(json['bestSellDate'] as String?),
      notes: json['notes'] as String?,
    );
  }
}

/// 价格点
class PricePoint {
  final DateTime date;
  final double value;

  PricePoint({
    required this.date,
    required this.value,
  });

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}