enum AiSender { user, ai }

class AiMessage {
  final String text;
  final AiSender sender;
  final String? imageUrl;
  final DateTime timestamp;

  AiMessage({
    required this.text,
    required this.sender,
    this.imageUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'sender': sender.name,
    'imageUrl': imageUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
    text: json['text'] as String? ?? '',
    sender: json['sender'] == 'user' ? AiSender.user : AiSender.ai,
    imageUrl: json['imageUrl'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
  );
}
