class MenuItemModel {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String routeType;
  final String? formCode;
  final List<MenuItemModel> children;

  const MenuItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeType,
    this.formCode,
    required this.children,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      routeType: json['routeType']?.toString() ?? '',
      formCode: json['formCode']?.toString(),
      children: (json['children'] as List? ?? [])
          .map(
            (item) => MenuItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}