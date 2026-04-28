enum AiSender { user, ai }

class AiMessage {
  final String text;
  final AiSender sender;
  final String? imageUrl; // For image generation results
  final DateTime timestamp;

  AiMessage({
    required this.text,
    required this.sender,
    this.imageUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
