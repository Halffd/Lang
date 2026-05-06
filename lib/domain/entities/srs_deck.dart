class SrsDeck {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final DateTime createdAt;
  final int cardCount;
  final int dueCount;

  const SrsDeck({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.icon = '📚',
    this.color = '#3B82F6',
    required this.createdAt,
    this.cardCount = 0,
    this.dueCount = 0,
  });

  factory SrsDeck.fromMap(Map<String, dynamic> map) {
    return SrsDeck(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String? ?? '📚',
      color: map['color'] as String? ?? '#3B82F6',
      createdAt: DateTime.parse(map['created_at'] as String),
      cardCount: map['card_count'] as int? ?? 0,
      dueCount: map['due_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SrsDeck copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? icon,
    String? color,
    DateTime? createdAt,
    int? cardCount,
    int? dueCount,
  }) {
    return SrsDeck(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
    );
  }
}