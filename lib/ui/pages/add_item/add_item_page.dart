import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/database/asset_dao.dart';
import '../../../data/database/category_dao.dart';
import '../../../data/models/asset_item.dart';
import '../../../data/models/category.dart';
import '../../../services/ai_service.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_toast.dart';

/// 添加/编辑物品页面
class AddItemPage extends ConsumerStatefulWidget {
  final AssetItem? editItem;

  const AddItemPage({super.key, this.editItem});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  // AI 识别相关
  final AiService _aiService = AiService();
  File? _screenshotFile;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _aiResult;

  // 多物品逐件保存
  List<Map<String, dynamic>> _pendingItems = [];
  int _currentItemIndex = 0;

  DateTime _purchaseDate = DateTime.now();
  String _selectedCategory = '其他';
  int _plannedLifetimeDays = 365;
  String _lifetimeUnit = 'days';
  int _rating = 0;

  // 保修与保险
  final _warrantyController = TextEditingController();
  DateTime? _warrantyExpiry;
  final _insuranceController = TextEditingController();
  bool _warrantyExpanded = false;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      _isEditing = true;
      final item = widget.editItem!;
      _nameController.text = item.name;
      _brandController.text = item.brand;
      _priceController.text = item.price.toString();
      _notesController.text = item.notes;
      _purchaseDate = item.purchaseDate ?? DateTime.now();
      _selectedCategory = item.category;
      _plannedLifetimeDays = item.plannedLifetimeDays;
      _rating = item.rating;
      if (item.screenshotPath.isNotEmpty) {
        _screenshotFile = File(item.screenshotPath);
      }
      if (item.warrantyPeriod != null) {
        _warrantyController.text = item.warrantyPeriod!;
        _warrantyExpiry = item.warrantyExpiry;
        _warrantyExpanded = true;
      }
      if (item.insuranceInfo != null) {
        _insuranceController.text = item.insuranceInfo!;
        _warrantyExpanded = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _warrantyController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoryListProvider);

