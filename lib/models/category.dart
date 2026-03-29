import 'sync_model.dart';

enum CategoryType { income, expense, transfer }

class Category implements SyncableModel {
  final int? id;
  final String name;
  final int iconCode; // Store IconData.codePoint
  final String? fontFamily;
  final String? fontPackage;
  final int colorValue; // Store Color.value
  final CategoryType type;
  final bool isCustom; // To distinguish between default and user-added
  
  // Sync fields
  @override
  final String? syncId;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? deletedAt;
  @override
  final SyncStatus syncStatus;

  Category({
    this.id,
    required this.name,
    required this.iconCode,
    this.fontFamily,
    this.fontPackage,
    required this.colorValue,
    required this.type,
    this.isCustom = true,
    this.syncId,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Category copyWith({
    int? id,
    String? name,
    int? iconCode,
    String? fontFamily,
    String? fontPackage,
    int? colorValue,
    CategoryType? type,
    bool? isCustom,
    String? syncId,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontPackage: fontPackage ?? this.fontPackage,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      isCustom: isCustom ?? this.isCustom,
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'fontFamily': fontFamily,
      'fontPackage': fontPackage,
      'colorValue': colorValue,
      'type': type.index, // Store as int
      'isCustom': isCustom ? 1 : 0,
      'syncId': syncId,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus.toValue(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      iconCode: map['iconCode'],
      fontFamily: map['fontFamily'],
      fontPackage: map['fontPackage'],
      colorValue: map['colorValue'],
      type: CategoryType.values[map['type']],
      isCustom: map['isCustom'] == 1,
      syncId: map['syncId'],
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt']) : null,
      syncStatus: map['syncStatus'] != null 
          ? SyncStatusExtension.fromValue(map['syncStatus']) 
          : SyncStatus.pending,
    );
  }

  @override
  Map<String, dynamic> toSyncMap() {
    return {
      'id': syncId ?? generateSyncId(),
      'local_id': id,
      'name': name,
      'icon_code': iconCode,
      'font_family': fontFamily,
      'font_package': fontPackage,
      'color_value': colorValue,
      'type': type.name,
      'is_custom': isCustom,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
