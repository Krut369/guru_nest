class Message {
  final String id;
  final String conversationId;
  final String? senderId;
  final String content;
  final DateTime sentAt;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.content,
    required this.sentAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      sentAt: DateTime.parse(json['sent_at']),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}

class Conversation {
  final String id;
  final String? title;
  final bool isGroup;
  final DateTime createdAt;

  Conversation({
    required this.id,
    this.title,
    this.isGroup = false,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      isGroup: json['is_group'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_group': isGroup,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
