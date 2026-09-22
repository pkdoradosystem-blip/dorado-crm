import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../models/form_schema_model.dart';
import '../../services/services.dart';

class DynamicFormPage extends StatefulWidget {
  final String formCode;
  final String title;

  const DynamicFormPage({
    super.key,
    required this.formCode,
    required this.title,
  });

  @override
  State<DynamicFormPage> createState() =>
      _DynamicFormPageState();
}

class _DynamicFormPageState
    extends State<DynamicFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final FormService _formService;

  FormSchema? _schema;

  final Map<String, TextEditingController>
      _controllers = {};

  bool _loading = true;
  bool _saving = false;

  String? _error;
  final Map<String, String> _executiveManagers = {};

  @override
  void initState() {
    super.initState();

    _formService = FormService(
      ApiClient(),
    );

    _loadExecutiveManagers();
    _loadForm();
  }

  Future<void> _loadExecutiveManagers() async {
    try {
      final result = await ApiClient().get(
        '/api/v1/masters/executives',
      );

      if (result is List) {
        _executiveManagers.clear();

        for (final item in result) {
          if (item is Map) {
            final name = item['value']?.toString().trim() ?? '';
            final manager =
                item['reporting_manager']?.toString().trim() ?? '';

            if (name.isNotEmpty) {
              _executiveManagers[name] = manager;
            }
          }
        }
      }
    } catch (_) {
      // Backend still auto-assigns the Marketing Head during save.
    }
  }

  Future<void> _loadForm() async {
    try {
      final schema = await _formService.loadForm(
        widget.formCode,
      );

      for (final field in schema.fields) {
        _controllers[field.key] =
            TextEditingController();
      }

      if (widget.formCode == 'lead_entry') {
        final now = DateTime.now();
        _controllers['lead_date']?.text =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
      }

      if (!mounted) return;

      setState(() {
        _schema = schema;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveForm() async {
    if (_schema == null) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> values = {};

      for (final field in _schema!.fields) {
        values[field.key] =
            _controllers[field.key]?.text.trim() ??
                '';
      }

      // Lead Date generated from Flutter frontend.
      if (widget.formCode == 'lead_entry') {
        values['lead_status'] = 'New Lead';

        values['call_done'] = false;
        values['appointment_fixed'] = false;
        values['site_visit_done'] = false;
        values['survey_done'] = false;
        values['quotation_given'] = false;
        values['negotiation_done'] = false;
        values['order_finalized'] = false;
      }

      await _formService.submitForm(
        _schema!.submitEndpoint,
        values,
      );

      if (!mounted) return;

      for (final controller
          in _controllers.values) {
        controller.clear();
      }

      _formKey.currentState?.reset();

      if (widget.formCode == 'lead_entry') {
        final now = DateTime.now();
        _controllers['lead_date']?.text =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
      }

      if (mounted) setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Lead saved successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildField(
    FormFieldSchema field,
  ) {
    final controller = _controllers[field.key]!;

    InputDecoration decoration({
      String? hintText,
    }) {
      return InputDecoration(
        labelText: field.label,
        hintText: hintText ?? 'Enter ${field.label}',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFDCE3EA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFDCE3EA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF0B5C9E),
            width: 1.5,
          ),
        ),
      );
    }

    String? validateValue(String? value) {
      if (field.required &&
          (value == null || value.trim().isEmpty)) {
        return '${field.label} is required';
      }

      if (field.type == 'phone' &&
          value != null &&
          value.trim().isNotEmpty &&
          value.trim().length < 10) {
        return 'Enter a valid mobile number';
      }

      return null;
    }

    if (field.type == 'dropdown') {
      final options = field.options;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: controller.text.trim().isEmpty
              ? null
              : controller.text.trim(),
          isExpanded: true,
          decoration: decoration(
            hintText: 'Select ${field.label}',
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: options.isEmpty
              ? null
              : (value) {
                  controller.text = value ?? '';
                },
          validator: validateValue,
        ),
      );
    }


    if (field.type == 'auto') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: decoration(
            hintText: 'Auto assigned from Lead Collector',
          ).copyWith(
            suffixIcon: const Icon(Icons.auto_awesome_outlined),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'map') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          decoration: decoration(
            hintText: 'Enter/search location',
          ).copyWith(
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          decoration: decoration(
            hintText: 'Image path / URL',
          ).copyWith(
            prefixIcon: const Icon(Icons.image_outlined),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: decoration(
            hintText: 'Select ${field.label}',
          ).copyWith(
            suffixIcon: const Icon(
              Icons.calendar_month_outlined,
            ),
          ),
          validator: validateValue,
          onTap: () async {
            final now = DateTime.now();

            DateTime initialDate = now;

            final current =
                DateTime.tryParse(controller.text.trim());

            if (current != null) {
              initialDate = current;
            }

            final selected = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (selected == null) return;

            controller.text =
                '${selected.year.toString().padLeft(4, '0')}-'
                '${selected.month.toString().padLeft(2, '0')}-'
                '${selected.day.toString().padLeft(2, '0')}';
          },
        ),
      );
    }

    int maxLines = 1;
    if (field.type == 'textarea') {
      maxLines = 4;
    }

    TextInputType keyboardType = TextInputType.text;

    if (field.type == 'phone') {
      keyboardType = TextInputType.phone;
    } else if (field.type == 'number') {
      keyboardType = const TextInputType.numberWithOptions(
        decimal: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: decoration(),
        validator: validateValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0B5C9E),
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load form',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_schema == null) {
      return const Center(
        child: Text(
          'Form not available',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 980,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color:
                          const Color(
                        0xFFE3E9EF,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Text(
                        _schema!.title,
                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              Color(
                            0xFF17212B,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = _schema!.fields;
                          final useTwoColumns =
                              constraints.maxWidth >= 620;

                          if (!useTwoColumns) {
                            return Column(
                              children:
                                  fields.map(_buildField).toList(),
                            );
                          }

                          final rows = <Widget>[];

                          for (int i = 0;
                              i < fields.length;
                              i += 2) {
                            final left = fields[i];
                            final hasRight = i + 1 < fields.length;
                            final right =
                                hasRight ? fields[i + 1] : null;

                            // Keep auto Marketing Head full-width.
                            if (left.type == 'auto') {
                              rows.add(_buildField(left));
                              if (right != null) {
                                rows.add(_buildField(right));
                              }
                              continue;
                            }

                            // Keep image fields compact but paired like other fields.
                            rows.add(
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildField(left),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: right == null
                                        ? const SizedBox.shrink()
                                        : _buildField(right),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(children: rows);
                        },
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : _saveForm,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF0B5C9E,
                            ),
                            foregroundColor:
                                Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                9,
                              ),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_outlined,
                                ),
                          label: Text(
                            _saving
                                ? 'Saving...'
                                : 'Save Lead',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}