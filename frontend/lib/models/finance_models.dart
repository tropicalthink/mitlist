class Expense {
  final String id;
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String currency;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id, required this.groupId, required this.payerId,
    required this.amount, required this.description, required this.category,
    required this.currency, required this.date, required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    payerId: json['payer_id'] as String,
    amount: json['amount'] as int,
    description: json['description'] as String,
    category: json['category'] as String? ?? 'other',
    currency: json['currency'] as String? ?? 'USD',
    date: DateTime.parse(json['date'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'group_id': groupId, 'payer_id': payerId,
    'amount': amount, 'description': description, 'category': category,
    'currency': currency, 'date': date.toIso8601String(),
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
    required this.id, required this.groupId, required this.fromUserId,
    required this.toUserId, required this.amount, required this.createdAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    fromUserId: json['from_user_id'] as String,
    toUserId: json['to_user_id'] as String,
    amount: json['amount'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class CreateExpenseRequest {
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String currency;
  final DateTime date;
  final List<String> splitUserIds;

  const CreateExpenseRequest({
    required this.groupId, required this.payerId, required this.amount,
    required this.description, this.category = 'other', this.currency = 'USD',
    required this.date, this.splitUserIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId, 'payer_id': payerId, 'amount': amount,
    'description': description, 'category': category, 'currency': currency,
    'date': date.toIso8601String(), 'split_user_ids': splitUserIds,
  };
}

class CreateSettlementRequest {
  final String fromUserId;
  final String toUserId;
  final int amount;
  const CreateSettlementRequest({required this.fromUserId, required this.toUserId, required this.amount});
  Map<String, dynamic> toJson() => {'from_user_id': fromUserId, 'to_user_id': toUserId, 'amount': amount};
}

class CreateSplitRequest {
  final String userId;
  final int amount;
  const CreateSplitRequest({required this.userId, required this.amount});
  Map<String, dynamic> toJson() => {'user_id': userId, 'amount': amount};
}
