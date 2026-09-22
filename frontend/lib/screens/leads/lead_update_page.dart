import 'package:flutter/material.dart';

import '../../services/services.dart';

class LeadUpdatePage extends StatefulWidget {
  final LeadService leadService;
  final Map<String, dynamic>? lead;

  const LeadUpdatePage({
    super.key,
    required this.leadService,
    this.lead,
  });

  @override
  State<LeadUpdatePage> createState() =>
      _LeadUpdatePageState();
}

class _LeadUpdatePageState extends State<LeadUpdatePage> {
  final _formKey = GlobalKey<FormState>();

  // =========================================================
  // CONTROLLERS
  // =========================================================

  final _customerNameController =
      TextEditingController();

  final _mobileController =
      TextEditingController();

  final _locationController =
      TextEditingController();

  final _leadSourceController =
      TextEditingController();

  final _buildingTypeController =
      TextEditingController();

  final _liftTypeController =
      TextEditingController();

  final _requirementTimeController =
      TextEditingController();

  final _marketingHeadController =
      TextEditingController();

  final _leadStatusController =
      TextEditingController();

  final _followUpDateController =
      TextEditingController();

  final _revisitDateController =
      TextEditingController();

  final _orderValueController =
      TextEditingController();

  final _remarksController =
      TextEditingController();

  // =========================================================
  // PIPELINE VALUES
  // =========================================================

  bool _overPhone = false;
  bool _callDone = false;
  bool _appointmentFixed = false;
  bool _siteVisitDone = false;
  bool _surveyDone = false;
  bool _quotationGiven = false;
  bool _negotiationDone = false;
  bool _orderFinalized = false;

  // =========================================================
  // PAGE STATE
  // =========================================================

  bool _loading = true;
  bool _saving = false;

  String? _error;

  List<Map<String, dynamic>> _leads = [];

  Map<String, dynamic>? _selectedLead;

  // =========================================================
  // LEAD STATUS OPTIONS
  // =========================================================

