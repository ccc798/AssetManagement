import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// 用于 copyWith 的哨兵值——区分「不修改」和「设为 null」
const _sentinel = Object();

class AssetItem extends Equatable {
  AssetItem({
    this.id = 0,
    String? uuid,
    this.name = '',
    this.category = '',
    this.brand = '',
    this.price = 0.0,
    this.purchaseDate,
    this.notes = '',
    this.screenshotPath = '',
    this.aiRawData = '',
    this.tags = const [],
    this.rating = 0,
    this.plannedLifetimeDays = 365,
    this.isArchived = false,
    this.isDeleted = false,
    this.isFavorite = false,
    this.images = const [],
    this.warrantyPeriod,
    this.warrantyExpiry,
    this.insuranceInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final int id;
  final String uuid;
  final String name;
  final String category;
  final String brand;
  final double price;
  final DateTime? purchaseDate;
  final String notes;
  final String screenshotPath;
  final String aiRawData;
  final List<String> tags;
  final int rating;
  final int plannedLifetimeDays;
  final bool isArchived;
  final bool isDeleted;
  final bool isFavorite;
  final List<String> images;
  final String? warrantyPeriod;
  final DateTime? warrantyExpiry;
  final String? insuranceInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get daysUsed {
    if (purchaseDate == null) return 0;
    final diff = DateTime.now().difference(purchaseDate!);
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  double get dailyCost {
    final days = daysUsed;
    if (days <= 0) return price;
    return price / days;
  }

  DateTime? get estimatedEndDate {
    if (purchaseDate == null) return null;
    return purchaseDate!.add(Duration(days: plannedLifetimeDays));
  }

  double get remainingValueRatio {
    final total = plannedLifetimeDays;
    if (total <= 0) return 0;
    final used = daysUsed;
    if (used >= total) return 0;
    return (total - used) / total;
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'uuid': uuid, 'name': name, 'category': category,
        'brand': brand, 'price': price,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'notes': notes, 'screenshotPath': screenshotPath, 'aiRawData': aiRawData,
        'tags': tags, 'rating': rating, 'plannedLifetimeDays': plannedLifetimeDays,
        'isArchived': isArchived, 'isDeleted': isDeleted, 'isFavorite': isFavorite,
        'images': images,
        'warrantyPeriod': warrantyPeriod,
        'warrantyExpiry': warrantyExpiry?.toIso8601String(),
        'insuranceInfo': insuranceInfo,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AssetItem.fromJson(Map<String, dynamic> json) => AssetItem(
        id: json['id'] as int? ?? 0, uuid: json['uuid'] as String?,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        purchaseDate: json['purchaseDate'] != null
            ? DateTime.parse(json['purchaseDate'] as String) : null,
        notes: json['notes'] as String? ?? '',
        screenshotPath: json['screenshotPath'] as String? ?? '',
        aiRawData: json['aiRawData'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        rating: json['rating'] as int? ?? 0,
        plannedLifetimeDays: json['plannedLifetimeDays'] as int? ?? 365,
        isArchived: json['isArchived'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        warrantyPeriod: json['warrantyPeriod'] as String?,
        warrantyExpiry: json['warrantyExpiry'] != null
            ? DateTime.parse(json['warrantyExpiry'] as String) : null,
        insuranceInfo: json['insuranceInfo'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String) : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String) : null,
      );

  static AssetItem create({
    required String name, required String category, required double price,
    required DateTime purchaseDate, String brand = '', String notes = '',
    String screenshotPath = '', String aiRawData = '',
    List<String> tags = const [], int rating = 0, int plannedLifetimeDays = 365,
    bool isFavorite = false, List<String> images = const [],
    String? warrantyPeriod, DateTime? warrantyExpiry, String? insuranceInfo,
  }) {
    return AssetItem(uuid: const Uuid().v4(), name: name, category: category,
        brand: brand, price: price, purchaseDate: purchaseDate, notes: notes,
        screenshotPath: screenshotPath, aiRawData: aiRawData, tags: tags,
        rating: rating, plannedLifetimeDays: plannedLifetimeDays,
        isFavorite: isFavorite, images: images,
        warrantyPeriod: warrantyPeriod, warrantyExpiry: warrantyExpiry,
        insuranceInfo: insuranceInfo);
  }

  AssetItem copyWith({
    int? id, String? uuid, String? name, String? category,
    String? brand, double? price, DateTime? purchaseDate,
    String? notes, String? screenshotPath, String? aiRawData,
    List<String>? tags, int? rating, int? plannedLifetimeDays,
    bool? isArchived, bool? isDeleted, bool? isFavorite,
    List<String>? images,
    Object? warrantyPeriod = _sentinel,
    Object? warrantyExpiry = _sentinel,
    Object? insuranceInfo = _sentinel,
    DateTime? createdAt, DateTime? updatedAt,
  }) {
    return AssetItem(
      id: id ?? this.id, uuid: uuid ?? this.uuid,
      name: name ?? this.name, category: category ?? this.category,
      brand: brand ?? this.brand, price: price ?? this.price,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      notes: notes ?? this.notes,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      aiRawData: aiRawData ?? this.aiRawData,
      tags: tags ?? this.tags, rating: rating ?? this.rating,
      plannedLifetimeDays: plannedLifetimeDays ?? this.plannedLifetimeDays,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      images: images ?? this.images,
      warrantyPeriod: identical(warrantyPeriod, _sentinel) ? this.warrantyPeriod : warrantyPeriod as String?,
      warrantyExpiry: identical(warrantyExpiry, _sentinel) ? this.warrantyExpiry : warrantyExpiry as DateTime?,
      insuranceInfo: identical(insuranceInfo, _sentinel) ? this.insuranceInfo : insuranceInfo as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id, uuid, name, category, brand, price, purchaseDate,
        notes, screenshotPath, aiRawData, tags, rating,
        plannedLifetimeDays, isArchived, isDeleted, isFavorite, images,
        warrantyPeriod, warrantyExpiry, insuranceInfo,
        createdAt, updatedAt,
      ];
}
