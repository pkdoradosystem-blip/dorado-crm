class FormFieldSchema {
  final String key;
  final String label;
  final String type;
  final bool required;
  final List<String> options;

  const FormFieldSchema({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  factory FormFieldSchema.fromJson(
    Map<String, dynamic> json,
  ) {
    return FormFieldSchema(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] == true,

      // Database/API dropdown values
      options: (json['options'] as List? ?? [])
          .map(
            (item) => item.toString(),
          )
          .where(
            (item) => item.trim().isNotEmpty,
          )
          .toList(),
    );
  }
}


class FormSchema {
  final String code;
  final String title;
  final String submitEndpoint;
  final List<FormFieldSchema> fields;

  const FormSchema({
    required this.code,
    required this.title,
    required this.submitEndpoint,
    required this.fields,
  });

  factory FormSchema.fromJson(
    Map<String, dynamic> json,
  ) {
    return FormSchema(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      submitEndpoint:
          json['submitEndpoint']?.toString() ?? '',
      fields: (json['fields'] as List? ?? [])
          .map(
            (item) => FormFieldSchema.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}