  final List<String> _statusOptions = const [
    'New Lead',
    'Call Done',
    'Appointment Fixed',
    'Site Visit Done',
    'Survey Done',
    'Quotation Given',
    'Negotiation',
    'Order Finalized',
    'Lost',
    'Hold',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.lead != null) {
      _selectedLead =
          Map<String, dynamic>.from(
        widget.lead!,
      );

      _fillForm(_selectedLead!);

      _loading = false;
    } else {
      _loadLeads();
    }
  }

  // =========================================================
  // BOOL CONVERTER
  // =========================================================

  bool _asBool(dynamic value) {
    if (value == true) {
      return true;
    }

    if (value is String) {
      final text =
          value.trim().toLowerCase();

      return text == 'true' ||
          text == 'yes' ||
          text == '1';
    }

    if (value is num) {
      return value == 1;
    }

    return false;
  }

  // =========================================================
  // LOAD ALL LEADS
  // =========================================================

  Future<void> _loadLeads() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final leads =
          await widget.leadService.load();

      if (!mounted) return;

      setState(() {
        _leads = leads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // FILL FORM
  // =========================================================

  void _fillForm(
    Map<String, dynamic> lead,
  ) {
    _customerNameController.text =
        lead['customer_name']
                ?.toString() ??
            '';

    _mobileController.text =
        lead['mobile']
                ?.toString() ??
            '';

    _locationController.text =
        lead['location']
                ?.toString() ??
            '';

    _leadSourceController.text =
        lead['lead_source']
                ?.toString() ??
            '';

    _buildingTypeController.text =
        lead['building_type']
                ?.toString() ??
            '';

    _liftTypeController.text =
        lead['lift_type']
                ?.toString() ??
            '';

    _requirementTimeController.text =
        lead['requirement_time']
                ?.toString() ??
            '';

    _marketingHeadController.text =
        lead['marketing_head']
                ?.toString() ??
            '';

    _leadStatusController.text =
        lead['lead_status']
                ?.toString() ??
            'New Lead';

    _followUpDateController.text =
        _displayDate(
      lead['follow_up_date'],
    );

    _revisitDateController.text =
        _displayDate(
      lead['revisit_date'],
    );

    _orderValueController.text =
        _cleanAmount(
      lead['order_value'],
    );

    _remarksController.text =
        lead['remarks']
                ?.toString() ??
            '';

    _overPhone =
        _asBool(
      lead['over_phone'],
    );

    _callDone =
        _asBool(
      lead['call_done'],
    );

    _appointmentFixed =
        _asBool(
      lead['appointment_fixed'],
    );

    _siteVisitDone =
        _asBool(
      lead['site_visit_done'],
    );

    _surveyDone =
        _asBool(
      lead['survey_done'],
    );

    _quotationGiven =
        _asBool(
      lead['quotation_given'],
    );

    _negotiationDone =
        _asBool(
      lead['negotiation_done'],
    );

    _orderFinalized =
        _asBool(
      lead['order_finalized'],
    );
  }

  // =========================================================
  // AMOUNT HELPER
  // =========================================================

  String _cleanAmount(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    if (value is int) {
      return value.toString();
    }

    if (value is double) {
      if (value ==
          value.roundToDouble()) {
        return value
            .toInt()
            .toString();
      }

      return value.toString();
    }

    return value.toString();
  }

  // =========================================================
  // DATE HELPERS
  // =========================================================

  String _displayDate(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return '';
    }

    final date =
        DateTime.tryParse(text);

    if (date == null) {
      return text;
    }

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  DateTime? _controllerDate(
    TextEditingController controller,
  ) {
    final text =
        controller.text.trim();

    if (text.isEmpty) {
      return null;
    }

    final parts =
        text.split('/');

    if (parts.length != 3) {
      return null;
    }

    final day =
        int.tryParse(parts[0]);

    final month =
        int.tryParse(parts[1]);

    final year =
        int.tryParse(parts[2]);

    if (day == null ||
        month == null ||
        year == null) {
      return null;
    }

    return DateTime(
      year,
      month,
      day,
    );
  }

  String? _apiDate(
    TextEditingController controller,
  ) {
    final date =
        _controllerDate(
      controller,
    );

    if (date == null) {
      return null;
    }

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate(
    TextEditingController controller,
  ) async {
    final current =
        _controllerDate(
          controller,
        ) ??
        DateTime.now();

    final result =
        await showDatePicker(
      context: context,
      initialDate: current,
      firstDate:
          DateTime(2020),
      lastDate: DateTime(
        DateTime.now().year + 5,
      ),
    );

    if (result == null) {
      return;
    }

    final day =
        result.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        result.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    setState(() {
      controller.text =
          '$day/$month/${result.year}';
    });
  }

  // =========================================================
  // SELECT LEAD
  // =========================================================

  void _selectLead(
    Map<String, dynamic> lead,
  ) {
    setState(() {
      _selectedLead =
          Map<String, dynamic>.from(
        lead,
      );

      _fillForm(
        _selectedLead!,
      );
    });
  }

  // =========================================================
  // SAVE UPDATE
  // =========================================================

  Future<void> _saveLead() async {
    if (_selectedLead == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a lead first',
          ),
        ),
      );

      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final idValue =
        _selectedLead!['id'];

    final leadId =
        idValue is int
            ? idValue
            : int.tryParse(
                idValue.toString(),
              );

    if (leadId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid Lead ID',
          ),
          backgroundColor:
              Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final orderValue =
          double.tryParse(
                _orderValueController
                    .text
                    .trim()
                    .replaceAll(
                      ',',
                      '',
                    ),
              ) ??
              0;

      final payload =
          <String, dynamic>{
        'customer_name':
            _customerNameController
                .text
                .trim(),

        'mobile':
            _mobileController
                .text
                .trim(),

        'location':
            _locationController
                .text
                .trim(),

        'lead_source':
            _leadSourceController
                .text
                .trim(),

        'building_type':
            _buildingTypeController
                .text
                .trim(),

        'lift_type':
            _liftTypeController
                .text
                .trim(),

        'requirement_time':
            _requirementTimeController
                .text
                .trim(),

        'marketing_head':
            _marketingHeadController
                .text
                .trim(),

        'lead_status':
            _leadStatusController
                .text
                .trim(),

        'over_phone':
            _overPhone,

        'call_done':
            _callDone,

        'appointment_fixed':
            _appointmentFixed,

        'site_visit_done':
            _siteVisitDone,

        'survey_done':
            _surveyDone,

        'quotation_given':
            _quotationGiven,

        'negotiation_done':
            _negotiationDone,

        'order_finalized':
            _orderFinalized,

        'order_value':
            orderValue,

        'follow_up_date':
            _apiDate(
              _followUpDateController,
            ),

        'revisit_date':
            _apiDate(
              _revisitDateController,
            ),

        'remarks':
            _remarksController
                .text
                .trim(),
      };

      final updated =
          await widget.leadService.update(
        leadId,
        payload,
      );

      if (!mounted) return;

      setState(() {
        _selectedLead =
            Map<String, dynamic>.from(
          updated,
        );

        _fillForm(
          _selectedLead!,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Lead updated successfully',
          ),
          backgroundColor:
              Colors.green,
        ),
      );

      Navigator.pop(
        context,
        updated,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Update failed: $e',
          ),
          backgroundColor:
              Colors.red,
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

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          Icon(icon),
      filled: true,
      fillColor:
          Colors.white,
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          9,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFFDCE3EA,
          ),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          9,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFF0B5C9E,
          ),
          width: 1.5,
        ),
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _textField({
    required String label,
    required IconData icon,
    required TextEditingController
        controller,
    TextInputType keyboardType =
        TextInputType.text,
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType:
            keyboardType,
        maxLines:
            maxLines,
        decoration:
            _decoration(
          label: label,
          icon: icon,
        ),
        validator: (value) {
          if (required &&
              (value == null ||
                  value
                      .trim()
                      .isEmpty)) {
            return '$label is required';
          }

          return null;
        },
      ),
    );
  }

  // =========================================================
  // DATE FIELD
  // =========================================================

  Widget _dateField({
    required String label,
    required TextEditingController
        controller,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () {
          _pickDate(
            controller,
          );
        },
        decoration:
            _decoration(
          label: label,
          icon: Icons
              .calendar_month_outlined,
        ).copyWith(
          suffixIcon:
              controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip:
                          'Clear',
                      onPressed: () {
                        setState(() {
                          controller
                              .clear();
                        });
                      },
                      icon:
                          const Icon(
                        Icons.clear,
                      ),
                    ),
        ),
      ),
    );
  }

  // =========================================================
  // SWITCH TILE
  // =========================================================

  Widget _switchTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>
        onChanged,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          9,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE1E7ED,
          ),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged:
            onChanged,
        activeThumbColor:
            const Color(
          0xFF0B5C9E,
        ),
        secondary:
            Icon(
          icon,
          color:
              const Color(
            0xFF0B5C9E,
          ),
        ),
        title:
            Text(
          title,
          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SECTION
  // =========================================================

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          11,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE1E7ED,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color:
                    const Color(
                  0xFF0B5C9E,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          ...children,
        ],
      ),
    );
  }

  // =========================================================
  // LEAD SELECTOR
  // =========================================================

  Widget _leadSelector() {
    if (_selectedLead != null) {
      return const SizedBox.shrink();
    }

    if (_leads.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.all(
          24,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            11,
          ),
        ),
        child:
            const Center(
          child:
              Text(
            'No leads available',
          ),
        ),
      );
    }

    return _section(
      title:
          'Select Lead',
      icon:
          Icons.search_rounded,
      children: [
        ..._leads.map(
          (lead) {
            final id =
                lead['id']
                        ?.toString() ??
                    '';

            final customer =
                lead['customer_name']
                        ?.toString() ??
                    'Unnamed Customer';

            final mobile =
                lead['mobile']
                        ?.toString() ??
                    '';

            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              decoration:
                  BoxDecoration(
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFE1E7ED,
                  ),
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  9,
                ),
              ),
              child:
                  ListTile(
                leading:
                    const CircleAvatar(
                  child:
                      Icon(
                    Icons.person_outline,
                  ),
                ),
                title:
                    Text(
                  customer,
                ),
                subtitle:
                    Text(
                  mobile,
                ),
                trailing:
                    Text(
                  '#$id',
                ),
                onTap: () {
                  _selectLead(
                    lead,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // STATUS DROPDOWN
  // =========================================================

  Widget _statusDropdown() {
    final current =
        _leadStatusController
            .text
            .trim();

    final value =
        _statusOptions.contains(
          current,
        )
            ? current
            : null;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child:
          DropdownButtonFormField<String>(
        initialValue:
            value,
        decoration:
            _decoration(
          label:
              'Lead Status',
          icon:
              Icons.flag_outlined,
        ),
        hint:
            const Text(
          'Select Lead Status',
        ),
        items:
            _statusOptions
                .map(
                  (status) =>
                      DropdownMenuItem<
                          String>(
                    value:
                        status,
                    child:
                        Text(
                      status,
                    ),
                  ),
                )
                .toList(),
        onChanged:
            (value) {
          if (value == null) {
            return;
          }

          setState(() {
            _leadStatusController
                    .text =
                value;
          });
        },
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF4F7FB,
      ),
      appBar: AppBar(
        backgroundColor:
            const Color(
          0xFF0B5C9E,
        ),
        foregroundColor:
            Colors.white,
        title:
            const Text(
          'Lead Update',
        ),
        actions: [
          if (widget.lead ==
              null)
            IconButton(
              tooltip:
                  'Reload Leads',
              onPressed:
                  _loadLeads,
              icon:
                  const Icon(
                Icons.refresh_rounded,
              ),
            ),
        ],
      ),
      body:
          _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color:
                    Colors.redAccent,
              ),
              const SizedBox(
                height: 12,
              ),
              const Text(
                'Unable to load leads',
                style:
                    TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 18,
              ),
              ElevatedButton.icon(
                onPressed:
                    _loadLeads,
                icon:
                    const Icon(
                  Icons.refresh,
                ),
                label:
                    const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedLead ==
        null) {
      return SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            _leadSelector(),
      );
    }

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(
        16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 760,
          ),
          child: Form(
            key:
                _formKey,
            child: Column(
              children: [
                // ===========================================
                // CUSTOMER / LEAD DETAILS
                // ===========================================

                _section(
                  title:
                      'Lead Details',
                  icon:
                      Icons.person_outline,
                  children: [
                    _textField(
                      label:
                          'Customer Name',
                      icon:
                          Icons.person_outline,
                      controller:
                          _customerNameController,
                      required:
                          true,
                    ),

                    _textField(
                      label:
                          'Mobile',
                      icon:
                          Icons.phone_outlined,
                      controller:
                          _mobileController,
                      keyboardType:
                          TextInputType.phone,
                      required:
                          true,
                    ),

                    _textField(
                      label:
                          'Location',
                      icon:
                          Icons.location_on_outlined,
                      controller:
                          _locationController,
                    ),

                    _textField(
                      label:
                          'Lead Source',
                      icon:
                          Icons.campaign_outlined,
                      controller:
                          _leadSourceController,
                    ),

                    _textField(
                      label:
                          'Building Type',
                      icon:
                          Icons.apartment_outlined,
                      controller:
                          _buildingTypeController,
                    ),

                    _textField(
                      label:
                          'Lift Type',
                      icon:
                          Icons.elevator_outlined,
                      controller:
                          _liftTypeController,
                    ),

                    _textField(
                      label:
                          'Requirement Time',
                      icon:
                          Icons.schedule_outlined,
                      controller:
                          _requirementTimeController,
                    ),

                    _textField(
                      label:
                          'Assigned Marketing Head',
                      icon:
                          Icons.badge_outlined,
                      controller:
                          _marketingHeadController,
                    ),

                    _statusDropdown(),
                  ],
                ),

                // ===========================================
                // SALES PIPELINE
                // ===========================================

                _section(
                  title:
                      'Sales Pipeline',
                  icon:
                      Icons.trending_up_rounded,
                  children: [
                    _switchTile(
                      title:
                          'Call Done',
                      icon:
                          Icons.phone_callback_outlined,
                      value:
                          _callDone,
                      onChanged:
                          (value) {
                        setState(() {
                          _callDone =
                              value;
                        });
                      },
                    ),

                    _switchTile(
                      title:
                          'Appointment Fixed',
                      icon:
                          Icons.event_available_outlined,
                      value:
                          _appointmentFixed,
                      onChanged:
                          (value) {
                        setState(() {
                          _appointmentFixed =
                              value;

                          if (value) {
                            _callDone =
                                true;
                          }
                        });
                      },
                    ),

                    _switchTile(
                      title:
                          'Site Visit Done',
                      icon:
                          Icons.location_on_outlined,
                      value:
                          _siteVisitDone,
                      onChanged:
                          (value) {
                        setState(() {
                          _siteVisitDone =
                              value;

                          if (value) {
                            _callDone =
                                true;

                            _appointmentFixed =
                                true;
                          }
                        });
                      },
                    ),

                    _switchTile(
                      title:
                          'Survey Done',
                      icon:
                          Icons.fact_check_outlined,
                      value:
                          _surveyDone,
                      onChanged:
                          (value) {
                        setState(() {
                          _surveyDone =
                              value;

                          if (value) {
                            _callDone =
                                true;

                            _appointmentFixed =
                                true;

                            _siteVisitDone =
                                true;
                          }
                        });
                      },
                    ),

                    _switchTile(
                      title:
                          'Quotation Given',
                      icon:
                          Icons.request_quote_outlined,
                      value:
                          _quotationGiven,
                      onChanged:
                          (value) {
                        setState(() {
                          _quotationGiven =
                              value;

                          if (value) {
                            _callDone =
                                true;

                            _appointmentFixed =
                                true;

                            _siteVisitDone =
                                true;

                            _surveyDone =
                                true;
                          }
                        });
                      },
                    ),

                    _switchTile(
                      title:
                          'Negotiation Done',
                      icon:
                          Icons.handshake_outlined,
                      value:
                          _negotiationDone,
                      onChanged:
                          (value) {
                        setState(() {
                          _negotiationDone =
                              value;

                          if (value) {
                            _callDone =
                                true;

                            _appointmentFixed =
                                true;

                            _siteVisitDone =
                                true;

                            _surveyDone =
                                true;

                            _quotationGiven =
                                true;
                          }
                        });
                      },
                    ),

                    _switchTile(
  title: 'Order Finalized',
  icon: Icons.shopping_cart_checkout_outlined,
  value: _orderFinalized,
  onChanged: (value) {
    setState(() {
      _orderFinalized = value;

      if (value) {
        _callDone = true;
        _appointmentFixed = true;
        _siteVisitDone = true;
        _surveyDone = true;
        _quotationGiven = true;
        _negotiationDone = true;

        _leadStatusController.text =
            'Order Finalized';
      }
    });
  },
),

const SizedBox(
  height: 4,
),

TextFormField(
  controller: _orderValueController,
  keyboardType:
      const TextInputType.numberWithOptions(
    decimal: true,
  ),
  decoration: _decoration(
    label: 'Order Value',
    icon: Icons.currency_rupee,
    hint: 'Enter finalized order value',
  ),
  validator: (value) {
    if (_orderFinalized) {
      if (value == null ||
          value.trim().isEmpty) {
        return 'Order Value is required';
      }

      final amount = double.tryParse(
        value
            .replaceAll(',', '')
            .trim(),
      );

      if (amount == null ||
          amount <= 0) {
        return 'Enter valid Order Value';
      }
    }

    return null;
  },
),

// Sales Pipeline children close
],
),

                // ===========================================
                // FOLLOW-UP
                // ===========================================

                _section(
                  title:
                      'Follow-up & Remarks',
                  icon:
                      Icons.event_repeat_rounded,
                  children: [
                    _switchTile(
                      title: 'Over Phone',
                      icon: Icons.phone_in_talk_outlined,
                      value: _overPhone,
                      onChanged: (value) {
                    setState(() {
                      _overPhone = value;
                        });
                      },
                    ),

const SizedBox(height: 4),
                    _dateField(
                      label:
                          'Follow-up Date',
                      controller:
                          _followUpDateController,
                    ),

                    _dateField(
                      label:
                          'Revisit Date',
                      controller:
                          _revisitDateController,
                    ),

                    _textField(
                      label:
                          'Remarks',
                      icon:
                          Icons.notes_outlined,
                      controller:
                          _remarksController,
                      maxLines:
                          4,
                    ),
                  ],
                ),

                // ===========================================
                // SAVE BUTTON
                // ===========================================

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      50,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : _saveLead,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF0B5C9E,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                      ),
                    ),
                    icon:
                        _saving
                            ? const SizedBox(
                                width:
                                    19,
                                height:
                                    19,
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
                    label:
                        Text(
                      _saving
                          ? 'Updating...'
                          : 'Update Lead',
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _customerNameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _leadSourceController.dispose();
    _buildingTypeController.dispose();
    _liftTypeController.dispose();
    _requirementTimeController.dispose();
    _marketingHeadController.dispose();
    _leadStatusController.dispose();

    _followUpDateController.dispose();
    _revisitDateController.dispose();

    _orderValueController.dispose();

    _remarksController.dispose();

    super.dispose();
  }
}