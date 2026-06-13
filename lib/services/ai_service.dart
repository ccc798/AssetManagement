import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/i18n/translations.dart';
import '../data/database/config_dao.dart';
import '../data/models/backup_config.dart';

/// AI 鏈嶅姟 鈥?閫氱敤 OpenAI 鍏煎鎺ュ彛
///
/// 鏀寔:
/// 1. 鎴浘璇嗗埆 (瑙嗚) 鈫?鎻愬彇鐗╁搧淇℃伅
/// 2. 鏁版嵁鏁寸悊 (鏂囨湰) 鈫?缁撴瀯鍖?鍒嗙被/鏍囩寤鸿
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

  /// 鑾峰彇褰撳墠 AI 閰嶇疆
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
  }) async {
    final config = await _getConfig();
    if (config.aiApiKey.isEmpty) {
      return [{'error': '璇峰厛鍦ㄨ缃腑閰嶇疆 AI API Key'}];
    }

    // 将图片转为 Base64
    final base64Image = base64Encode(imageBytes);

    final url = _buildUrl(config.aiBaseUrl, '/chat/completions');

    final prompt = '''
浣犳槸涓€涓喘鐗╄鍗曟埅鍥捐瘑鍒姪鎵嬨€傝璇嗗埆杩欏紶鎴浘涓殑鎵€鏈夌墿鍝佷俊鎭€?
娉ㄦ剰锛氫竴涓鍗曚腑鍙兘鍖呭惈澶氫欢鐗╁搧锛岃閫愪竴鍒楀嚭姣忎欢鐗╁搧銆?
浠?JSON 鏁扮粍鏍煎紡杩斿洖锛屾暟缁勪腑鐨勬瘡涓厓绱犱唬琛ㄤ竴浠剁墿鍝侊細

[
  {
    "name": "鐗╁搧鍚嶇О锛堝繀椤伙級",
    "category": "鍒嗙被锛堢數瀛愪骇鍝?鏈嶈闉嬪附/椋熷搧楗枡/瀹跺眳鐢ㄥ搧/鍥句功鏁欒偛/杩愬姩鎴峰/缇庡鎶よ偆/浜ら€氬伐鍏?鍖荤枟鍋ュ悍/绀煎搧鐜╁叿/瀹犵墿鐢ㄥ搧/鍏朵粬锛?,
    "brand": "鍝佺墝",
    "price": 瀹為檯鏀粯浠锋牸锛堢函鏁板瓧锛屼笉瑕佽揣甯佺鍙凤級,
    "quantity": 鏁伴噺锛堥粯璁?锛?
    "purchaseDate": "璐拱鏃ユ湡锛堟牸寮?YYYY-MM-DD锛?,
    "tags": ["鏍囩1", "鏍囩2"]
  }
]

閲嶈 鈥斺€?浠锋牸鎻愬彇瑙勫垯锛?1. 璐墿鎴浘涓婇€氬父鏈夊涓噾棰濓細鍘熶环銆佹姌鎵ｄ环銆佹弧鍑忎环銆佹渶缁堟敮浠樹环绛夈€?2. 璇蜂娇鐢ㄣ€屽疄闄呮敮浠?瀹炰粯/瀹炰粯娆?瀹炰粯閲戦/璁㈠崟鎬讳环/鍚堣/瀹炴敹/鏀粯閲戦/鏈€缁堜环鏍笺€嶅搴旂殑閲戦銆?3. 涓嶈浣跨敤銆屽師浠?鍒掔嚎浠?鍚婄墝浠?寤鸿闆跺敭浠枫€嶃€?4. 涓嶈浣跨敤銆屼紭鎯?绔嬪噺/鐪佷簡/宸蹭紭鎯?鎶樻墸閲戦銆嶏紙杩欎簺鏄渷浜嗗灏戦挶锛屼笉鏄敮浠橀噾棰濓級銆?5. 濡傛灉鐪嬪埌銆屄x 鍒版墜浠?鍒稿悗浠?娲诲姩浠?淇冮攢浠枫€嶏紝浼樺厛浣跨敤杩欎釜閲戦銆?6. 澶氫欢鍟嗗搧鐨勭壒娈婃儏鍐碉紙濡傛窐瀹?浜笢璁㈠崟锛夛細
   a) 姣忎釜鍟嗗搧鏃佽竟鏄剧ず鐨勬槸璇ュ晢鍝佽嚜宸辩殑浠锋牸锛堝崟鍝佸疄浠樹环锛夛紝搴斿垎鍒彁鍙栦负姣忎釜鐗╁搧鐨?price銆?   b) 椤甸潰搴曢儴鐨勩€屽疄浠樻/瀹炰粯鍚堣/璁㈠崟鎬讳环銆嶆槸鏁寸瑪璁㈠崟鐨勬€婚噾棰濓紝涓嶈鐢ㄦ€婚噾棰濋櫎浠ユ暟閲忋€?   c) 鍗充娇澶氫釜鍟嗗搧锛屻€屼笉瑕佷娇鐢ㄣ€嶇殑瀛楁锛堝師浠风瓑锛変粛鐒跺簲璇ヨ蹇界暐銆?   d) 浼樺厛鎵惧埌姣忎欢鍟嗗搧鑷繁鐨勪环鏍兼爣绛撅紝涓嶄緷璧栨€荤殑銆屽疄浠樻銆嶃€?7. 濡傛灉纭疄鍙湁璁㈠崟鎬讳环娌℃湁鍗曞搧浠凤紝price 濉€屾€讳环/鏁伴噺銆嶇殑浼扮畻鍊硷紝骞跺湪 tags 涓坊鍔犮€屼及绠椼€嶃€?
鍏朵粬瑕佹眰锛?- 濡傛灉鍙湁涓€浠剁墿鍝侊紝涔熻繑鍥炲寘鍚竴涓厓绱犵殑鏁扮粍
- 濡傛灉鏈夊涓墿鍝侊紙濡備竴绗旇鍗曚拱浜嗘墜鏈哄拰鑰虫満锛夛紝姣忎欢鐗╁搧浣滀负涓€涓嫭绔嬪厓绱?- 鍚屼竴浠剁墿鍝佷拱澶氫釜锛堝3浠禩鎭わ級锛宷uantity 濉?锛宲rice 濉崟涓环鏍?- 鍙繑鍥?JSON 鏁扮粍锛屼笉瑕侀澶栬鏄庛€備笉纭畾鐨勫瓧娈靛啓绌哄瓧绗︿覆鎴?null銆?''';

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
        'error': '无法解析 AI 返回结果',
        'rawContent': content,
      }];
    } on DioException catch (e) {
      return [{
        'error': 'AI 请求失败: ${e.message}',
        'rawContent': e.response?.toString() ?? '',
      }];
    } catch (e) {
      return [{
        'error': '未知错误: $e',
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
浣犳槸涓€涓釜浜鸿祫浜х鐞嗗姪鎵嬨€傜敤鎴锋彁渚涗簡涓€涓墿鍝佺殑鍘熷淇℃伅锛岃琛ュ厖鍜屽畬鍠勫畠銆?
鍘熷淇℃伅:
${jsonEncode(itemInfo)}

璇疯繑鍥炶ˉ鍏呭悗鐨?JSON锛屽寘鍚互涓嬪瓧娈碉細
- name: 鐗╁搧鍚嶇О锛堣鑼冨懡鍚嶏級
- category: 鏈€鍚堥€傜殑鍒嗙被
- brand: 鍝佺墝
- tags: 寤鸿鐨勬爣绛炬暟缁勶紙3-5涓級
- suggestions: 浣跨敤寤鸿/淇濆吇寤鸿锛堜竴鍙ヨ瘽锛?
鍙繑鍥?JSON锛屼笉瑕侀澶栬鏄庛€?''';

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
              'content': '请帮我完善这条物品信息',
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

      // ---------- 绗竴姝ワ細鍩虹杩炴帴娴嬭瘯 ----------
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
        if (baseResp.statusCode == 401) return 'API Key 无效（401）';
        if (baseResp.statusCode == 404) return '接口地址不存在（404），请检查 API 地址';
        if (baseResp.statusCode == 429) return '请求过于频繁（429），请稍后重试';
        if (baseResp.statusCode == 500) return '服务器内部错误（500）';
        return 'HTTP ${baseResp.statusCode}';
      }

      // ---------- 绗簩姝ワ細澶氭ā鎬佸浘鐗囪瘑鍒祴璇?----------
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
                  {'type': 'text', 'text': '鎻忚堪杩欏紶鍥剧墖'},
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
          return '模型不支持图片识别（400），但仍可使用文字描述手动添加物品';
        }
        return '图片识别测试未通过（HTTP ${visionResp.statusCode}），但基础连接正常';
      } on DioException catch (e) {
        if (e.type == DioExceptionType.badResponse &&
            e.response?.statusCode == 400) {
          return '模型不支持图片识别（400），但仍可使用文字描述手动添加物品';
        }
        return '图片识别测试异常，但基础连接正常（实际截图识别可能可用）';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) return '连接超时，请检查网络';
      if (e.type == DioExceptionType.receiveTimeout) return '响应超时';
      if (e.type == DioExceptionType.connectionError) {
        if (e.message != null && e.message!.contains('Connection refused')) {
          return '连接被服务器拒绝。常见原因：1）运营商/网络防火墙拦截了该服务器 2）需通过代理/VPN访问 3）API地址或端口有误。建议切换WiFi/移动数据后重试';
        }
        return '无法连接服务器（${e.message}）';
      }
      if (e.type == DioExceptionType.badResponse) {
        final code = e.response?.statusCode;
        if (code == 400) return '请求格式错误（400），模型可能不支持图片识别';
        if (code == 401) return 'API Key 无效（401）';
        if (code == 404) return '接口地址不存在（404），请检查 API 地址';
        if (code == 429) return '请求过于频繁（429）';
        return '服务器错误 $code';
      }
      return '璇锋眰澶辫触: ${e.message}';
    } catch (e) {
      return '鏈煡閿欒: $e';
    }
  }
}
