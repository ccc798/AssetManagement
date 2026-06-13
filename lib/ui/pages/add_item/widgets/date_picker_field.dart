import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/translations.dart';
import '../../../../core/utils/date_utils.dart';

class DatePickerField extends ConsumerWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  final String labelKey;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.initialDate,
    required this.onChanged,
    required this.labelKey,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
          locale: const Locale('zh'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t(labelKey, ref.read(localeCodeProvider)),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(AppDateUtils.formatLocale(initialDate, ref.read(localeCodeProvider))),
      ),
    );
  }
}