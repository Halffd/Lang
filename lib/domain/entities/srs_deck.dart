class SrsDeck {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SrsDeck({
    required this.id,
    required this.name,
    this.description,
    this.icon = '📚',
    this.color = '#3B82F6',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SrsDeck.fromJson(Map<String, dynamic> json) {
    return SrsDeck(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? '📚',
      color: json['color'] as String? ?? '#3B82F6',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SrsDeck copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SrsDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}