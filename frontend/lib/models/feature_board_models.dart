enum FeatureBoardStatus {
  planned,
  inProgress,
  shipped;

  factory FeatureBoardStatus.fromJson(String value) {
    return switch (value) {
      'new' => FeatureBoardStatus.planned,
      'in_progress' => FeatureBoardStatus.inProgress,
      'done' => FeatureBoardStatus.shipped,
      _ => throw FormatException('Unknown feature board status: $value'),
    };
  }
}

class FeatureBoardItem {
  const FeatureBoardItem({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.voteCount,
    required this.hasVoted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final FeatureBoardStatus status;
  final int voteCount;
  final bool hasVoted;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeatureBoardItem.fromJson(Map<String, dynamic> json) {
    return FeatureBoardItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: FeatureBoardStatus.fromJson(json['status'] as String),
      voteCount: (json['voteCount'] as num).toInt(),
      hasVoted: json['hasVoted'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num).toInt(),
      ),
    );
  }

  FeatureBoardItem copyWith({
    int? voteCount,
    bool? hasVoted,
  }) {
    return FeatureBoardItem(
      id: id,
      title: title,
      description: description,
      status: status,
      voteCount: voteCount ?? this.voteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class FeatureBoardVote {
  const FeatureBoardVote({
    required this.requestId,
    required this.voteCount,
    required this.hasVoted,
  });

  final String requestId;
  final int voteCount;
  final bool hasVoted;

  factory FeatureBoardVote.fromJson(Map<String, dynamic> json) {
    return FeatureBoardVote(
      requestId: json['requestId'] as String,
      voteCount: (json['voteCount'] as num).toInt(),
      hasVoted: json['hasVoted'] as bool,
    );
  }
}
