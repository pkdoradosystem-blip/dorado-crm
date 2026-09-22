import 'package:flutter/material.dart';

import '../../services/services.dart';
import 'lead_update_page.dart';

class FollowUpPage extends StatefulWidget {
  final LeadService leadService;

  const FollowUpPage({
    super.key,
    required this.leadService,
  });

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _filteredLeads = [];

  bool _loading = true;
  String? _error;

  String _filter = 'Today';
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilter);
    _loadData();
  }

  // =========================================================
  // LOAD
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
          await widget.leadService.loadFollowUps();

      if (!mounted) return;

      setState(() {
        _allLeads = leads;
        _loading = false;
      });

      _applyFilter();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // =========================================================
  // DATE HELPERS
  // =========================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    final day =
        value.day.toString().padLeft(2, '0');

    final month =
        value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }

  // =========================================================
  // FILTER
  // =========================================================

  void _applyFilter() {
    final search =
        _searchController.text.trim().toLowerCase();

    final today = _dateOnly(
      DateTime.now(),
    );

    final firstDayOfMonth = DateTime(
      today.year,
      today.month,
      1,
    );

    final nextMonth = today.month == 12
        ? DateTime(
            today.year + 1,
            1,
            1,
          )
        : DateTime(
            today.year,
            today.month + 1,
            1,
          );

    final lastDayOfMonth = nextMonth.subtract(
      const Duration(days: 1),
    );

    final result = _allLeads.where((lead) {
      final followUpDate =
          _parseDate(
        lead['follow_up_date'],
      );

      if (followUpDate == null) {
        return false;
      }

      final date =
          _dateOnly(followUpDate);

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

      final matchesSearch =
          search.isEmpty ||
          customer.contains(search) ||
          mobile.contains(search) ||
          location.contains(search) ||
          marketingHead.contains(search) ||
          status.contains(search);

      if (!matchesSearch) {
        return false;
      }

      // TODAY
      if (_filter == 'Today') {
        return date == today;
      }

      // MISSED
      if (_filter == 'Missed') {
        return date.isBefore(today);
      }

      // THIS MONTH
      if (_filter == 'This Month') {
        return !date.isBefore(firstDayOfMonth) &&
            !date.isAfter(lastDayOfMonth);
      }

      // CUSTOM
      if (_filter == 'Custom' &&
          _customRange != null) {
        final start =
            _dateOnly(_customRange!.start);

        final end =
            _dateOnly(_customRange!.end);

        return !date.isBefore(start) &&
            !date.isAfter(end);
      }

      return true;
    }).toList();

    result.sort((a, b) {
      final dateA =
          _parseDate(a['follow_up_date']);

      final dateB =
          _parseDate(b['follow_up_date']);

      if (dateA == null ||
          dateB == null) {
        return 0;
      }

      return dateA.compareTo(dateB);
    });

    if (!mounted) return;

    setState(() {
      _filteredLeads = result;
    });
  }

  // =========================================================
  // SELECT FILTER
  // =========================================================

  Future<void> _selectFilter(
    String value,
  ) async {
    if (value == 'Custom') {
      final now = DateTime.now();

      final result =
          await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(
          now.year + 5,
        ),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: now,
              end: now,
            ),
      );

      if (result == null) {
        return;
      }

      setState(() {
        _filter = 'Custom';
        _customRange = result;
      });

      _applyFilter();
      return;
    }

    setState(() {
      _filter = value;
      _customRange = null;
    });

    _applyFilter();
  }

  // =========================================================
  // OPEN UPDATE
  // =========================================================

  Future<void> _openLead(
    Map<String, dynamic> lead,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadUpdatePage(
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
  // FILTER BUTTON
  // =========================================================

  Widget _filterButton(
    String title,
  ) {
    final selected =
        _filter == title;

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
        _selectFilter(title);
      },
    );
  }

  // =========================================================
  // LEAD CARD
  // =========================================================

  Widget _leadCard(
    Map<String, dynamic> lead,
  ) {
    final customer =
        lead['customer_name']
            ?.toString() ??
        'Unnamed Customer';

    final mobile =
        lead['mobile']
            ?.toString() ??
        '';

    final location =
        lead['location']
            ?.toString() ??
        '';

    final status =
        lead['lead_status']
            ?.toString() ??
        '';

    final marketingHead =
        lead['marketing_head']
            ?.toString() ??
        '';

    final followUpDate =
        _parseDate(
      lead['follow_up_date'],
    );

    final today =
        _dateOnly(DateTime.now());

    final missed =
        followUpDate != null &&
        _dateOnly(followUpDate)
            .isBefore(today);

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
                BorderRadius.circular(10),
            border: Border.all(
              color:
                  const Color(
                0xFFE2E8EF,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: missed
                      ? const Color(
                          0xFFFFECEC,
                        )
                      : const Color(
                          0xFFEAF3FA,
                        ),
                  borderRadius:
                      BorderRadius
                          .circular(9),
                ),
                child: Icon(
                  missed
                      ? Icons
                          .warning_amber_rounded
                      : Icons
                          .event_repeat_rounded,
                  color: missed
                      ? Colors.redAccent
                      : const Color(
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
                    Text(
                      customer,
                      style:
                          const TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    if (mobile.isNotEmpty)
                      Text(
                        mobile,
                        style:
                            const TextStyle(
                          fontSize: 12.5,
                          color:
                              Color(
                            0xFF657381,
                          ),
                        ),
                      ),

                    if (location.isNotEmpty)
                      Text(
                        location,
                        style:
                            const TextStyle(
                          fontSize: 12.5,
                          color:
                              Color(
                            0xFF657381,
                          ),
                        ),
                      ),

                    const SizedBox(
                      height: 7,
                    ),

                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _chip(
                          'Follow-up: '
                          '${_formatDate(followUpDate)}',
                        ),

                        if (status.isNotEmpty)
                          _chip(status),

                        if (marketingHead
                            .isNotEmpty)
                          _chip(
                            marketingHead,
                          ),

                        if (missed)
                          _chip(
                            'MISSED',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color:
                    Color(0xFF8C98A4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF1F5F8),
        borderRadius:
            BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style:
            const TextStyle(
          fontSize: 11.5,
          color:
              Color(0xFF536170),
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
          const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0B5C9E),
        foregroundColor:
            Colors.white,
        title:
            const Text('Follow-up'),
        actions: [
          IconButton(
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
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Text(
              'Unable to load follow-ups',
            ),
            const SizedBox(
              height: 10,
            ),
            Text(_error!),
            const SizedBox(
              height: 15,
            ),
            ElevatedButton(
              onPressed: _loadData,
              child:
                  const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.all(14),
          child: Column(
            children: [
              TextField(
                controller:
                    _searchController,
                decoration:
                    InputDecoration(
                  hintText:
                      'Search follow-up...',
                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),
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

              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: Row(
                  children: [
                    _filterButton(
                      'Today',
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    _filterButton(
                      'Missed',
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    _filterButton(
                      'This Month',
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    _filterButton(
                      'Custom',
                    ),
                  ],
                ),
              ),

              if (_filter ==
                      'Custom' &&
                  _customRange !=
                      null) ...[
                const SizedBox(
                  height: 8,
                ),
                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    '${_formatDate(_customRange!.start)}'
                    ' to '
                    '${_formatDate(_customRange!.end)}',
                  ),
                ),
              ],
            ],
          ),
        ),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
            vertical: 9,
          ),
          child: Text(
            '${_filteredLeads.length} follow-up'
            '${_filteredLeads.length == 1 ? '' : 's'} found',
            style:
                const TextStyle(
              fontSize: 12.5,
              color:
                  Color(0xFF657381),
            ),
          ),
        ),

        Expanded(
          child:
              _filteredLeads.isEmpty
                  ? const Center(
                      child: Text(
                        'No follow-ups found',
                        style:
                            TextStyle(
                          fontSize: 16,
                          color:
                              Color(
                            0xFF697683,
                          ),
                        ),
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
                            _filteredLeads
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
                            _filteredLeads[
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
      _applyFilter,
    );
    _searchController.dispose();
    super.dispose();
  }
}