        return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? t('edit.title', ref.read(localeCodeProvider)) : t('add.title', ref.read(localeCodeProvider))),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: _pickScreenshot,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_search),
              label: Text(
                _isAnalyzing ? t('add.aiRecognizing', ref.read(localeCodeProvider)) : t('add.aiRecognize', ref.read(localeCodeProvider)),
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI 识别结果提示
            if (_aiResult != null && _aiResult!['error'] == null)
              _buildAiResultBanner(),

            // 物品名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('add.name', ref.read(localeCodeProvider)),
                hintText: t('add.nameHint', ref.read(localeCodeProvider)),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? t('add.nameRequired', ref.read(localeCodeProvider)) : null,
            ),
            const SizedBox(height: 16),

            // 品牌 + 价格
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: InputDecoration(
                      labelText: t('add.brand', ref.read(localeCodeProvider)),
                      hintText: t('add.brandHint', ref.read(localeCodeProvider)),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: t('add.price', ref.read(localeCodeProvider)),
                      hintText: t('add.priceHint', ref.read(localeCodeProvider)),
                      prefixIcon: Icon(Icons.monetization_on),
                      prefixText: '¥ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return t('add.priceRequired', ref.read(localeCodeProvider));
                      if (double.tryParse(v) == null) return t('add.priceInvalid', ref.read(localeCodeProvider));
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 分类选择
            categoriesAsync.when(
              data: (categories) => _buildCategorySelector(categories),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(t('error.loadFailed', ref.read(localeCodeProvider))),
            ),
            const SizedBox(height: 16),

            // 购买日期
            _buildDatePicker(),
            const SizedBox(height: 16),

            // 计划使用天数
            _buildLifetimeSelector(),
            const SizedBox(height: 16),

            // 评分
            _buildRatingSelector(),
            const SizedBox(height: 16),

            // 备注
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: t('add.notes', ref.read(localeCodeProvider)),
                hintText: t('add.notesHint', ref.read(localeCodeProvider)),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 保修与保险（选填可折叠）
            _buildWarrantySection(),
            const SizedBox(height: 32),

            // 提交按钮
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isEditing ? t('add.saveEdit', ref.read(localeCodeProvider))
                    : _pendingItems.length > 1
                        ? '${t('add.submit', ref.read(localeCodeProvider))} (${_currentItemIndex + 1}/${_pendingItems.length})'
                        : t('add.submit', ref.read(localeCodeProvider)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (_pendingItems.length > 1) ...[const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _skipCurrentItem,
                  icon: const Icon(Icons.skip_next),
                  label: Text(t('add.skip', ref.read(localeCodeProvider)).replaceAll('{n}', '${_pendingItems.length - _currentItemIndex - 1}')),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 截图预览
  Widget _buildScreenshotPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.file(
              _screenshotFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _screenshotFile = null;
                    _aiResult = null;
                  });
                },
                icon: const Icon(Icons.close, size: 16),
                label: Text(t('edit.remove', ref.read(localeCodeProvider))),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// AI 识别结果
  Widget _buildAiResultBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t('add.aiDetected', ref.read(localeCodeProvider)),
              style: TextStyle(color: Colors.green[800]),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _aiResult = null),
            child: Text(t('add.aiDismiss', ref.read(localeCodeProvider))),
          ),
        ],
      ),
    );
  }

  /// 分类选择器
  Widget _buildCategorySelector(List<CategoryItem> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('add.category', ref.read(localeCodeProvider)),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat.name;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.categoryIcon(cat.icon, cat.colorHex, size: 16),
                  const SizedBox(width: 8),
                  Text(cat.isPreset ? t(AppConstants.getCategoryNameKey(cat.name), ref.read(localeCodeProvider)) : cat.name),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.fromHex(cat.colorHex).withOpacity(0.2),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategory = cat.name);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 日期选择器
  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t('add.purchaseDate', ref.read(localeCodeProvider)),
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(AppDateUtils.formatCn(_purchaseDate)),
      ),
    );
  }

  /// 计划使用天数选择
  Widget _buildLifetimeSelector() {
    final presets = [
      {'key': 'lifetime.3m', 'days': 90},
      {'key': 'lifetime.6m', 'days': 180},
      {'key': 'lifetime.1y', 'days': 365},
      {'key': 'lifetime.2y', 'days': 730},
      {'key': 'lifetime.3y', 'days': 1095},
      {'key': 'lifetime.5y', 'days': 1825},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('add.lifetime', ref.read(localeCodeProvider)),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final days = preset['days'] as int;
            final isSelected = _plannedLifetimeDays == days;
            return ChoiceChip(
              label: Text(t(preset['key'] as String, ref.read(localeCodeProvider))),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _plannedLifetimeDays = days);
                }
              },
            );
          }).toList(),
        ),
        // 自定义输入
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: _plannedLifetimeDays.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  labelText: t('add.customLifetime', ref.read(localeCodeProvider)),
                ),
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 0) {
                    setState(() => _plannedLifetimeDays = _toDays(val, _lifetimeUnit));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _lifetimeUnit,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'days', child: Text(t('add.days', ref.read(localeCodeProvider)))),
                DropdownMenuItem(value: 'weeks', child: Text(t('add.weeks', ref.read(localeCodeProvider)))),
                DropdownMenuItem(value: 'months', child: Text(t('add.months', ref.read(localeCodeProvider)))),
                DropdownMenuItem(value: 'years', child: Text(t('add.years', ref.read(localeCodeProvider)))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _lifetimeUnit = v);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  int _toDays(int value, String unit) {
    switch (unit) {
      case 'weeks': return value * 7;
      case 'months': return value * 30;
      case 'years': return value * 365;
      default: return value;
    }
  }

  /// 评分选择
  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('add.rating', ref.read(localeCodeProvider)),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            return IconButton(
              onPressed: () => setState(() => _rating = star),
              icon: Icon(
                star <= _rating ? Icons.star : Icons.star_border,
                color: star <= _rating ? Colors.amber : null,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 保修与保险输入区域（可折叠）
  Widget _buildWarrantySection() {
    final loc = ref.read(localeCodeProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _warrantyExpanded = !_warrantyExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(t('add.warrantySection', ref.read(localeCodeProvider)), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _warrantyExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // 保修期限
                  Text(t('add.warrantyPeriod', loc), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      t('lifetime.1y', loc), t('lifetime.2y', loc), t('lifetime.3y', loc), t('add.warrantyPeriod', loc).split(' ')[0]
                    ].map((label) {
                      final isSelected = _warrantyController.text == label;
                      return ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 13)),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        onSelected: (_) {
                          setState(() => _warrantyController.text = label);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _warrantyController,
                    decoration: const InputDecoration(
                      hintText: '自定义保修期限',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 保修到期
                  InkWell(
                    onTap: _pickWarrantyExpiry,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '保修到期（选填）',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                        isDense: true,
                      ),
                      child: Text(
                        _warrantyExpiry != null
                            ? '${_warrantyExpiry!.year}-${_padWarranty(_warrantyExpiry!.month)}-${_padWarranty(_warrantyExpiry!.day)}'
                            : '选择日期',
                        style: TextStyle(color: _warrantyExpiry != null ? null : Colors.grey),
                      ),
                    ),
                  ),
                  if (_warrantyExpiry != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _warrantyExpiry = null),
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('清除日期', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                    ),
                  const SizedBox(height: 16),

                  // 保险信息
                  TextField(
                    controller: _insuranceController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: '保险信息（选填）',
                      hintText: '保险公司、保单号等',
                      prefixIcon: Icon(Icons.security, size: 20),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            crossFadeState: _warrantyExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _padWarranty(int n) => n.toString().padLeft(2, '0');

  /// 选择保修到期日期
  Future<void> _pickWarrantyExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyExpiry ?? _purchaseDate.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh'),
    );
    if (picked != null) setState(() => _warrantyExpiry = picked);
  }

  /// 选择日期
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('zh'),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  /// 选择截图
  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('add.imageSource', ref.read(localeCodeProvider))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(t('add.camera', ref.read(localeCodeProvider))),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(t('add.gallery', ref.read(localeCodeProvider))),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (picked != null) {
      setState(() {
        _screenshotFile = File(picked.path);
        _isAnalyzing = true;
      });

      // 调用 AI 识别（带30秒超时）
      final bytes = await _screenshotFile!.readAsBytes();
      final items = await _aiService.recognizeFromScreenshot(
        bytes,
        fileName: picked.name,
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        return [{'error': t('add.aiTimeout', ref.read(localeCodeProvider))}];
      });

      setState(() {
        _isAnalyzing = false;
        _aiResult = null;
      });

      if (items.isEmpty || items.first['error'] != null) {
        final errMsg = items.isNotEmpty
            ? items.first['error']?.toString() ?? t('add.aiFailed', ref.read(localeCodeProvider))
            : t('add.aiFailed', ref.read(localeCodeProvider));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $errMsg'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      setState(() {
        _pendingItems = items;
        _currentItemIndex = 0;
      });
      _fillFormWithItem(items[0]);

      if (mounted && items.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('add.aiDetectedN', ref.read(localeCodeProvider)).replaceAll('{n}', '${items.length}')}，${t('add.continue_', ref.read(localeCodeProvider)).replaceAll('{i}', '1').replaceAll('{n}', '${items.length}')}'),
            backgroundColor: Colors.green, duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 用 AI 识别结果填充表单
  void _fillFormWithItem(Map<String, dynamic> data) {
    if (data['name'] != null && data['name'].toString().isNotEmpty) {
      _nameController.text = data['name'].toString();
    }
    if (data['brand'] != null && data['brand'].toString().isNotEmpty) {
      _brandController.text = data['brand'].toString();
    }
    if (data['price'] != null) {
      final p = data['price'];
      _priceController.text = p is num ? p.toString() : p.toString();
    }
    if (data['category'] != null && data['category'].toString().isNotEmpty) {
      _selectedCategory = data['category'].toString();
    }
    if (data['purchaseDate'] != null && data['purchaseDate'].toString().isNotEmpty) {
      try { _purchaseDate = DateTime.parse(data['purchaseDate'].toString()); } catch (_) {}
    }
    if (data['tags'] != null && data['tags'] is List) {
      _notesController.text = '标签: ${(data['tags'] as List).join(', ')}';
    }
    setState(() {});
  }

  /// 跳过当前物品，进入下一个
  void _skipCurrentItem() {
    _advanceToNext();
  }

  /// 静默 AI 增强（后台更新物品标签/分类，不影响用户）
  Future<void> _tryEnrich(AssetItem saved) async {
    try {
      final enriched = await _aiService.enrichItemInfo({
        'name': saved.name,
        'category': saved.category,
        'brand': saved.brand,
        'price': saved.price,
      });
      if (enriched['category'] != null && enriched['category'] != saved.category ||
          enriched['tags'] != null || enriched['suggestions'] != null) {
        // 有增强结果才更新
        final updatedTags = enriched['tags'] is List
            ? (enriched['tags'] as List).cast<String>()
            : null;
        final suggestion = enriched['suggestions'] as String? ?? '';
        final enhancedNotes = suggestion.isNotEmpty
            ? '${saved.notes}${saved.notes.isNotEmpty ? '\n' : ''}[AI建议] $suggestion'
            : saved.notes;
        if (updatedTags != null || suggestion.isNotEmpty ||
            (enriched['category'] != null && enriched['category'] != saved.category)) {
          final dao = ref.read(assetDaoProvider);
          await dao.update(saved.copyWith(
            category: enriched['category'] is String ? enriched['category'] as String : null,
            tags: updatedTags,
            notes: suggestion.isNotEmpty ? enhancedNotes : null,
          ));
        }
      }
    } catch (_) {
      // 静默失败
    }
  }

  /// 进入下一个物品（或完成）
  void _advanceToNext() {
    final next = _currentItemIndex + 1;
    if (next >= _pendingItems.length) {
      // 全部处理完毕
      _pendingItems = [];
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() => _currentItemIndex = next);
    _fillFormWithItem(_pendingItems[next]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('add.confirmSaveN', ref.read(localeCodeProvider)).replaceAll('{current}', '${next + 1}').replaceAll('{total}', '${_pendingItems.length}')),
          backgroundColor: Colors.blue, duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 提交表单
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    final dao = ref.read(assetDaoProvider);

    if (_isEditing && widget.editItem != null) {
      final wp = _warrantyController.text.trim();
      final ins = _insuranceController.text.trim();
      final updated = widget.editItem!.copyWith(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        price: price,
        purchaseDate: _purchaseDate,
        category: _selectedCategory,
        notes: _notesController.text.trim(),
        plannedLifetimeDays: _plannedLifetimeDays,
        rating: _rating,
        screenshotPath: _screenshotFile?.path ?? widget.editItem!.screenshotPath,
        warrantyPeriod: wp.isNotEmpty ? wp : null,
        warrantyExpiry: _warrantyExpiry,
        insuranceInfo: ins.isNotEmpty ? ins : null,
      );
      await dao.update(updated);
      if (mounted) {
        AppToast.capsule(context, '已更新', Colors.green);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
      return;
    }

    // 多物品逐件保存
    if (_pendingItems.isNotEmpty) {
      final wp = _warrantyController.text.trim();
      final ins = _insuranceController.text.trim();
      final data = _pendingItems[_currentItemIndex];
      final item = AssetItem.create(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        price: price,
        purchaseDate: _purchaseDate,
        category: _selectedCategory,
        notes: _notesController.text.trim(),
        plannedLifetimeDays: _plannedLifetimeDays,
        rating: _rating,
        screenshotPath: _screenshotFile?.path ?? '',
        aiRawData: _pendingItems.length > 1 ? '共${_pendingItems.length}件，第${_currentItemIndex + 1}件' : '',
        warrantyPeriod: wp.isNotEmpty ? wp : null,
        warrantyExpiry: _warrantyExpiry,
        insuranceInfo: ins.isNotEmpty ? ins : null,
      );
      await dao.add(item);
      AppToast.capsule(context, '已添加 (${_currentItemIndex + 1}/${_pendingItems.length})', Colors.green);
      _advanceToNext();
      return;
    }

    // 单件手动添加
    final wp = _warrantyController.text.trim();
    final ins = _insuranceController.text.trim();
    final item = AssetItem.create(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      price: price,
      purchaseDate: _purchaseDate,
      category: _selectedCategory,
      notes: _notesController.text.trim(),
      plannedLifetimeDays: _plannedLifetimeDays,
      rating: _rating,
      screenshotPath: _screenshotFile?.path ?? '',
      aiRawData: _aiResult != null ? _aiResult.toString() : '',
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    final saved = await dao.add(item);
    // 静默调用 AI 增强（后台更新，不影响用户）
    _tryEnrich(saved);
    if (mounted) {
      AppToast.capsule(context, '已添加', Colors.green);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }
}
