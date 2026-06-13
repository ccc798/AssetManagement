import 'package:equatable/equatable.dart';

/// 分类模型（改用纯 Dart 类，无需代码生成）
class CategoryItem extends Equatable {
  const CategoryItem({
    this.id = 0,
    this.name = '',
    this.icon = 'other',
    this.colorHex = '#9E9E9E',
    this.sortOrder = 0,
    this.isPreset = false,
    this.isDeleted = false,
  });

  final int id;
  final String name;
  final String icon;
  final String colorHex;
  final int sortOrder;
  final bool isPreset;
  final bool isDeleted;

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'other',
        colorHex: json['colorHex'] as String? ?? '#9E9E9E',
        sortOrder: json['sortOrder'] as int? ?? 0,
        isPreset: json['isPreset'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorHex': colorHex,
        'sortOrder': sortOrder,
        'isPreset': isPreset,
        'isDeleted': isDeleted,
      };

  CategoryItem copyWith({
    int? id,
    String? name,
    String? icon,
    String? colorHex,
    int? sortOrder,
    bool? isPreset,
    bool? isDeleted,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id, name, icon, colorHex, sortOrder, isPreset, isDeleted,
      ];
}
