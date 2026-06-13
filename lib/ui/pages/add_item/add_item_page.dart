import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
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
      aiRawData: _pendingItems.length > 1 
          ? t('add.aiRawDataMultiple', ref.read(localeCodeProvider))
              .replaceAll('{n}', '${_pendingItems.length}')
              .replaceAll('{i}', '${_currentItemIndex + 1}')
          : '',
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    await dao.add(item);
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
      aiRawData: _aiResult != null ? _aiResult.toString() : '',
      warrantyPeriod: wp.isNotEmpty ? wp : null,
      warrantyExpiry: _warrantyExpiry,
      insuranceInfo: ins.isNotEmpty ? ins : null,
    );
    final saved = await dao.add(item);
    _tryEnrich(saved);
    if (mounted) {
      AppToast.capsule(context, t('toast.added', ref.read(localeCodeProvider)), Colors.green);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }
}