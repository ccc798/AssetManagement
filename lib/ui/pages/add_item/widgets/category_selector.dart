import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../data/models/category.dart';

class CategorySelector extends ConsumerWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final List<CategoryItem> categories;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            final isSelected = selectedCategory == cat.name;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.categoryIcon(cat.icon, cat.colorHex, size: 16),
                  const SizedBox(width: 8),
                  Text(cat.isPreset 
                      ? t(AppConstants.getCategoryNameKey(cat.name), ref.read(localeCodeProvider)) 
                      : cat.name),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.fromHex(cat.colorHex).withValues(alpha: 0.2),
              onSelected: (selected) {
                if (selected) {
                  onSelected(cat.name);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}