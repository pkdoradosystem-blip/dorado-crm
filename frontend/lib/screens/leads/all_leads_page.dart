import 'package:flutter/material.dart';

import '../../services/services.dart';
import 'lead_update_page.dart';

class AllLeadsPage extends StatefulWidget {
  final LeadService leadService;

  const AllLeadsPage({
    super.key,
    required this.leadService,
  });

  @override
  State<AllLeadsPage> createState() => _AllLeadsPageState();
}

class _AllLeadsPageState extends State<AllLeadsPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _filteredLeads = [];

  bool _loading = true;
  String? _error;

  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);

    _loadLeads();
  }

  // =========================================================
  // LOAD LEADS
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

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // LEAD DATE
  // =========================================================

  DateTime? _getLeadDate(
    Map<String, dynamic> lead,
  ) {
    final value =
        lead['lead_date'] ??
        lead['created_at'] ??
        lead['date'];

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  DateTime _dateOnly(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // =========================================================
  // SEARCH + DATE FILTER
  // =========================================================

  void _applyFilters() {
    final search =
        _searchController.text
            .trim()
            .toLowerCase();

    final now = DateTime.now();
    final today = _dateOnly(now);

    final filtered =
        _allLeads.where((lead) {
      final id =
          lead['id']
              ?.toString()
              .toLowerCase() ??
          '';

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

      final source =
          lead['lead_source']
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

      final matchesSearch =
          search.isEmpty ||
          id.contains(search) ||
          customer.contains(search) ||
          mobile.contains(search) ||
          location.contains(search) ||
          source.contains(search) ||
          marketingHead.contains(search) ||
          status.contains(search);

      if (!matchesSearch) {
        return false;
      }

      if (_selectedFilter == 'All') {
        return true;
      }

      final leadDate =
          _getLeadDate(lead);

      if (leadDate == null) {
        return false;
      }

      final date =
          _dateOnly(leadDate);

      if (_selectedFilter ==
          'Today') {
        return date == today;
      }

      if (_selectedFilter ==
          '7 Days') {
        final startDate =
            today.subtract(
          const Duration(days: 6),
        );

        return !date.isBefore(
              startDate,
            ) &&
            !date.isAfter(today);
      }

      if (_selectedFilter ==
              'Custom' &&
          _customDateRange !=
              null) {
        final start =
            _dateOnly(
          _customDateRange!.start,
        );

        final end =
            _dateOnly(
          _customDateRange!.end,
        );

        return !date.isBefore(
              start,
            ) &&
            !date.isAfter(end);
      }

      return true;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredLeads = filtered;
    });
  }

  // =========================================================
  // SELECT FILTER
  // =========================================================

  Future<void> _selectFilter(
    String filter,
  ) async {
    if (filter == 'Custom') {
      final now =
          DateTime.now();

      final result =
          await showDateRangePicker(
        context: context,
        firstDate:
            DateTime(2020),
        lastDate:
            DateTime(
          now.year + 5,
        ),
        initialDateRange:
            _customDateRange ??
            DateTimeRange(
              start: now,
              end: now,
            ),
      );

      if (result == null) {
        return;
      }

      setState(() {
        _selectedFilter =
            'Custom';

        _customDateRange =
            result;
      });

      _applyFilters();

      return;
    }

    setState(() {
      _selectedFilter =
          filter;

      _customDateRange =
          null;
    });

    _applyFilters();
  }

  // =========================================================
  // OPEN LEAD UPDATE
  // =========================================================

  Future<void> _openLeadUpdate(
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
      await _loadLeads();
    }
  }

  // =========================================================
  // DATE FORMAT
  // =========================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
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

  // =========================================================
  // SAFE TEXT
  // =========================================================

  String _text(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    return text;
  }

  // =========================================================
  // FILTER BUTTON
  // =========================================================

  Widget _filterButton(
    String title,
  ) {
    final selected =
        _selectedFilter ==
            title;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) {
        _selectFilter(
          title,
        );
      },
      selectedColor:
          const Color(
        0xFF0B5C9E,
      ),
      backgroundColor:
          Colors.white,
      labelStyle:
          TextStyle(
        fontSize: 12.5,
        color: selected
            ? Colors.white
            : const Color(
                0xFF435160,
              ),
        fontWeight:
            selected
                ? FontWeight.w600
                : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? const Color(
                0xFF0B5C9E,
              )
            : const Color(
                0xFFDCE3EA,
              ),
      ),
      showCheckmark:
          false,
      visualDensity:
          VisualDensity.compact,
    );
  }

  // =========================================================
  // TABLE HEADER TEXT
  // =========================================================

  Widget _headerText(
    String text,
  ) {
    return Text(
      text,
      style:
          const TextStyle(
        fontSize: 12.5,
        fontWeight:
            FontWeight.w700,
        color:
            Color(
          0xFF334155,
        ),
      ),
    );
  }

  // =========================================================
  // TABLE CELL TEXT
  // =========================================================

  Widget _cellText(
    String text, {
    double width = 120,
    FontWeight fontWeight =
        FontWeight.w400,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style:
            TextStyle(
          fontSize: 12.5,
          fontWeight:
              fontWeight,
          color:
              const Color(
            0xFF374151,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATUS
  // =========================================================

  Widget _statusCell(
    String status,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 90,
        maxWidth: 145,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFEAF3FA,
        ),
        borderRadius:
            BorderRadius.circular(
          6,
        ),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        textAlign:
            TextAlign.center,
        style:
            const TextStyle(
          fontSize: 11.5,
          fontWeight:
              FontWeight.w600,
          color:
              Color(
            0xFF0B5C9E,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TABLE
  // =========================================================

  Widget _buildTable() {
    return Scrollbar(
      thumbVisibility: true,
      child:
          SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child: Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            12,
            0,
            12,
            20,
          ),
          child: Container(
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              border:
                  Border.all(
                color:
                    const Color(
                  0xFFDDE4EB,
                ),
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                8,
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius
                      .circular(
                8,
              ),
              child: DataTable(
                headingRowHeight:
                    44,
                dataRowMinHeight:
                    44,
                dataRowMaxHeight:
                    48,
                horizontalMargin:
                    12,
                columnSpacing:
                    18,
                dividerThickness:
                    0.7,
                headingRowColor:
                    WidgetStateProperty
                        .all(
                  const Color(
                    0xFFF1F5F9,
                  ),
                ),
                columns: [
                  DataColumn(
                    label:
                        _headerText(
                      'ID',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Date',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Customer',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Mobile',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Location',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Marketing Head',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Status',
                    ),
                  ),
                  DataColumn(
                    label:
                        _headerText(
                      'Edit',
                    ),
                  ),
                ],
                rows:
                    _filteredLeads
                        .map(
                  (lead) {
                    final id =
                        _text(
                      lead['id'],
                    );

                    final date =
                        _formatDate(
                      _getLeadDate(
                        lead,
                      ),
                    );

                    final customer =
                        _text(
                      lead[
                          'customer_name'],
                    );

                    final mobile =
                        _text(
                      lead['mobile'],
                    );

                    final location =
                        _text(
                      lead['location'],
                    );

                    final marketingHead =
                        _text(
                      lead[
                          'marketing_head'],
                    );

                    final status =
                        _text(
                      lead[
                          'lead_status'],
                    );

                    return DataRow(
                      onSelectChanged:
                          (_) {
                        _openLeadUpdate(
                          lead,
                        );
                      },
                      cells: [
                        DataCell(
                          _cellText(
                            '#$id',
                            width: 55,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        DataCell(
                          _cellText(
                            date,
                            width: 85,
                          ),
                        ),
                        DataCell(
                          _cellText(
                            customer,
                            width: 150,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        DataCell(
                          _cellText(
                            mobile,
                            width: 105,
                          ),
                        ),
                        DataCell(
                          _cellText(
                            location,
                            width: 125,
                          ),
                        ),
                        DataCell(
                          _cellText(
                            marketingHead,
                            width: 135,
                          ),
                        ),
                        DataCell(
                          _statusCell(
                            status,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip:
                                'Update Lead',
                            visualDensity:
                                VisualDensity
                                    .compact,
                            icon:
                                const Icon(
                              Icons
                                  .edit_outlined,
                              size: 19,
                              color:
                                  Color(
                                0xFF0B5C9E,
                              ),
                            ),
                            onPressed:
                                () {
                              _openLeadUpdate(
                                lead,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
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
        title:
            const Text(
          'All Leads',
        ),
        actions: [
          IconButton(
            tooltip:
                'Refresh',
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

  // =========================================================
  // BODY
  // =========================================================

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

    return Column(
      children: [
        // ===================================================
        // SEARCH + FILTER
        // ===================================================

        Container(
          color:
              Colors.white,
          padding:
              const EdgeInsets.fromLTRB(
            14,
            10,
            14,
            8,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 42,
                child:
                    TextField(
                  controller:
                      _searchController,
                  style:
                      const TextStyle(
                    fontSize: 13,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        'Search customer, mobile, location, status...',
                    prefixIcon:
                        const Icon(
                      Icons.search_rounded,
                      size: 20,
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
                                  size: 19,
                                ),
                              )
                            : null,
                    filled:
                        true,
                    fillColor:
                        const Color(
                      0xFFF6F8FA,
                    ),
                    contentPadding:
                        EdgeInsets.zero,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: Row(
                  children: [
                    _filterButton(
                      'All',
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    _filterButton(
                      'Today',
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    _filterButton(
                      '7 Days',
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    _filterButton(
                      'Custom',
                    ),
                  ],
                ),
              ),

              if (_selectedFilter ==
                      'Custom' &&
                  _customDateRange !=
                      null) ...[
                const SizedBox(
                  height: 6,
                ),
                Align(
                  alignment:
                      Alignment
                          .centerLeft,
                  child: Text(
                    '${_formatDate(_customDateRange!.start)}'
                    '  to  '
                    '${_formatDate(_customDateRange!.end)}',
                    style:
                        const TextStyle(
                      fontSize: 11.5,
                      color:
                          Color(
                        0xFF607080,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ===================================================
        // COUNT
        // ===================================================

        Container(
          width:
              double.infinity,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 14,
            vertical: 7,
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .format_list_numbered_rounded,
                size: 16,
                color:
                    Color(
                  0xFF0B5C9E,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                '${_filteredLeads.length} lead'
                '${_filteredLeads.length == 1 ? '' : 's'} found',
                style:
                    const TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Color(
                    0xFF657381,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ===================================================
        // TABLE
        // ===================================================

        Expanded(
          child:
              _filteredLeads
                      .isEmpty
                  ? const Center(
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          Icon(
                            Icons
                                .inbox_outlined,
                            size: 52,
                            color:
                                Color(
                              0xFFABB5BF,
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            'No leads found',
                            style:
                                TextStyle(
                              fontSize: 16,
                              color:
                                  Color(
                                0xFF697683,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh:
                          _loadLeads,
                      child:
                          ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildTable(),
                        ],
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
      _applyFilters,
    );

    _searchController
        .dispose();

    super.dispose();
  }
}