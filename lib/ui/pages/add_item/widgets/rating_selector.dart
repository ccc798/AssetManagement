import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/translations.dart';

class RatingSelector extends ConsumerWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const RatingSelector({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= rating ? Icons.star : Icons.star_border,
                color: star <= rating ? Colors.amber : null,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }
}