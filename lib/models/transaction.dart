import 'category.dart';
import 'sync_model.dart';

class Transaction implements SyncableModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final CategoryType type;
  final int categoryId;
  final int? accountId;
  final int? transferAccountId; // Destination account for transfers
  final String? notes;
  final double? originalAmount;
  final String? originalCurrency;
  final int? loanId;
  
  // Sync fields
  @override
  final String? syncId;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? deletedAt;
  @override
  final SyncStatus syncStatus;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    this.accountId,
    this.transferAccountId,
    this.notes,
    this.originalAmount,
    this.originalCurrency,
    this.loanId,
    this.syncId,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    CategoryType? type,
    int? categoryId,
    int? accountId,
    int? transferAccountId,
    String? notes,
    double? originalAmount,
    String? originalCurrency,
    int? loanId,
    String? syncId,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transferAccountId: transferAccountId ?? this.transferAccountId,
      notes: notes ?? this.notes,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      loanId: loanId ?? this.loanId,
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.index,
      'categoryId': categoryId,
      'accountId': accountId,
      'transferAccountId': transferAccountId,
      'notes': notes,
      'originalAmount': originalAmount,
      'originalCurrency': originalCurrency,
      'loanId': loanId,
      'syncId': syncId,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus.toValue(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: CategoryType.values[map['type']],
      categoryId: map['categoryId'],
      accountId: map['accountId'],
      transferAccountId: map['transferAccountId'],
      notes: map['notes'],
      originalAmount: map['originalAmount'],
      originalCurrency: map['originalCurrency'],
      loanId: map['loanId'],
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
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'category_id': categoryId,
      'account_id': accountId,
      'transfer_account_id': transferAccountId,
      'notes': notes,
      'original_amount': originalAmount,
      'original_currency': originalCurrency,
      'loan_id': loanId,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
