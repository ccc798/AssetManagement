import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/translations.dart';

class WarrantySection extends ConsumerStatefulWidget {
  final String initialWarrantyPeriod;
  final DateTime? initialWarrantyExpiry;
  final String initialInsuranceInfo;
  final ValueChanged<String> onWarrantyPeriodChanged;
  final ValueChanged<DateTime?> onWarrantyExpiryChanged;
  final ValueChanged<String> onInsuranceChanged;

  const WarrantySection({
    super.key,
    required this.initialWarrantyPeriod,
    required this.initialWarrantyExpiry,
    required this.initialInsuranceInfo,
    required this.onWarrantyPeriodChanged,
    required this.onWarrantyExpiryChanged,
    required this.onInsuranceChanged,
  });

  @override
  ConsumerState<WarrantySection> createState() => _WarrantySectionState();
}

class _WarrantySectionState extends ConsumerState<WarrantySection> {
  late TextEditingController _warrantyController;
  late TextEditingController _insuranceController;
  late DateTime? _warrantyExpiry;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _warrantyController = TextEditingController(text: widget.initialWarrantyPeriod);
    _insuranceController = TextEditingController(text: widget.initialInsuranceInfo);
    _warrantyExpiry = widget.initialWarrantyExpiry;
    _expanded = widget.initialWarrantyPeriod.isNotEmpty || 
                widget.initialInsuranceInfo.isNotEmpty ||
                widget.initialWarrantyExpiry != null;
  }

  @override
  void dispose() {
    _warrantyController.dispose();
    _insuranceController.dispose();
    super.dispose();
  }

  Future<void> _pickWarrantyExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh'),
    );
    if (picked != null) {
      setState(() => _warrantyExpiry = picked);
      widget.onWarrantyExpiryChanged(picked);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final loc = ref.read(localeCodeProvider);
    final presetLabels = [
      t('lifetime.1y', loc),
      t('lifetime.2y', loc),
      t('lifetime.3y', loc),
      t('add.warrantyPeriod', loc).split(' ')[0],
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    t('add.warrantySection', loc),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
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
                  Text(t('add.warrantyPeriod', loc), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetLabels.map((label) {
                      final isSelected = _warrantyController.text == label;
                      return ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 13)),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        onSelected: (_) {
                          setState(() => _warrantyController.text = label);
                          widget.onWarrantyPeriodChanged(label);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _warrantyController,
                    decoration: InputDecoration(
                      hintText: t('add.warrantyCustomHint', loc),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: widget.onWarrantyPeriodChanged,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickWarrantyExpiry,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t('add.warrantyExpiry', loc),
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        isDense: true,
                      ),
                      child: Text(
                        _warrantyExpiry != null
                            ? '${_warrantyExpiry!.year}-${_pad(_warrantyExpiry!.month)}-${_pad(_warrantyExpiry!.day)}'
                            : t('add.selectDate', loc),
                        style: TextStyle(color: _warrantyExpiry != null ? null : Colors.grey),
                      ),
                    ),
                  ),
                  if (_warrantyExpiry != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _warrantyExpiry = null);
                        widget.onWarrantyExpiryChanged(null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text(t('add.clearDate', loc), style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _insuranceController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: t('add.insuranceInfo', loc),
                      hintText: t('add.insuranceHint', loc),
                      prefixIcon: const Icon(Icons.security, size: 20),
                    ),
                    maxLines: 2,
                    onChanged: widget.onInsuranceChanged,
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}