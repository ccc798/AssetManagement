import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/translations.dart';

class LifetimeSelector extends ConsumerStatefulWidget {
  final int initialDays;
  final ValueChanged<int> onChanged;

  const LifetimeSelector({
    super.key,
    required this.initialDays,
    required this.onChanged,
  });

  @override
  ConsumerState<LifetimeSelector> createState() => _LifetimeSelectorState();
}

class _LifetimeSelectorState extends ConsumerState<LifetimeSelector> {
  late int _days;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _days = widget.initialDays;
    _unit = 'days';
  }

  @override
  void didUpdateWidget(covariant LifetimeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _days = widget.initialDays;
  }

  int _toDays(int value, String unit) {
    switch (unit) {
      case 'weeks': return value * 7;
      case 'months': return value * 30;
      case 'years': return value * 365;
      default: return value;
    }
  }

  void _handleCustomInput(String value) {
    final val = int.tryParse(value);
    if (val != null && val > 0) {
      _days = _toDays(val, _unit);
      widget.onChanged(_days);
    }
  }

  void _handleUnitChange(String? unit) {
    if (unit != null) {
      setState(() => _unit = unit);
    }
  }

  void _handlePresetSelect(int days) {
    setState(() {
      _days = days;
    });
    widget.onChanged(days);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.read(localeCodeProvider);
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
          t('add.lifetime', loc),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final days = preset['days'] as int;
            final isSelected = _days == days;
            return ChoiceChip(
              label: Text(t(preset['key'] as String, loc)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _handlePresetSelect(days);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: _days.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  labelText: t('add.customLifetime', loc),
                ),
                onChanged: _handleCustomInput,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _unit,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: 'days', child: Text(t('add.days', loc))),
                DropdownMenuItem(value: 'weeks', child: Text(t('add.weeks', loc))),
                DropdownMenuItem(value: 'months', child: Text(t('add.months', loc))),
                DropdownMenuItem(value: 'years', child: Text(t('add.years', loc))),
              ],
              onChanged: _handleUnitChange,
            ),
          ],
        ),
      ],
    );
  }
}