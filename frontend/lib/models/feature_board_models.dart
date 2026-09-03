/// Where a request stands, as the tracker reports it. The tracker also has a
/// "declined" status but never lists declined requests on the board.
enum FeatureBoardStatus {
  underReview,
  inProgress,
  shipped;

  factory FeatureBoardStatus.fromJson(String value) {
    return switch (value) {
      'new' => FeatureBoardStatus.underReview,
      'in_progress' => FeatureBoardStatus.inProgress,
      'done' => FeatureBoardStatus.shipped,
      _ => throw FormatException('Unknown feature board status: $value'),
    };
  }
}

/// Chosen by the user when they post; staff can reclassify later.
enum FeatureBoardKind {
  feature,
  bug;

  factory FeatureBoardKind.fromJson(String value) {
    return switch (value) {
      'bug' => FeatureBoardKind.bug,
      _ => FeatureBoardKind.feature,
    };
  }

  String toJson() => switch (this) {
        FeatureBoardKind.feature => 'feature',
        FeatureBoardKind.bug => 'bug',
      };
}

enum FeatureBoardSort {
  top,
  newest;

  String toQuery() => switch (this) {
        FeatureBoardSort.top => 'top',
        FeatureBoardSort.newest => 'new',
      };
}

class FeatureBoardItem {
  const FeatureBoardItem({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.kind,
    required this.voteCount,
    required this.hasVoted,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final FeatureBoardStatus status;
  final FeatureBoardKind kind;
  final int voteCount;
  final bool hasVoted;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeatureBoardItem.fromJson(Map<String, dynamic> json) {
    return FeatureBoardItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: FeatureBoardStatus.fromJson(json['status'] as String),
      kind: FeatureBoardKind.fromJson(json['kind'] as String? ?? 'feature'),
      voteCount: (json['voteCount'] as num).toInt(),
      hasVoted: json['hasVoted'] as bool,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
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
    int? commentCount,
  }) {
    return FeatureBoardItem(
      id: id,
      title: title,
      description: description,
      status: status,
      kind: kind,
      voteCount: voteCount ?? this.voteCount,
      hasVoted: hasVoted ?? this.hasVoted,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// One entry in a request's public thread. Team replies are what the board
/// shows as the official word on a request.
class FeatureBoardComment {
  const FeatureBoardComment({
    required this.id,
    required this.body,
    required this.isFromTeam,
    this.authorName,
    required this.isMine,
    required this.createdAt,
  });

  final String id;
  final String body;
  final bool isFromTeam;
  final String? authorName;
  final bool isMine;
  final DateTime createdAt;

  factory FeatureBoardComment.fromJson(Map<String, dynamic> json) {
    return FeatureBoardComment(
      id: json['id'] as String,
      body: json['body'] as String,
      isFromTeam: json['authorKind'] == 'staff',
      authorName: json['authorName'] as String?,
      isMine: json['isMine'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num).toInt(),
      ),
    );
  }
}

class FeatureBoardDetail {
  const FeatureBoardDetail({required this.item, required this.comments});

  final FeatureBoardItem item;
  final List<FeatureBoardComment> comments;

  factory FeatureBoardDetail.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List<dynamic>? ?? const [];
    return FeatureBoardDetail(
      item: FeatureBoardItem.fromJson(json),
      comments: rawComments
          .map((entry) => FeatureBoardComment.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(growable: false),
    );
  }

  FeatureBoardDetail copyWith({
    FeatureBoardItem? item,
    List<FeatureBoardComment>? comments,
  }) {
    return FeatureBoardDetail(
      item: item ?? this.item,
      comments: comments ?? this.comments,
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
