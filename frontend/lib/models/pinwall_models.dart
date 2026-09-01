/// Sticky-note palette names a note may pick. They are palette *keys*, not
/// raw color values, so light/dark themes each resolve them to their own
/// shade. Order matches `MitlistColors.notePalette`.
const List<String> kPinwallNoteColors = [
  'yellow',
  'peach',
  'mint',
  'sky',
  'blush',
  'lavender',
];

/// Card sizes a note may pick. Null on a post means the default (medium).
const List<String> kPinwallNoteSizes = ['small', 'medium', 'large'];

class PinwallPost {
  final String id;
  final String groupId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? remindAt;
  final DateTime? reminderSentAt;
  final String? linkedEntityType;
  final String? linkedEntityId;

  /// Placement on the shared cork board, in the board's fixed logical
  /// coordinate space. Null means the note has never been positioned; the
  /// board then lays it out on its grid.
  final double? posX;
  final double? posY;

  /// Chosen sticky-note color (a name from [kPinwallNoteColors]) and card
  /// size (from [kPinwallNoteSizes]). Null means no explicit choice: the
  /// card derives a palette color from the note id / renders medium.
  final String? color;
  final String? size;

  const PinwallPost({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.remindAt,
    this.reminderSentAt,
    this.linkedEntityType,
    this.linkedEntityId,
    this.posX,
    this.posY,
    this.color,
    this.size,
  });

  factory PinwallPost.fromJson(Map<String, dynamic> json) => PinwallPost(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        remindAt: json['remind_at'] != null
            ? DateTime.parse(json['remind_at'] as String)
            : null,
        reminderSentAt: json['reminder_sent_at'] != null
            ? DateTime.parse(json['reminder_sent_at'] as String)
            : null,
        linkedEntityType: json['linked_entity_type'] as String?,
        linkedEntityId: json['linked_entity_id'] as String?,
        posX: (json['pos_x'] as num?)?.toDouble(),
        posY: (json['pos_y'] as num?)?.toDouble(),
        color: json['color'] as String?,
        size: json['size'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'remind_at': remindAt?.toIso8601String(),
        'reminder_sent_at': reminderSentAt?.toIso8601String(),
        if (linkedEntityType != null) 'linked_entity_type': linkedEntityType,
        if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
        if (posX != null) 'pos_x': posX,
        if (posY != null) 'pos_y': posY,
        if (color != null) 'color': color,
        if (size != null) 'size': size,
      };

  PinwallPost copyWith({double? posX, double? posY}) => PinwallPost(
        id: id,
        groupId: groupId,
        userId: userId,
        content: content,
        createdAt: createdAt,
        remindAt: remindAt,
        reminderSentAt: reminderSentAt,
        linkedEntityType: linkedEntityType,
        linkedEntityId: linkedEntityId,
        posX: posX ?? this.posX,
        posY: posY ?? this.posY,
        color: color,
        size: size,
      );
}
