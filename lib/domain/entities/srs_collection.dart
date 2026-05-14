class SrsCollection {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int cardCount;
  final int dueCount;

  const SrsCollection({
    required this.id,
    required this.name,
    this.description,
    this.icon = '📚',
    this.color = '#3B82F6',
    required this.createdAt,
    required this.updatedAt,
    this.cardCount = 0,
    this.dueCount = 0,
  });

  factory SrsCollection.fromJson(Map<String, dynamic> json) {
    return SrsCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? '📚',
      color: json['color'] as String? ?? '#3B82F6',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      cardCount: json['card_count'] as int? ?? 0,
      dueCount: json['due_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'card_count': cardCount,
      'due_count': dueCount,
    };
  }

  SrsCollection copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? cardCount,
    int? dueCount,
  }) {
    return SrsCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
    );
  }
}

class CollectionCard {
  final String collectionId;
  final String cardId;
  final DateTime addedAt;
  final int sortOrder;

  const CollectionCard({
    required this.collectionId,
    required this.cardId,
    required this.addedAt,
    this.sortOrder = 0,
  });

  factory CollectionCard.fromJson(Map<String, dynamic> json) {
    return CollectionCard(
      collectionId: json['collection_id'] as String,
      cardId: json['card_id'] as String,
      addedAt: DateTime.parse(json['added_at'] as String),
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collection_id': collectionId,
      'card_id': cardId,
      'added_at': addedAt.toIso8601String(),
      'sort_order': sortOrder,
    };
  }
}