import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/services/image_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/money_utils.dart';
import '../../../data/database/asset_dao.dart';
import '../../../data/models/asset_item.dart';
import '../../../services/ai_service.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_toast.dart';
import 'ai_recognizer.dart';
import 'widgets/index.dart';

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

  final AiRecognizer _aiRecognizer = AiRecognizer();
  File? _screenshotFile;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _aiResult;

  List<String> _images = [];
  final ImageService _imageService = ImageService.instance;

  List<String> _relatedItems = [];

  List<Map<String, dynamic>> _pendingItems = [];
  int _currentItemIndex = 0;

  DateTime _purchaseDate = DateTime.now();
  String _selectedCategory = '';
  int _plannedLifetimeDays = 365;
  int _rating = 0;

  String _warrantyPeriod = '';
  DateTime? _warrantyExpiry;
  String _insuranceInfo = '';

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      _initEditMode();
    }
  }

  void _initEditMode() {
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
    _images = List.from(item.images);
    _relatedItems = List.from(item.relatedItems);
    if (item.screenshotPath.isNotEmpty) {
      _screenshotFile = File(item.screenshotPath);
    }
    _warrantyPeriod = item.warrantyPeriod ?? '';
    _warrantyExpiry = item.warrantyExpiry;
    _insuranceInfo = item.insuranceInfo ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing 
            ? t('edit.title', ref.read(localeCodeProvider)) 
            : t('add.title', ref.read(localeCodeProvider))),
        actions: _buildActions(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_aiResult != null && _aiResult!['error'] == null)
              _buildAiResultBanner(),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildBrandAndPriceFields(),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (categories) => CategorySelector(
                selectedCategory: _selectedCategory,
                onSelected: (cat) => setState(() => _selectedCategory = cat),
                categories: categories,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(t('error.loadFailed', ref.read(localeCodeProvider))),
            ),
            const SizedBox(height: 16),
            DatePickerField(
              initialDate: _purchaseDate,
              onChanged: (date) => setState(() => _purchaseDate = date),
              labelKey: 'add.purchaseDate',
            ),
            const SizedBox(height: 16),
            LifetimeSelector(
              initialDays: _plannedLifetimeDays,
              onChanged: (days) => setState(() => _plannedLifetimeDays = days),
            ),
            const SizedBox(height: 16),
            RatingSelector(
              rating: _rating,
              onChanged: (rating) => setState(() => _rating = rating),
            ),
            const SizedBox(height: 16),
            _buildNotesField(),
            const SizedBox(height: 16),
            WarrantySection(
              initialWarrantyPeriod: _warrantyPeriod,
              initialWarrantyExpiry: _warrantyExpiry,
              initialInsuranceInfo: _insuranceInfo,
              onWarrantyPeriodChanged: (val) => setState(() => _warrantyPeriod = val),
              onWarrantyExpiryChanged: (date) => setState(() => _warrantyExpiry = date),
              onInsuranceChanged: (val) => setState(() => _insuranceInfo = val),
            ),
            const SizedBox(height: 16),
            _buildImageSection(theme),
            const SizedBox(height: 16),
            _buildRelatedItemsCard(context, theme),
            const SizedBox(height: 32),
            _buildSubmitButton(theme),
            if (_pendingItems.length > 1) ...[
              const SizedBox(height: 8),
              _buildSkipButton(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isEditing) return [];
    return [
      TextButton.icon(
        onPressed: _pickScreenshot,
        icon: _isAnalyzing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.image_search),
        label: Text(
          _isAnalyzing 
              ? t('add.aiRecognizing', ref.read(localeCodeProvider)) 
              : t('add.aiRecognize', ref.read(localeCodeProvider)),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ];
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: t('add.name', ref.read(localeCodeProvider)),
        hintText: t('add.nameHint', ref.read(localeCodeProvider)),
        prefixIcon: const Icon(Icons.shopping_bag),
      ),
      validator: (v) => v == null || v.trim().isEmpty 
          ? t('add.nameRequired', ref.read(localeCodeProvider)) 
          : null,
    );
  }

  Widget _buildBrandAndPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _brandController,
            decoration: InputDecoration(
              labelText: t('add.brand', ref.read(localeCodeProvider)),
              hintText: t('add.brandHint', ref.read(localeCodeProvider)),
              prefixIcon: const Icon(Icons.business),
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
              prefixIcon: const Icon(Icons.monetization_on),
              prefixText: '¥ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return t('add.priceRequired', ref.read(localeCodeProvider));
              if (double.tryParse(v) == null) return t('add.priceInvalid', ref.read(localeCodeProvider));
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: t('add.notes', ref.read(localeCodeProvider)),
        hintText: t('add.notesHint', ref.read(localeCodeProvider)),
        prefixIcon: const Icon(Icons.notes),
      ),
      maxLines: 3,
    );
  }

  Widget _buildImageSection(ThemeData theme) {
    final loc2 = ref.read(localeCodeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('add.images', loc2),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _images.asMap().entries.map((entry) {
              final index = entry.key;
              final path = entry.value;
              return Stack(
                children: [
                  _imageService.buildImageThumbnail(path, size: 80),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _images.removeAt(index);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_images.length < 9)
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text(t('add.pickImages', loc2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            const SizedBox(width: 8),
            if (_images.length < 9)
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(t('add.takePhoto', loc2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelatedItemsCard(BuildContext context, ThemeData theme) {
    final loc = ref.read(localeCodeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('related.title', loc),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showRelatedItemsDialog(context),
                ),
              ],
            ),
            if (_relatedItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    t('related.empty', loc),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ..._relatedItems.map((uuid) {
                return FutureBuilder<AssetItem?>(
                  future: ref.read(assetDaoProvider).getByUuid(uuid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final relatedItem = snapshot.data!;
                    return ListTile(
                      key: Key(uuid),
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          AppIcons.getIcon(_getCategoryIcon(relatedItem.category)),
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(relatedItem.name),
                      subtitle: Text(
                        MoneyUtils.format(relatedItem.price, locale: loc),
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.orange),
                        onPressed: () {
                          setState(() {
                            _relatedItems.remove(uuid);
                          });
                        },
                      ),
                    );
                  },
                );
              }),
            if (_relatedItems.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('related.totalValue', loc),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  FutureBuilder<double>(
                    future: _calculateRelatedTotalValue(),
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? 0.0;
                      return Text(
                        MoneyUtils.format(total, locale: loc),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<double> _calculateRelatedTotalValue() async {
    double total = 0.0;
    for (final uuid in _relatedItems) {
      final relatedItem = await ref.read(assetDaoProvider).getByUuid(uuid);
      if (relatedItem != null) {
        total += relatedItem.price;
      }
    }
    return total;
  }

  void _showRelatedItemsDialog(BuildContext context) async {
    final allItems = await ref.read(assetListProvider.future);
    final currentItemId = widget.editItem?.id ?? 0;
    final availableItems = allItems.where((i) =>
      i.id != currentItemId &&
      !i.isArchived &&
      !i.isDeleted
    ).toList();

    if (!context.mounted) return;

    final dialogTheme = Theme.of(context);
    final loc = ref.read(localeCodeProvider);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t('related.selectTitle', loc)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: availableItems.isEmpty
                ? Center(child: Text(t('related.noMore', loc)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableItems.length,
                    itemBuilder: (ctx, index) {
                      final relatedItem = availableItems[index];
                      final isSelected = _relatedItems.contains(relatedItem.uuid);
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: dialogTheme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            AppIcons.getIcon(_getCategoryIcon(relatedItem.category)),
                            color: dialogTheme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(relatedItem.name),
                        subtitle: Text(
                          t(AppConstants.getCategoryNameKey(relatedItem.category), loc),
                        ),
                        trailing: IconButton(
                          icon: isSelected 
                              ? const Icon(Icons.remove_circle, color: Colors.orange)
                              : const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            setState(() {
                              if (isSelected) {
                                _relatedItems.remove(relatedItem.uuid);
                              } else {
                                _relatedItems.add(relatedItem.uuid);
                              }
                            });
                            if (mounted) {
                              this.setState(() {});
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String _getCategoryIcon(String category) {
    return AppConstants.getCategoryIconName(category);
  }

  Future<void> _pickImages() async {
    final paths = await _imageService.pickImages(maxImages: 9 - _images.length);
    if (paths.isNotEmpty) {
      setState(() {
        _images.addAll(paths);
      });
    }
  }

  Future<void> _takePhoto() async {
    final path = await _imageService.takePhoto();
    if (path.isNotEmpty) {
      setState(() {
        _images.add(path);
      });
    }
  }

  Widget _buildAiResultBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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

  Widget _buildSubmitButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      child: Text(
        _isEditing 
            ? t('add.saveEdit', ref.read(localeCodeProvider))
            : _pendingItems.length > 1
                ? '${t('add.submit', ref.read(localeCodeProvider))} (${_currentItemIndex + 1}/${_pendingItems.length})'
                : t('add.submit', ref.read(localeCodeProvider)),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _skipCurrentItem,
        icon: const Icon(Icons.skip_next),
        label: Text(t('add.skip', ref.read(localeCodeProvider))
            .replaceAll('{n}', '${_pendingItems.length - _currentItemIndex - 1}')),
        style: TextButton.styleFrom(foregroundColor: Colors.orange),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    await _aiRecognizer.pickAndRecognize(
      context,
      ref,
      (analyzing) => setState(() => _isAnalyzing = analyzing),
      (items) {
        setState(() {
          _pendingItems = items;
          _currentItemIndex = 0;
        });
        _fillFormWithItem(items[0]);
      },
    );
  }

  void _fillFormWithItem(Map<String, dynamic> data) {
    _aiRecognizer.fillFormData(
      data,
      nameController: _nameController,
      brandController: _brandController,
      priceController: _priceController,
      notesController: _notesController,
      selectedCategory: _selectedCategory,
      purchaseDate: _purchaseDate,
      onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
      onDateChanged: (date) => setState(() => _purchaseDate = date),
      locale: ref.read(localeCodeProvider),
    );
    setState(() {});
  }

  void _skipCurrentItem() => _advanceToNext();

  Future<void> _tryEnrich(AssetItem saved) async {
    try {
      final aiService = AiService();
      final enriched = await aiService.enrichItemInfo({
        'name': saved.name,
        'category': saved.category,
        'brand': saved.brand,
        'price': saved.price,
      });
      if (enriched['category'] != null && enriched['category'] != saved.category ||
          enriched['tags'] != null || enriched['suggestions'] != null) {
        final updatedTags = enriched['tags'] is List
            ? (enriched['tags'] as List).cast<String>()
            : null;
        final suggestion = enriched['suggestions'] as String? ?? '';
        final loc = ref.read(localeCodeProvider);
        final enhancedNotes = suggestion.isNotEmpty
            ? '${saved.notes}${saved.notes.isNotEmpty ? '\n' : ''}${t('add.aiSuggestion', loc).replaceAll('{suggestion}', suggestion)}'
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
    } catch (_) {}
  }

  void _advanceToNext() {
    final next = _currentItemIndex + 1;
    if (next >= _pendingItems.length) {
      _pendingItems = [];
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() => _currentItemIndex = next);
    _fillFormWithItem(_pendingItems[next]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('add.confirmSaveN', ref.read(localeCodeProvider))
              .replaceAll('{current}', '${next + 1}').replaceAll('{total}', '${_pendingItems.length}')),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    final dao = ref.read(assetDaoProvider);

    if (_isEditing && widget.editItem != null) {
      await _updateItem(dao, price);
      return;
    }

    if (_pendingItems.isNotEmpty) {
      await _savePendingItem(dao, price);
      return;
    }

    await _saveNewItem(dao, price);
  }

  Future<void> _updateItem(AssetDao dao, double price) async {
    final wp = _warrantyPeriod.trim();
    final ins = _insuranceInfo.trim();

    final oldRelatedItems = widget.editItem!.relatedItems;
    final newRelatedItems = _relatedItems;

    final addedItems = newRelatedItems.where((uuid) => !oldRelatedItems.contains(uuid)).toList();
    final removedItems = oldRelatedItems.where((uuid) => !newRelatedItems.contains(uuid)).toList();

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
      images: _images,
      relatedItems: _relatedItems,
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    await dao.update(updated);

    for (final uuid in addedItems) {
      final targetItem = await dao.getByUuid(uuid);
      if (targetItem != null) {
        final targetRelatedItems = List<String>.from(targetItem.relatedItems)..add(widget.editItem!.uuid);
        await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));

        for (final existingUuid in _relatedItems) {
          if (existingUuid != uuid && existingUuid != widget.editItem!.uuid) {
            final existingItem = await dao.getByUuid(existingUuid);
            if (existingItem != null) {
              if (!existingItem.relatedItems.contains(uuid)) {
                final existingRelatedItems = List<String>.from(existingItem.relatedItems)..add(uuid);
                await dao.update(existingItem.copyWith(relatedItems: existingRelatedItems));
              }
              if (!targetRelatedItems.contains(existingUuid)) {
                targetRelatedItems.add(existingUuid);
                await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));
              }
            }
          }
        }
      }
    }

    for (final uuid in removedItems) {
      final targetItem = await dao.getByUuid(uuid);
      if (targetItem != null) {
        final targetRelatedItems = List<String>.from(targetItem.relatedItems)..remove(widget.editItem!.uuid);
        await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));

        for (final existingUuid in _relatedItems) {
          if (existingUuid != uuid && existingUuid != widget.editItem!.uuid) {
            final existingItem = await dao.getByUuid(existingUuid);
            if (existingItem != null) {
              if (existingItem.relatedItems.contains(uuid)) {
                final existingRelatedItems = List<String>.from(existingItem.relatedItems)..remove(uuid);
                await dao.update(existingItem.copyWith(relatedItems: existingRelatedItems));
              }
              if (targetRelatedItems.contains(existingUuid)) {
                targetRelatedItems.remove(existingUuid);
                await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));
              }
            }
          }
        }
      }
    }

    if (mounted) {
      AppToast.capsule(context, t('toast.updated', ref.read(localeCodeProvider)), Colors.green);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  Future<void> _savePendingItem(AssetDao dao, double price) async {
    final wp = _warrantyPeriod.trim();
    final ins = _insuranceInfo.trim();
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
      images: _images,
      relatedItems: _relatedItems,
      aiRawData: _pendingItems.length > 1 
          ? t('add.aiRawDataMultiple', ref.read(localeCodeProvider))
              .replaceAll('{n}', '${_pendingItems.length}')
              .replaceAll('{i}', '${_currentItemIndex + 1}')
          : '',
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    final saved = await dao.add(item);

    for (final uuid in _relatedItems) {
      final targetItem = await dao.getByUuid(uuid);
      if (targetItem != null) {
        final targetRelatedItems = List<String>.from(targetItem.relatedItems)..add(saved.uuid);
        await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));

        for (final otherUuid in _relatedItems) {
          if (otherUuid != uuid && !targetRelatedItems.contains(otherUuid)) {
            final otherItem = await dao.getByUuid(otherUuid);
            if (otherItem != null) {
              final otherRelatedItems = List<String>.from(otherItem.relatedItems)..add(uuid);
              await dao.update(otherItem.copyWith(relatedItems: otherRelatedItems));
              targetRelatedItems.add(otherUuid);
              await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));
            }
          }
        }
      }
    }

    if (mounted) {
      AppToast.capsule(context, t('toast.addedN', ref.read(localeCodeProvider))
          .replaceAll('{i}', '${_currentItemIndex + 1}')
          .replaceAll('{n}', '${_pendingItems.length}'), Colors.green);
    }
    _advanceToNext();
  }

  Future<void> _saveNewItem(AssetDao dao, double price) async {
    final wp = _warrantyPeriod.trim();
    final ins = _insuranceInfo.trim();
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
      images: _images,
      relatedItems: _relatedItems,
      aiRawData: _aiResult != null ? _aiResult.toString() : '',
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    final saved = await dao.add(item);

    for (final uuid in _relatedItems) {
      final targetItem = await dao.getByUuid(uuid);
      if (targetItem != null) {
        final targetRelatedItems = List<String>.from(targetItem.relatedItems)..add(saved.uuid);
        await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));

        for (final otherUuid in _relatedItems) {
          if (otherUuid != uuid && !targetRelatedItems.contains(otherUuid)) {
            final otherItem = await dao.getByUuid(otherUuid);
            if (otherItem != null) {
              final otherRelatedItems = List<String>.from(otherItem.relatedItems)..add(uuid);
              await dao.update(otherItem.copyWith(relatedItems: otherRelatedItems));
              targetRelatedItems.add(otherUuid);
              await dao.update(targetItem.copyWith(relatedItems: targetRelatedItems));
            }
          }
        }
      }
    }

    _tryEnrich(saved);
    if (mounted) {
      AppToast.capsule(context, t('toast.added', ref.read(localeCodeProvider)), Colors.green);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }
}