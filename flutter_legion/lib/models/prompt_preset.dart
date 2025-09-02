class PromptPreset {
  final String id;
  final String name;
  final String content;

  const PromptPreset({required this.id, required this.name, required this.content});

  factory PromptPreset.fromJson(Map<String, dynamic> json) => PromptPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        content: json['content'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
      };
}

