import 'package:flutter/material.dart';

import '../../services/services.dart';
import '../leads/lead_update_page.dart';

class MarketingReportsPage extends StatefulWidget {
  final LeadService leadService;

  const MarketingReportsPage({
    super.key,
    required this.leadService,
  });

  @override
  State<MarketingReportsPage> createState() =>
      _MarketingReportsPageState();
}

class _MarketingReportsPageState
    extends State<MarketingReportsPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _reportLeads = [];

  bool _loading = true;
  String? _error;

  String _selectedReport = 'Appointment Fixed';

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _toDate = DateTime.now();

  final List<String> _reports = const [
    'Appointment Fixed',
    'Site Visit',
    'Survey',
    'Quotation',
    'Negotiation',
    'Order Finalized',
  ];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _applyReport,
    );

    _loadData();
  }

  // =========================================================
  // LOAD DATA
  // =========================================================

  Future<void> _loadData() async {
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

      _applyReport();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // BOOL HELPER
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
  // DATE
  // =========================================================

  DateTime? _parseDate(
    dynamic value,
  ) {
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

  DateTime _dateOnly(
    DateTime value,
  ) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  DateTime? _leadDate(
    Map<String, dynamic> lead,
  ) {
    return _parseDate(
      lead['lead_date'] ??
          lead['created_at'],
    );
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
    }

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
  // WHICH PIPELINE FIELD
  // =========================================================

  String _reportField() {
    switch (_selectedReport) {
      case 'Appointment Fixed':
        return 'appointment_fixed';

      case 'Site Visit':
        return 'site_visit_done';

      case 'Survey':
        return 'survey_done';

      case 'Quotation':
        return 'quotation_given';

      case 'Negotiation':
        return 'negotiation_done';

      case 'Order Finalized':
        return 'order_finalized';

      default:
        return 'appointment_fixed';
    }
  }

  // =========================================================
  // APPLY REPORT
  // =========================================================

  void _applyReport() {
    final field =
        _reportField();

    final search =
        _searchController.text
            .trim()
            .toLowerCase();

    final from =
        _dateOnly(_fromDate);

    final to =
        _dateOnly(_toDate);

    final result =
        _allLeads.where((lead) {
      // Pipeline stage must be completed.
      if (!_asBool(lead[field])) {
        return false;
      }

      // Date filter
      final rawDate =
          _leadDate(lead);

      if (rawDate == null) {
        return false;
      }

      final date =
          _dateOnly(rawDate);

      if (date.isBefore(from) ||
          date.isAfter(to)) {
        return false;
      }

      // Search
      final customer =
          lead['customer_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final mobile =
          lead['mobile']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final location =
          lead['location']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final marketingHead =
          lead['marketing_head']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final status =
          lead['lead_status']
                  ?.toString()
                  .toLowerCase() ??
              '';

      return search.isEmpty ||
          customer.contains(search) ||
          mobile.contains(search) ||
          location.contains(search) ||
          marketingHead.contains(search) ||
          status.contains(search);
    }).toList();

    result.sort((a, b) {
      final aDate =
          _leadDate(a);

      final bDate =
          _leadDate(b);

      if (aDate == null &&
          bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    if (!mounted) return;

    setState(() {
      _reportLeads = result;
    });
  }

  // =========================================================
  // DATE PICKERS
  // =========================================================

  Future<void> _pickFromDate() async {
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

    _applyReport();
  }

  Future<void> _pickToDate() async {
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

    _applyReport();
  }

  // =========================================================
  // SELECT REPORT
  // =========================================================

  void _selectReport(
    String report,
  ) {
    setState(() {
      _selectedReport = report;
    });

    _applyReport();
  }

  // =========================================================
  // OPEN LEAD
  // =========================================================

  Future<void> _openLead(
    Map<String, dynamic> lead,
  ) async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LeadUpdatePage(
          leadService:
              widget.leadService,
          lead: lead,
        ),
      ),
    );

    if (result != null) {
      await _loadData();
    }
  }

  // =========================================================
  // REPORT BUTTON
  // =========================================================

  Widget _reportButton(
    String title,
  ) {
    final selected =
        _selectedReport == title;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      showCheckmark: false,
      selectedColor:
          const Color(0xFF0B5C9E),
      backgroundColor:
          Colors.white,
      side: BorderSide(
        color: selected
            ? const Color(
                0xFF0B5C9E,
              )
            : const Color(
                0xFFDCE3EA,
              ),
      ),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : const Color(
                0xFF435160,
              ),
        fontWeight: selected
            ? FontWeight.w600
            : FontWeight.w500,
      ),
      onSelected: (_) {
        _selectReport(title);
      },
    );
  }

  // =========================================================
  // DATE BOX
  // =========================================================

  Widget _dateBox({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color:
                const Color(
              0xFFF6F8FA,
            ),
            borderRadius:
                BorderRadius.circular(9),
            border: Border.all(
              color:
                  const Color(
                0xFFDCE3EA,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .calendar_month_outlined,
                size: 19,
                color:
                    Color(
                  0xFF0B5C9E,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Color(
                          0xFF74808D,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      _formatDate(
                        date,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LEAD CARD
  // =========================================================

  Widget _leadCard(
    Map<String, dynamic> lead,
  ) {
    final id =
        lead['id']?.toString() ??
            '';

    final customer =
        lead['customer_name']
                ?.toString()
                .trim() ??
            '';

    final mobile =
        lead['mobile']
                ?.toString()
                .trim() ??
            '';

    final location =
        lead['location']
                ?.toString()
                .trim() ??
            '';

    final marketingHead =
        lead['marketing_head']
                ?.toString()
                .trim() ??
            '';

    final status =
        lead['lead_status']
                ?.toString()
                .trim() ??
            '';

    final date =
        _leadDate(lead);

    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(10),
        onTap: () {
          _openLead(lead);
        },
        child: Container(
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            border: Border.all(
              color:
                  const Color(
                0xFFE2E8EF,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEAF3FA,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(9),
                ),
                child: const Icon(
                  Icons
                      .analytics_outlined,
                  color:
                      Color(
                    0xFF0B5C9E,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.isEmpty
                                ? 'Unnamed Customer'
                                : customer,
                            style:
                                const TextStyle(
                              fontSize:
                                  15.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                        Text(
                          '#$id',
                          style:
                              const TextStyle(
                            fontSize: 11.5,
                            color:
                                Color(
                              0xFF7B8794,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    if (mobile.isNotEmpty)
                      _infoRow(
                        Icons
                            .phone_outlined,
                        mobile,
                      ),
                    if (location.isNotEmpty)
                      _infoRow(
                        Icons
                            .location_on_outlined,
                        location,
                      ),
                    if (marketingHead
                        .isNotEmpty)
                      _infoRow(
                        Icons
                            .badge_outlined,
                        marketingHead,
                      ),
                    const SizedBox(
                      height: 7,
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _chip(
                          _selectedReport,
                        ),
                        _chip(
                          _formatDate(
                            date,
                          ),
                        ),
                        if (status.isNotEmpty)
                          _chip(status),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Color(
                  0xFF8C98A4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 4,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color:
                const Color(
              0xFF74808D,
            ),
          ),
          const SizedBox(
            width: 6,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                fontSize: 12.5,
                color:
                    Color(
                  0xFF5E6975,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFFF1F5F8,
        ),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style:
            const TextStyle(
          fontSize: 11.5,
          color:
              Color(
            0xFF536170,
          ),
        ),
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
        title: const Text(
          'Marketing Reports',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _buildBody(),
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
                'Unable to load reports',
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
                    _loadData,
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

    return Column(
      children: [
        // ===================================================
        // TOP FILTER AREA
        // ===================================================

        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Column(
            children: [
              // Date filter
              Row(
                children: [
                  _dateBox(
                    title: 'From Date',
                    date: _fromDate,
                    onTap:
                        _pickFromDate,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _dateBox(
                    title: 'To Date',
                    date: _toDate,
                    onTap:
                        _pickToDate,
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              // Search
              TextField(
                controller:
                    _searchController,
                decoration:
                    InputDecoration(
                  hintText:
                      'Search customer, mobile, location...',
                  prefixIcon:
                      const Icon(
                    Icons.search_rounded,
                  ),
                  suffixIcon:
                      _searchController
                              .text
                              .isNotEmpty
                          ? IconButton(
                              onPressed:
                                  () {
                                _searchController
                                    .clear();
                              },
                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                            )
                          : null,
                  filled: true,
                  fillColor:
                      const Color(
                    0xFFF6F8FA,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(9),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // Report selection
              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0;
                        i <
                            _reports
                                .length;
                        i++) ...[
                      _reportButton(
                        _reports[i],
                      ),
                      if (i <
                          _reports.length -
                              1)
                        const SizedBox(
                          width: 7,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ===================================================
        // REPORT SUMMARY
        // ===================================================

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedReport,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(
                      0xFF536170,
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEAF3FA,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(20),
                ),
                child: Text(
                  '${_reportLeads.length}',
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
        ),

        // ===================================================
        // REPORT LIST
        // ===================================================

        Expanded(
          child:
              _reportLeads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          const Icon(
                            Icons
                                .analytics_outlined,
                            size: 55,
                            color:
                                Color(
                              0xFFABB5BF,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'No $_selectedReport records found',
                            style:
                                const TextStyle(
                              fontSize: 15,
                              color:
                                  Color(
                                0xFF697683,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            '${_formatDate(_fromDate)} to ${_formatDate(_toDate)}',
                            style:
                                const TextStyle(
                              fontSize: 12,
                              color:
                                  Color(
                                0xFF8A96A2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh:
                          _loadData,
                      child:
                          ListView
                              .separated(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          4,
                          16,
                          20,
                        ),
                        itemCount:
                            _reportLeads
                                .length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 8,
                        ),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          return _leadCard(
                            _reportLeads[
                                index],
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController
        .removeListener(
      _applyReport,
    );

    _searchController.dispose();

    super.dispose();
  }
}