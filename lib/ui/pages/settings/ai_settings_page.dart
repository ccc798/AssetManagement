import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../data/database/config_dao.dart';
import '../../../data/models/backup_config.dart';
import '../../../services/ai_service.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_toast.dart';

/// AI 智能识别设置页面
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _maxTokensController = TextEditingController();
  bool _isTesting = false;
  final ConfigDao _configDao = ConfigDao();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _configDao.getConfig();
    _baseUrlController.text = config.aiBaseUrl;
    _apiKeyController.text = config.aiApiKey;
    _modelController.text = config.aiModel;
    _maxTokensController.text = config.aiMaxTokens.toString();
    setState(() {});
  }

  Future<void> _save() async {
    final existing = await _configDao.getConfig();
    final config = existing.copyWith(
      aiBaseUrl: _baseUrlController.text.trim().isEmpty
          ? 'https://api.openai.com/v1'
          : _baseUrlController.text.trim(),
      aiApiKey: _apiKeyController.text.trim(),
      aiModel: _modelController.text.trim().isEmpty
          ? 'gpt-4o-mini'
          : _modelController.text.trim(),
      aiMaxTokens: int.tryParse(_maxTokensController.text) ?? 4096,
    );
    await _configDao.saveConfig(config);
    ref.refresh(configProvider);
    if (mounted) {
      AppToast.capsule(context, t('toast.saved', ref.read(localeCodeProvider)), Colors.green);
    }
  }

  /// 保存但不弹出提示（用于测试前静默保存）
  Future<void> _saveSilent() async {
    final existing = await _configDao.getConfig();
    final config = existing.copyWith(
      aiBaseUrl: _baseUrlController.text.trim().isEmpty
          ? 'https://api.openai.com/v1'
          : _baseUrlController.text.trim(),
      aiApiKey: _apiKeyController.text.trim(),
      aiModel: _modelController.text.trim().isEmpty
          ? 'gpt-4o-mini'
          : _modelController.text.trim(),
      aiMaxTokens: int.tryParse(_maxTokensController.text) ?? 4096,
    );
    await _configDao.saveConfig(config);
    ref.refresh(configProvider);
  }

  Future<void> _test() async {
    setState(() => _isTesting = true);
    AppToast.loading(context, t('ai.testLoading', ref.read(localeCodeProvider)));
    await _saveSilent();

    final error = await AiService().testConnection();
    AppToast.dismiss(context);
    setState(() => _isTesting = false);

    if (!mounted) return;

    if (error == null) {
      AppToast.bottom(context, '✅ ${t('ai.testSuccess', ref.read(localeCodeProvider))}', Colors.green);
    } else if (error.contains('400') || error.contains('not support') || error.contains('不支持')) {
      AppToast.bottom(
        context,
        t('ai.testVisionWarning', ref.read(localeCodeProvider)).replaceAll('{error}', error),
        Colors.orange,
        seconds: 5,
      );
    } else {
      AppToast.bottom(context, '❌ $error', Colors.red, seconds: 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc2 = ref.read(localeCodeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('ai.title', loc2)),
        actions: [
          TextButton(onPressed: _save, child: Text(t('ai.save', loc2))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: InputDecoration(
                      labelText: t('ai.baseUrl', loc2),
                      hintText: 'https://api.openai.com/v1',
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: t('ai.apiKey', loc2),
                      hintText: 'sk-...',
                      prefixIcon: Icon(Icons.key),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: t('ai.model', loc2),
                      hintText: 'gpt-4o-mini',
                      prefixIcon: const Icon(Icons.model_training),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _maxTokensController,
                    decoration: InputDecoration(
                      labelText: t('ai.maxTokens', loc2),
                      hintText: '4096',
                      prefixIcon: const Icon(Icons.memory),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _test,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_isTesting ? t('ai.testing', loc2) : t('ai.test', loc2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
