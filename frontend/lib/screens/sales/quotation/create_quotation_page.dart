import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key});

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final ApiClient _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  bool _loadingLeads = true;
  bool _loadingPrefill = false;
  bool _loadingForm = false;
  bool _saving = false;

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _fields = [];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};

  int? _selectedLeadId;
  String _quotationType = 'TRACTION';

  Map<String, dynamic> _prefill = {};

  final List<Map<String, String>> _types = const [
    {'id': 'TRACTION', 'name': 'Traction Lift'},
    {'id': 'GOODS', 'name': 'Goods Lift'},
    {'id': 'HYDRAULIC', 'name': 'Hydraulic Lift'},
    {'id': 'MRL_3_PHASE', 'name': 'MRL Lift - 3 Phase'},
    {'id': 'MRL_1_PHASE', 'name': 'MRL Lift - 1 Phase'},
    {
      'id': 'MRL_STRUCTURE',
      'name': 'MRL with Structure / Civil / Covering',
    },
  ];

  static const Set<String> _commercialKeys = {
    'price_including_gst',
    'license_fee',
    'quotation_validity',
    'cabin_model_no',
    'extra_payment',
  };

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLeads() async {
    try {
      final response = await _api.get('/api/v1/data/leads');

      List<dynamic> rows = [];

      if (response is List) {
        rows = response;
      } else if (response is Map) {
        final data = response['items'] ?? response['leads'] ?? response['data'];

        if (data is List) {
          rows = data;
        }
      }

      final parsed = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => row['id'] != null)
          .toList();

      if (!mounted) return;

      setState(() {
        _leads = parsed;
        _loadingLeads = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingLeads = false;
      });

      _message(
        'Unable to load leads: $e',
        error: true,
      );
    }
  }

  Future<void> _selectLead(int? leadId) async {
    if (leadId == null) return;

    setState(() {
      _selectedLeadId = leadId;
      _loadingPrefill = true;
      _prefill = {};
      _fields = [];
    });

    try {
      final response = await _api.get(
        '/api/v1/quotations/prefill/$leadId',
      );

      if (!mounted) return;

      setState(() {
        if (response is Map) {
          _prefill = Map<String, dynamic>.from(response);
        }

        _loadingPrefill = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPrefill = false;
      });

      _message(
        'Unable to load customer details: $e',
        error: true,
      );
    }
  }

  Future<void> _loadQuotationForm() async {
    if (_selectedLeadId == null) {
      _message(
        'Please select a Lead',
        error: true,
      );
      return;
    }

    if (_quotationType != 'TRACTION') {
      _message(
        '$_quotationType format will be configured after Traction.',
      );
      return;
    }

    setState(() {
      _loadingForm = true;
      _fields = [];
      _values.clear();
    });

    try {
      final response = await _api.get(
        '/api/v1/quotation-form-definition'
        '?quotation_type=$_quotationType',
      );

      final rawFields = response is Map ? response['fields'] : null;

      if (rawFields is! List) {
        throw Exception(
          'Invalid quotation form definition',
        );
      }

      final fields = rawFields
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList();

      for (final controller in _controllers.values) {
        controller.dispose();
      }

      _controllers.clear();

      for (final field in fields) {
        final key = '${field['key'] ?? ''}';
        final type = '${field['type'] ?? 'text'}';

        if (key.isEmpty) continue;

        if (type == 'dropdown' || type == 'choice') {
          _values[key] = null;
        } else {
          _controllers[key] = TextEditingController();
        }
      }

      // Lead Lift Type can prefill the quotation Lift Type
      // when the same option exists in Data Master.
      final leadLiftType = '${_prefill['lift_type'] ?? ''}'.trim();

      for (final field in fields) {
        if (field['key'] != 'lift_type' || leadLiftType.isEmpty) {
          continue;
        }

        final options = _options(field);

        if (options.any(
          (option) => option['value'] == leadLiftType,
        )) {
          _values['lift_type'] = leadLiftType;
        }
      }

      if (!mounted) return;

      setState(() {
        _fields = fields;
        _loadingForm = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingForm = false;
      });

      _message(
        'Unable to load quotation form: $e',
        error: true,
      );
    }
  }

  List<Map<String, String>> _options(
    Map<String, dynamic> field,
  ) {
    final raw = field['options'];

    if (raw is! List) return [];

    return raw
        .map<Map<String, String>>((item) {
          if (item is Map) {
            final value =
                '${item['value'] ?? item['name'] ?? item['label'] ?? ''}';

            final label = '${item['label'] ?? item['name'] ?? value}';

            return {
              'value': value,
              'label': label,
            };
          }

          return {
            'value': '$item',
            'label': '$item',
          };
        })
        .where(
          (item) => item['value']!.trim().isNotEmpty,
        )
        .toList();
  }

  Widget _buildDynamicField(
    Map<String, dynamic> field,
  ) {
    final key = '${field['key'] ?? ''}';
    final label = '${field['label'] ?? key}';
    final type = '${field['type'] ?? 'text'}';
    final required = field['required'] == true;

    final displayLabel = required ? '$label *' : label;

    if (type == 'dropdown' || type == 'choice') {
      final options = _options(field);

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: _values[key],
          isExpanded: true,
          decoration: InputDecoration(
            labelText: displayLabel,
            border: const OutlineInputBorder(),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(
                    option['label']!,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
          onChanged: (value) {
            _values[key] = value;
          },
        ),
      );
    }

    final controller = _controllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );

    final isNumber = type == 'number';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(
                decimal: true,
              )
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: displayLabel,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (required && text.isEmpty) {
            return '$label is required';
          }

          if (isNumber && text.isNotEmpty && double.tryParse(text) == null) {
            return 'Enter a valid number';
          }

          return null;
        },
      ),
    );
  }

  dynamic _fieldValue(
    Map<String, dynamic> field,
  ) {
    final key = '${field['key'] ?? ''}';
    final type = '${field['type'] ?? 'text'}';

    if (type == 'dropdown' || type == 'choice') {
      return _values[key];
    }

    final text = _controllers[key]?.text.trim() ?? '';

    if (text.isEmpty) return null;

    if (type == 'number') {
      return double.tryParse(text) ?? text;
    }

    return text;
  }

  Future<void> _saveDraft() async {
    if (_selectedLeadId == null) {
      _message(
        'Please select a Lead',
        error: true,
      );
      return;
    }

    if (_fields.isEmpty) {
      _message(
        'Load Technical Specification first',
        error: true,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      _message(
        'Please complete the required fields',
        error: true,
      );
      return;
    }

    final technicalData = <String, dynamic>{};

    final commercialData = <String, dynamic>{};

    for (final field in _fields) {
      final key = '${field['key'] ?? ''}';
      final value = _fieldValue(field);

      if (_commercialKeys.contains(key)) {
        commercialData[key] = value;
      } else {
        technicalData[key] = value;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await _api.post(
        '/api/v1/quotations',
        {
          'lead_id': _selectedLeadId,
          'quotation_type': _quotationType,
          'technical_data': technicalData,
          'commercial_data': commercialData,
          'gst_percent': 18,
        },
      );

      if (!mounted) return;

      String quotationNo = '';

      if (response is Map) {
        quotationNo = '${response['quotation_no'] ?? ''}';
      }

      _message(
        quotationNo.isEmpty
            ? 'Quotation Draft saved successfully'
            : 'Quotation $quotationNo saved successfully',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      _message(
        'Unable to save quotation: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _text(String key) {
    final value = _prefill[key];

    if (value == null) return '-';

    final result = value.toString().trim();

    return result.isEmpty ? '-' : result;
  }

  void _message(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Widget _info(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 165,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF52606D),
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _leadLabel(
    Map<String, dynamic> lead,
  ) {
    final id = '${lead['lead_id'] ?? lead['id'] ?? ''}';

    final customer = '${lead['customer_name'] ?? ''}'.trim();

    final building = '${lead['construction_building_name'] ?? ''}'.trim();

    if (building.isNotEmpty) {
      return '$id • $customer • $building';
    }

    return '$id • $customer';
  }

  @override
  Widget build(BuildContext context) {
    final technicalFields = _fields
        .where(
          (field) => !_commercialKeys.contains(
            '${field['key']}',
          ),
        )
        .toList();

    final commercialFields = _fields
        .where(
          (field) => _commercialKeys.contains(
            '${field['key']}',
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Create Quotation'),
        backgroundColor: const Color(0xFF0B5C9E),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lead & Customer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingLeads)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedLeadId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Lead *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.person_search,
                          ),
                        ),
                        items: _leads
                            .map(
                              (lead) => DropdownMenuItem<int>(
                                value: lead['id'] as int,
                                child: Text(
                                  _leadLabel(lead),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _selectLead,
                      ),
                    if (_loadingPrefill) ...[
                      const SizedBox(
                        height: 18,
                      ),
                      const LinearProgressIndicator(),
                    ],
                    if (_prefill.isNotEmpty) ...[
                      const SizedBox(
                        height: 18,
                      ),
                      const Divider(),
                      const SizedBox(
                        height: 10,
                      ),
                      _info(
                        'Lead ID',
                        _text(
                          'lead_display_id',
                        ),
                      ),
                      _info(
                        'Lead Collection By',
                        _text(
                          'lead_collection_by',
                        ),
                      ),
                      _info(
                        'Marketing By',
                        _text(
                          'marketing_by',
                        ),
                      ),
                      _info(
                        'Customer Name',
                        _text(
                          'customer_name',
                        ),
                      ),
                      _info(
                        'Building Name',
                        _text(
                          'construction_building_name',
                        ),
                      ),
                      _info(
                        'Contact No.',
                        _text(
                          'contact_no',
                        ),
                      ),
                      _info(
                        'Office Address',
                        _text(
                          'office_address',
                        ),
                      ),
                      _info(
                        'Site Address',
                        _text(
                          'site_address',
                        ),
                      ),
                      _info(
                        'Location',
                        _text(
                          'location',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quotation Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _quotationType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quotation Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: _types
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type['id'],
                              child: Text(
                                type['name']!,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _fields.isNotEmpty
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _quotationType = value;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadingForm || _loadingPrefill
                            ? null
                            : _loadQuotationForm,
                        icon: const Icon(
                          Icons.settings,
                        ),
                        label: Text(
                          _fields.isEmpty
                              ? 'Load Technical Specification'
                              : 'Reload Technical Specification',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loadingForm) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
            if (technicalFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elevator Technical Specification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      ...technicalFields.map(
                        _buildDynamicField,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (commercialFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commercial Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      ...commercialFields.map(
                        _buildDynamicField,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_fields.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveDraft,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.save_outlined,
                        ),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Quotation Draft',
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
