import 'package:flutter/material.dart';

import '../../services/services.dart';

class TargetsPage extends StatefulWidget {
  final LeadService leadService;

  const TargetsPage({
    super.key,
    required this.leadService,
  });

  @override
  State<TargetsPage> createState() =>
      _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage> {
  final _formKey = GlobalKey<FormState>();

  final _employeeController =
      TextEditingController();

  final _roleController =
      TextEditingController();

  final _leadTargetController =
      TextEditingController(text: '0');

  final _callTargetController =
      TextEditingController(text: '0');

  final _appointmentTargetController =
      TextEditingController(text: '0');

  final _siteVisitTargetController =
      TextEditingController(text: '0');

  final _surveyTargetController =
      TextEditingController(text: '0');

  final _quotationTargetController =
      TextEditingController(text: '0');

  final _orderTargetController =
      TextEditingController(text: '0');

  final _orderValueTargetController =
      TextEditingController(text: '0');

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _toDate = DateTime.now();

  List<Map<String, dynamic>> _allLeads = [];

  bool _loading = true;
  bool _calculating = false;

  String? _error;

  int _leadAchievement = 0;
  int _callAchievement = 0;
  int _appointmentAchievement = 0;
  int _siteVisitAchievement = 0;
  int _surveyAchievement = 0;
  int _quotationAchievement = 0;
  int _orderAchievement = 0;

  double _orderValueAchievement = 0;

  @override
  void initState() {
    super.initState();

    _loadLeads();
  }

  // =========================================================
  // LOAD LEADS FROM BACKEND
  // =========================================================

  Future<void> _loadLeads() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final leads =
          await widget.leadService.load();

      if (!mounted) return;

      setState(() {
        _allLeads = leads;
        _loading = false;
      });

      _calculateAchievements(
        showMessage: false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // HELPERS
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  DateTime? _leadDate(
    Map<String, dynamic> lead,
  ) {
    return _parseDate(
      lead['lead_date'] ??
          lead['created_at'],
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _isInsideSelectedPeriod(
    Map<String, dynamic> lead,
  ) {
    final date =
        _leadDate(lead);

    if (date == null) {
      return false;
    }

    final leadDate =
        _dateOnly(date);

    final from =
        _dateOnly(_fromDate);

    final to =
        _dateOnly(_toDate);

    return !leadDate.isBefore(from) &&
        !leadDate.isAfter(to);
  }

  bool _matchesEmployee(
    Map<String, dynamic> lead,
  ) {
    final selectedEmployee =
        _employeeController.text
            .trim()
            .toLowerCase();

    // Blank employee = all employees.
    if (selectedEmployee.isEmpty) {
      return true;
    }

    final marketingHead =
        lead['marketing_head']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    return marketingHead ==
        selectedEmployee;
  }

  int _number(
    TextEditingController controller,
  ) {
    return int.tryParse(
          controller.text.trim(),
        ) ??
        0;
  }

  double _amount(
    TextEditingController controller,
  ) {
    return double.tryParse(
          controller.text.trim(),
        ) ??
        0;
  }

  double _percentage(
    num achievement,
    num target,
  ) {
    if (target <= 0) {
      return 0;
    }

    return (achievement / target) *
        100;
  }

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  // =========================================================
  // CALCULATE REAL ACHIEVEMENTS
  // =========================================================

  void _calculateAchievements({
    bool showMessage = true,
  }) {
    if (_toDate.isBefore(
      _fromDate,
    )) {
      return;
    }

    if (mounted) {
      setState(() {
        _calculating = true;
      });
    }

    final selectedLeads =
        _allLeads.where((lead) {
      return _isInsideSelectedPeriod(
            lead,
          ) &&
          _matchesEmployee(lead);
    }).toList();

    final leadAchievement =
        selectedLeads.length;

    final callAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead['call_done'],
              ),
            )
            .length;

    final appointmentAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead[
                    'appointment_fixed'],
              ),
            )
            .length;

    final siteVisitAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead[
                    'site_visit_done'],
              ),
            )
            .length;

    final surveyAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead['survey_done'],
              ),
            )
            .length;

    final quotationAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead[
                    'quotation_given'],
              ),
            )
            .length;

    final orderAchievement =
        selectedLeads
            .where(
              (lead) => _asBool(
                lead[
                    'order_finalized'],
              ),
            )
            .length;

    double orderValueAchievement = 0;

    for (final lead
        in selectedLeads) {
      if (!_asBool(
        lead['order_finalized'],
      )) {
        continue;
      }

      final value =
          lead['order_value'];

      if (value is num) {
        orderValueAchievement +=
            value.toDouble();
      } else if (value != null) {
        orderValueAchievement +=
            double.tryParse(
                  value.toString(),
                ) ??
                0;
      }
    }

    if (!mounted) return;

    setState(() {
      _leadAchievement =
          leadAchievement;

      _callAchievement =
          callAchievement;

      _appointmentAchievement =
          appointmentAchievement;

      _siteVisitAchievement =
          siteVisitAchievement;

      _surveyAchievement =
          surveyAchievement;

      _quotationAchievement =
          quotationAchievement;

      _orderAchievement =
          orderAchievement;

      _orderValueAchievement =
          orderValueAchievement;

      _calculating = false;
    });

    if (showMessage) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Achievement calculated from actual lead data',
          ),
          backgroundColor:
              Colors.green,
        ),
      );
    }
  }

  // =========================================================
  // DATE PICKERS
  // =========================================================

  Future<void> _selectFromDate() async {
    final result =
        await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        DateTime.now().year + 5,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _fromDate = result;

      if (_toDate.isBefore(
        _fromDate,
      )) {
        _toDate = result;
      }
    });

    _calculateAchievements(
      showMessage: false,
    );
  }

  Future<void> _selectToDate() async {
    final result =
        await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(
        DateTime.now().year + 5,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _toDate = result;
    });

    _calculateAchievements(
      showMessage: false,
    );
  }

  // =========================================================
  // DECORATION
  // =========================================================

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(9),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(9),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFDCE3EA),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(9),
        borderSide:
            const BorderSide(
          color:
              Color(0xFF0B5C9E),
          width: 1.5,
        ),
      ),
    );
  }

  // =========================================================
  // NUMBER FIELD
  // =========================================================

  Widget _numberField({
    required String label,
    required TextEditingController
        controller,
    required IconData icon,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType:
            TextInputType.number,
        decoration:
            _decoration(
          label,
          icon,
        ),
        onChanged: (_) {
          setState(() {});
        },
        validator: (value) {
          if (value == null ||
              value.trim().isEmpty) {
            return 'Enter $label';
          }

          if (double.tryParse(
                value.trim(),
              ) ==
              null) {
            return 'Enter valid number';
          }

          return null;
        },
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
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(11),
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
  // DATE TILE
  // =========================================================

  Widget _dateTile({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              const Color(
            0xFFDCE3EA,
          ),
        ),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: ListTile(
        leading: const Icon(
          Icons
              .calendar_month_outlined,
          color:
              Color(0xFF0B5C9E),
        ),
        title: Text(title),
        subtitle: Text(
          _formatDate(date),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  // =========================================================
  // ACHIEVEMENT ROW
  // =========================================================

  Widget _achievementRow({
    required String title,
    required num target,
    required num achievement,
    bool currency = false,
  }) {
    final percentage =
        _percentage(
      achievement,
      target,
    );

    final progress =
        percentage <= 0
            ? 0.0
            : percentage >= 100
                ? 1.0
                : percentage / 100;

    final targetText = currency
        ? '₹${target.toStringAsFixed(0)}'
        : target.toString();

    final achievementText =
        currency
            ? '₹${achievement.toStringAsFixed(0)}'
            : achievement.toString();

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 17,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$achievementText / $targetText',
                style:
                    const TextStyle(
                  fontSize: 12.5,
                  color:
                      Color(
                    0xFF5E6975,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              SizedBox(
                width: 65,
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  textAlign:
                      TextAlign.right,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(
                      0xFF0B5C9E,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 7,
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CALCULATE BUTTON
  // =========================================================

  void _calculateButton() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    _calculateAchievements();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final leadTarget =
        _number(
      _leadTargetController,
    );

    final callTarget =
        _number(
      _callTargetController,
    );

    final appointmentTarget =
        _number(
      _appointmentTargetController,
    );

    final siteVisitTarget =
        _number(
      _siteVisitTargetController,
    );

    final surveyTarget =
        _number(
      _surveyTargetController,
    );

    final quotationTarget =
        _number(
      _quotationTargetController,
    );

    final orderTarget =
        _number(
      _orderTargetController,
    );

    final orderValueTarget =
        _amount(
      _orderValueTargetController,
    );

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
            const Text('Targets'),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            onPressed:
                _loadLeads,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _buildBody(
        leadTarget:
            leadTarget,
        callTarget:
            callTarget,
        appointmentTarget:
            appointmentTarget,
        siteVisitTarget:
            siteVisitTarget,
        surveyTarget:
            surveyTarget,
        quotationTarget:
            quotationTarget,
        orderTarget:
            orderTarget,
        orderValueTarget:
            orderValueTarget,
      ),
    );
  }

  Widget _buildBody({
    required int leadTarget,
    required int callTarget,
    required int appointmentTarget,
    required int siteVisitTarget,
    required int surveyTarget,
    required int quotationTarget,
    required int orderTarget,
    required double orderValueTarget,
  }) {
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
                Icons
                    .error_outline,
                size: 48,
                color:
                    Colors.redAccent,
              ),
              const SizedBox(
                height: 12,
              ),
              const Text(
                'Unable to load target data',
                style: TextStyle(
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

    return RefreshIndicator(
      onRefresh: _loadLeads,
      child:
          SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 750,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // =========================================
                  // PERIOD + EMPLOYEE
                  // =========================================

                  _section(
                    title:
                        'Target Period & Employee',
                    icon:
                        Icons.badge_outlined,
                    children: [
                      TextFormField(
                        controller:
                            _employeeController,
                        decoration:
                            _decoration(
                          'Employee / Marketing Head',
                          Icons
                              .person_outline,
                        ),
                        onChanged: (_) {
                          _calculateAchievements(
                            showMessage:
                                false,
                          );
                        },
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextFormField(
                        controller:
                            _roleController,
                        decoration:
                            _decoration(
                          'Role',
                          Icons
                              .business_center_outlined,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _dateTile(
                        title:
                            'From Date',
                        date:
                            _fromDate,
                        onTap:
                            _selectFromDate,
                      ),

                      _dateTile(
                        title:
                            'To Date',
                        date:
                            _toDate,
                        onTap:
                            _selectToDate,
                      ),
                    ],
                  ),

                  // =========================================
                  // TARGET
                  // =========================================

                  _section(
                    title:
                        'Sales Targets',
                    icon: Icons
                        .track_changes_outlined,
                    children: [
                      _numberField(
                        label:
                            'Lead Target',
                        controller:
                            _leadTargetController,
                        icon: Icons
                            .people_outline,
                      ),

                      _numberField(
                        label:
                            'Call Target',
                        controller:
                            _callTargetController,
                        icon: Icons
                            .phone_outlined,
                      ),

                      _numberField(
                        label:
                            'Appointment Target',
                        controller:
                            _appointmentTargetController,
                        icon: Icons
                            .event_available_outlined,
                      ),

                      _numberField(
                        label:
                            'Site Visit Target',
                        controller:
                            _siteVisitTargetController,
                        icon: Icons
                            .location_on_outlined,
                      ),

                      _numberField(
                        label:
                            'Survey Target',
                        controller:
                            _surveyTargetController,
                        icon: Icons
                            .fact_check_outlined,
                      ),

                      _numberField(
                        label:
                            'Quotation Target',
                        controller:
                            _quotationTargetController,
                        icon: Icons
                            .request_quote_outlined,
                      ),

                      _numberField(
                        label:
                            'Order Target',
                        controller:
                            _orderTargetController,
                        icon: Icons
                            .shopping_cart_checkout_outlined,
                      ),

                      _numberField(
                        label:
                            'Order Value Target',
                        controller:
                            _orderValueTargetController,
                        icon: Icons
                            .currency_rupee,
                      ),
                    ],
                  ),

                  // =========================================
                  // ACHIEVEMENT
                  // =========================================

                  _section(
                    title:
                        'Actual Achievement',
                    icon: Icons
                        .analytics_outlined,
                    children: [
                      _achievementRow(
                        title: 'Lead',
                        target:
                            leadTarget,
                        achievement:
                            _leadAchievement,
                      ),

                      _achievementRow(
                        title: 'Call',
                        target:
                            callTarget,
                        achievement:
                            _callAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Appointment',
                        target:
                            appointmentTarget,
                        achievement:
                            _appointmentAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Site Visit',
                        target:
                            siteVisitTarget,
                        achievement:
                            _siteVisitAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Survey',
                        target:
                            surveyTarget,
                        achievement:
                            _surveyAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Quotation',
                        target:
                            quotationTarget,
                        achievement:
                            _quotationAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Order Finalized',
                        target:
                            orderTarget,
                        achievement:
                            _orderAchievement,
                      ),

                      _achievementRow(
                        title:
                            'Order Value',
                        target:
                            orderValueTarget,
                        achievement:
                            _orderValueAchievement,
                        currency: true,
                      ),
                    ],
                  ),

                  // =========================================
                  // CALCULATE
                  // =========================================

                  SizedBox(
                    width:
                        double.infinity,
                    height: 50,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _calculating
                              ? null
                              : _calculateButton,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF0B5C9E,
                        ),
                        foregroundColor:
                            Colors.white,
                      ),
                      icon:
                          _calculating
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
                                  Icons
                                      .calculate_outlined,
                                ),
                      label: Text(
                        _calculating
                            ? 'Calculating...'
                            : 'Calculate Achievement',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _roleController.dispose();

    _leadTargetController.dispose();
    _callTargetController.dispose();
    _appointmentTargetController.dispose();
    _siteVisitTargetController.dispose();
    _surveyTargetController.dispose();
    _quotationTargetController.dispose();
    _orderTargetController.dispose();
    _orderValueTargetController.dispose();

    super.dispose();
  }
}