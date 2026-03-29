import 'sync_model.dart';

enum AccountType { cash, bank, creditCard, other }

class Account implements SyncableModel {
  final int? id;
  final String name;
  final AccountType type;
  final double balance; // Current balance
  
  // Sync fields
  @override
  final String? syncId;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? deletedAt;
  @override
  final SyncStatus syncStatus;

  Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.syncId,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    double? balance,
    String? syncId,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
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
      'type': type.index,
      'balance': balance,
      'syncId': syncId,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus.toValue(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      type: AccountType.values[map['type']],
      balance: map['balance'],
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
      'type': type.name,
      'balance': balance,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
