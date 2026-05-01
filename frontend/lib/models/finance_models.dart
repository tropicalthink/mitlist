import '../utils/json_int64.dart';

class Expense {
  final String id;
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String currency;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.category,
    required this.currency,
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        payerId: json['payer_id'] as String,
        amount: parseJsonInt64(json['amount'], fieldName: 'amount'),
        description: json['description'] as String,
        category: json['category'] as String? ?? 'other',
        currency: json['currency'] as String? ?? 'USD',
        notes: json['notes'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'payer_id': payerId,
        'amount': amount,
        'description': description,
        'category': category,
        'currency': currency,
        'notes': notes,
        'date': date.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

class Settlement {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.createdAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        fromUserId: json['from_user_id'] as String,
        toUserId: json['to_user_id'] as String,
        amount: parseJsonInt64(json['amount'], fieldName: 'amount'),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class BalanceEntry {
  final String userId;
  final String displayName;
  final int paid;
  final int owed;
  final int total;

  const BalanceEntry({
    required this.userId,
    required this.displayName,
    required this.paid,
    required this.owed,
    required this.total,
  });

  factory BalanceEntry.fromJson(Map<String, dynamic> json) => BalanceEntry(
        userId: json['user_id'] as String,
        displayName:
            json['display_name'] as String? ?? json['user_id'] as String,
        paid: parseJsonInt64(json['paid'], fieldName: 'paid'),
        owed: parseJsonInt64(json['owed'], fieldName: 'owed'),
        total: parseJsonInt64(json['total'], fieldName: 'total'),
      );
}

class ReimbursementSuggestion {
  final String fromUserId;
  final String fromDisplayName;
  final String toUserId;
  final String toDisplayName;
  final int amount;

  const ReimbursementSuggestion({
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.toDisplayName,
    required this.amount,
  });

  factory ReimbursementSuggestion.fromJson(Map<String, dynamic> json) =>
      ReimbursementSuggestion(
        fromUserId: json['from_user_id'] as String,
        fromDisplayName: json['from_display_name'] as String? ??
            json['from_user_id'] as String,
        toUserId: json['to_user_id'] as String,
        toDisplayName:
            json['to_display_name'] as String? ?? json['to_user_id'] as String,
        amount: parseJsonInt64(json['amount'], fieldName: 'amount'),
      );
}

class FinanceSummary {
  final List<BalanceEntry> balances;
  final List<ReimbursementSuggestion> reimbursements;

  const FinanceSummary({
    required this.balances,
    required this.reimbursements,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        balances: ((json['balances'] as List?) ?? const [])
            .map((j) =>
                BalanceEntry.fromJson((j as Map).cast<String, dynamic>()))
            .toList(),
        reimbursements: ((json['reimbursements'] as List?) ?? const [])
            .map((j) => ReimbursementSuggestion.fromJson(
                (j as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'balances': balances
            .map((b) => {
                  'user_id': b.userId,
                  'display_name': b.displayName,
                  'paid': b.paid,
                  'owed': b.owed,
                  'total': b.total,
                })
            .toList(),
        'reimbursements': reimbursements
            .map((r) => {
                  'from_user_id': r.fromUserId,
                  'from_display_name': r.fromDisplayName,
                  'to_user_id': r.toUserId,
                  'to_display_name': r.toDisplayName,
                  'amount': r.amount,
                })
            .toList(),
      };
}

class CreateExpenseRequest {
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String currency;
  final String notes;
  final DateTime date;
  final List<String> splitUserIds;
  final String splitMode;
  final List<CreateExpenseSplitRequest> splits;

  const CreateExpenseRequest({
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    this.category = 'other',
    this.currency = 'USD',
    this.notes = '',
    required this.date,
    this.splitUserIds = const [],
    this.splitMode = 'equal',
    this.splits = const [],
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'payer_id': payerId,
        'amount': amount,
        'description': description,
        'category': category,
        'currency': currency,
        'notes': notes,
        'date': date.toIso8601String(),
        'split_user_ids': splitUserIds,
        'split_mode': splitMode,
        if (splits.isNotEmpty) 'splits': splits.map((s) => s.toJson()).toList(),
      };
}

class CreateExpenseSplitRequest {
  final String userId;
  final int? amount;
  final int? shares;
  final int? percentage;

  const CreateExpenseSplitRequest({
    required this.userId,
    this.amount,
    this.shares,
    this.percentage,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (amount != null) 'amount': amount,
        if (shares != null) 'shares': shares,
        if (percentage != null) 'percentage': percentage,
      };
}

class UpdateExpenseRequest {
  final String? payerId;
  final int? amount;
  final String? description;
  final String? category;
  final String? currency;
  final String? notes;
  final DateTime? date;

  const UpdateExpenseRequest({
    this.payerId,
    this.amount,
    this.description,
    this.category,
    this.currency,
    this.notes,
    this.date,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (payerId != null) m['payer_id'] = payerId;
    if (amount != null) m['amount'] = amount;
    if (description != null) m['description'] = description;
    if (category != null) m['category'] = category;
    if (currency != null) m['currency'] = currency;
    if (notes != null) m['notes'] = notes;
    if (date != null) m['date'] = date!.toIso8601String();
    return m;
  }
}

class CreateSettlementRequest {
  final String? groupId;
  final String fromUserId;
  final String toUserId;
  final int amount;

  const CreateSettlementRequest({
    this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        if (groupId != null) 'group_id': groupId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'amount': amount,
      };
}

class CreateSplitRequest {
  final String userId;
  final int amount;
  const CreateSplitRequest({required this.userId, required this.amount});
  Map<String, dynamic> toJson() => {'user_id': userId, 'amount': amount};
}

class Split {
  final String id;
  final String expenseId;
  final String userId;
  final int amount;
  final bool isSettled;
  final DateTime createdAt;

  const Split({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amount,
    required this.isSettled,
    required this.createdAt,
  });

  factory Split.fromJson(Map<String, dynamic> json) => Split(
        id: json['id'] as String,
        expenseId: json['expense_id'] as String,
        userId: json['user_id'] as String,
        amount: parseJsonInt64(json['amount'], fieldName: 'amount'),
        isSettled: json['is_settled'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class UpdateSplitRequest {
  final String? userId;
  final int? amount;
  final bool? isSettled;
  const UpdateSplitRequest({this.userId, this.amount, this.isSettled});
  Map<String, dynamic> toJson() => {
        if (userId != null) 'user_id': userId,
        if (amount != null) 'amount': amount,
        if (isSettled != null) 'is_settled': isSettled,
      };
}

class RecurringExpense {
  final String id;
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String currency;
  final String frequency;
  final DateTime nextDue;
  final bool isActive;
  final DateTime createdAt;

  const RecurringExpense({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.category,
    required this.currency,
    required this.frequency,
    required this.nextDue,
    required this.isActive,
    required this.createdAt,
  });

  factory RecurringExpense.fromJson(Map<String, dynamic> json) =>
      RecurringExpense(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        payerId: json['payer_id'] as String,
        amount: parseJsonInt64(json['amount'], fieldName: 'amount'),
        description: json['description'] as String,
        category: json['category'] as String? ?? 'other',
        currency: json['currency'] as String? ?? 'USD',
        frequency: json['frequency'] as String? ?? 'monthly',
        nextDue: DateTime.parse(json['next_due'] as String),
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CreateRecurringExpenseRequest {
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String frequency;
  final DateTime nextDue;
  final bool isActive;

  const CreateRecurringExpenseRequest({
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    this.category = 'other',
    this.frequency = 'monthly',
    required this.nextDue,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'payer_id': payerId,
        'amount': amount,
        'description': description,
        'category': category,
        'frequency': frequency,
        'next_due': nextDue.toUtc().toIso8601String(),
        'is_active': isActive,
      };
}

class UpdateRecurringExpenseRequest {
  final String? payerId;
  final int? amount;
  final String? description;
  final String? category;
  final String? frequency;
  final DateTime? nextDue;
  final bool? isActive;

  const UpdateRecurringExpenseRequest({
    this.payerId,
    this.amount,
    this.description,
    this.category,
    this.frequency,
    this.nextDue,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        if (payerId != null) 'payer_id': payerId,
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (frequency != null) 'frequency': frequency,
        if (nextDue != null) 'next_due': nextDue!.toUtc().toIso8601String(),
        if (isActive != null) 'is_active': isActive,
      };
}
