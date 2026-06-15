import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class RelatedPool extends Equatable {
  final String uuid;
  final String name;
  final List<String> itemUuids;
  final DateTime createdAt;
  final DateTime updatedAt;

  RelatedPool({
    String? uuid,
    required this.name,
    required this.itemUuids,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RelatedPool copyWith({
    String? uuid,
    String? name,
    List<String>? itemUuids,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RelatedPool(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      itemUuids: itemUuids ?? this.itemUuids,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'itemUuids': itemUuids,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RelatedPool.fromJson(Map<String, dynamic> json) => RelatedPool(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        itemUuids: (json['itemUuids'] as List<dynamic>).map((e) => e.toString()).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
      );

  @override
  List<Object?> get props => [uuid, name, itemUuids, createdAt, updatedAt];
}