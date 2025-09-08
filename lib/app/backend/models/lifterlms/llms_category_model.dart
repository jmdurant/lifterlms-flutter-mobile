class LLMSCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String description;
  final int count;
  final int parent;
  
  LLMSCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.count,
    required this.parent,
  });

  factory LLMSCategoryModel.fromJson(Map<String, dynamic> json) {
    return LLMSCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      count: json['count'] ?? 0,
      parent: json['parent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'count': count,
      'parent': parent,
    };
  }

  @override
  String toString() {
    return 'LLMSCategoryModel{id: $id, name: $name, slug: $slug}';
  }
}