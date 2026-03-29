import 'dart:math';
import 'sync_model.dart';

enum LoanType { given, taken }

class Loan implements SyncableModel {
  final int? id;
  final String title;
  final double amount;
  final double interestRate; // Annual interest rate in %
  final int tenureMonths;
  final LoanType type;
  final DateTime startDate;
  final double emiAmount;
  final double amountPaid;
  final bool isClosed;
  final String? notes;
  
  // Sync fields
  @override
  final String? syncId;
  @override
  final DateTime? updatedAt;
  @override
  final DateTime? deletedAt;
  @override
  final SyncStatus syncStatus;

  Loan({
    this.id,
    required this.title,
    required this.amount,
    required this.interestRate,
    required this.tenureMonths,
    required this.type,
    required this.startDate,
    required this.emiAmount,
    this.amountPaid = 0.0,
    this.isClosed = false,
    this.notes,
    this.syncId,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Loan copyWith({
    int? id,
    String? title,
    double? amount,
    double? interestRate,
    int? tenureMonths,
    LoanType? type,
    DateTime? startDate,
    double? emiAmount,
    double? amountPaid,
    bool? isClosed,
    String? notes,
    String? syncId,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
  }) {
    return Loan(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      emiAmount: emiAmount ?? this.emiAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      isClosed: isClosed ?? this.isClosed,
      notes: notes ?? this.notes,
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // Calculate EMI: [P x R x (1+R)^N]/[(1+R)^N-1]
  // P = Principal, R = Monthly Interest Rate, N = Tenure in Months
  static double calculateEMI(double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    double monthlyRate = annualRate / 12 / 100;
    return (principal * monthlyRate * pow(1 + monthlyRate, months)) /
        (pow(1 + monthlyRate, months) - 1);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'type': type.index,
      'startDate': startDate.toIso8601String(),
      'emiAmount': emiAmount,
      'amountPaid': amountPaid,
      'isClosed': isClosed ? 1 : 0,
      'notes': notes,
      'syncId': syncId,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus.toValue(),
    };
  }

  static Loan fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      interestRate: map['interestRate'],
      tenureMonths: map['tenureMonths'],
      type: LoanType.values[map['type']],
      startDate: DateTime.parse(map['startDate']),
      emiAmount: map['emiAmount'],
      amountPaid: map['amountPaid'],
      isClosed: map['isClosed'] == 1,
      notes: map['notes'],
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
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'type': type.name,
      'start_date': startDate.toIso8601String(),
      'emi_amount': emiAmount,
      'amount_paid': amountPaid,
      'is_closed': isClosed,
      'notes': notes,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
