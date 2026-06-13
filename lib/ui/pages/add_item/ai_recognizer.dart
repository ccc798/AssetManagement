import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/i18n/translations.dart';
import '../../../services/ai_service.dart';

typedef AiResultCallback = void Function(List<Map<String, dynamic>> items);

class AiRecognizer {
  final AiService _aiService;

  AiRecognizer() : _aiService = AiService();

  Future<void> pickAndRecognize(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<bool> onAnalyzingChanged,
    AiResultCallback onResult,
  ) async {
    final picker = ImagePicker();
    final source = await _showSourceDialog(context, ref);

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (picked != null) {
      final file = File(picked.path);
      onAnalyzingChanged(true);

      try {
        final bytes = await file.readAsBytes();
        final items = await _aiService.recognizeFromScreenshot(
          bytes,
          fileName: picked.name,
          locale: ref.read(localeCodeProvider),
        ).timeout(const Duration(seconds: 30), onTimeout: () {
          return [{'error': t('add.aiTimeout', ref.read(localeCodeProvider))}];
        });

        onAnalyzingChanged(false);

        if (items.isEmpty || items.first['error'] != null) {
          final errMsg = items.isNotEmpty
              ? items.first['error']?.toString() ?? t('add.aiFailed', ref.read(localeCodeProvider))
              : t('add.aiFailed', ref.read(localeCodeProvider));
          if (context.mounted) {
            _showError(context, errMsg);
          }
          return;
        }

        onResult(items);

        if (items.length > 1 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${t('add.aiDetectedN', ref.read(localeCodeProvider)).replaceAll('{n}', '${items.length}')}，'
                '${t('add.continue_', ref.read(localeCodeProvider)).replaceAll('{i}', '1').replaceAll('{n}', '${items.length}')}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        onAnalyzingChanged(false);
        if (context.mounted) {
          _showError(context, t('add.aiFailed', ref.read(localeCodeProvider)));
        }
      }
    }
  }

  Future<ImageSource?> _showSourceDialog(BuildContext context, WidgetRef ref) {
    return showDialog<ImageSource>(
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
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
      );
    }
  }

  void fillFormData(
    Map<String, dynamic> data, {
    required TextEditingController nameController,
    required TextEditingController brandController,
    required TextEditingController priceController,
    required TextEditingController notesController,
    required String? selectedCategory,
    required DateTime purchaseDate,
    required ValueChanged<String> onCategoryChanged,
    required ValueChanged<DateTime> onDateChanged,
    required String locale,
  }) {
    if (data['name'] != null && data['name'].toString().isNotEmpty) {
      nameController.text = data['name'].toString();
    }
    if (data['brand'] != null && data['brand'].toString().isNotEmpty) {
      brandController.text = data['brand'].toString();
    }
    if (data['price'] != null) {
      final p = data['price'];
      priceController.text = p is num ? p.toString() : p.toString();
    }
    if (data['category'] != null && data['category'].toString().isNotEmpty) {
      onCategoryChanged(data['category'].toString());
    }
    if (data['purchaseDate'] != null && data['purchaseDate'].toString().isNotEmpty) {
      try {
        onDateChanged(DateTime.parse(data['purchaseDate'].toString()));
      } catch (_) {}
    }
    if (data['tags'] != null && data['tags'] is List) {
      notesController.text = t('add.tagsLabel', locale).replaceAll('{tags}', (data['tags'] as List).join(', '));
    }
  }
}