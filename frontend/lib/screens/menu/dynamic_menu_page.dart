import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../models/menu_item_model.dart';
import '../../services/services.dart';

import '../forms/dynamic_form_page.dart';

import '../leads/all_leads_page.dart';
import '../leads/follow_up_page.dart';

import '../sales/targets_page.dart';
import '../sales/marketing_reports_page.dart';


class DynamicMenuPage extends StatefulWidget {
  final String title;
  final List<MenuItemModel>? menuItems;
  final MenuService menuService;
  final FormService formService;

  const DynamicMenuPage({
    super.key,
    required this.title,
    required this.menuService,
    required this.formService,
    this.menuItems,
  });

  @override
  State<DynamicMenuPage> createState() =>
      _DynamicMenuPageState();
}

class _DynamicMenuPageState
    extends State<DynamicMenuPage> {
  bool _loading = true;
  String? _error;

  List<MenuItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  // =========================================================
  // LOAD MENU
  // =========================================================

  Future<void> _loadMenu() async {
    // Submenu already received from parent.
    if (widget.menuItems != null) {
      if (!mounted) return;

      setState(() {
        _items = widget.menuItems!;
        _loading = false;
        _error = null;
      });

      return;
    }

    // Root menu from backend.
    try {
      final items =
          await widget.menuService.loadMenus();

      if (!mounted) return;

      setState(() {
        _items = items;
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

  // =========================================================
  // OPEN MENU ITEM
  // =========================================================

  void _openItem(
    BuildContext context,
    MenuItemModel item,
  ) {
    final itemId =
        item.id.trim().toLowerCase();

    final itemTitle =
        item.title.trim().toLowerCase();

    // =======================================================
    // SALES & MARKETING
    // LEAD ENTRY
    // =======================================================

    if (item.routeType == 'form' &&
        item.formCode != null &&
        item.formCode!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DynamicFormPage(
            formCode:
                item.formCode!,
            title: item.title,
          ),
        ),
      );

      return;
    }

    // =======================================================
    // ALL LEADS
    // =======================================================

    if (itemId == 'all_leads' ||
        itemId == 'all-leads' ||
        itemTitle == 'all leads') {
      _openAllLeads();

      return;
    }

    // =======================================================
    // LEAD UPDATE
    //
    // Open lead list first.
    // Select lead -> Lead Update screen.
    // =======================================================

    if (itemId == 'lead_update' ||
        itemId == 'lead-update' ||
        itemTitle == 'lead update') {
      _openAllLeads();

      return;
    }

    // =======================================================
    // FOLLOW-UP
    // =======================================================

    if (itemId == 'follow_up' ||
        itemId == 'follow-up' ||
        itemTitle == 'follow-up' ||
        itemTitle == 'follow up') {
      _openFollowUp();

      return;
    }

    // =======================================================
    // TARGETS
    // =======================================================

    if (itemId == 'targets' ||
        itemId == 'target' ||
        itemTitle == 'targets' ||
        itemTitle == 'target') {
      _openTargets();

      return;
    }

    // =======================================================
    // MARKETING REPORTS
    // =======================================================

    if (itemId ==
            'marketing_reports' ||
        itemId ==
            'marketing-reports' ||
        itemTitle ==
            'marketing reports') {
      _openMarketingReports();

      return;
    }
    
    // =======================================================
    // GENERIC SUBMENU
    //
    // Main modules:
    // Sales & Marketing
    // New Installation
    // Repair & Modification
    // AMC & Service
    // Production
    // Accounts & Official
    // Back Office
    // Performance
    // Reports
    // =======================================================

    if (item.routeType ==
        'submenu') {
      if (item.children.isEmpty) {
        _showComingSoon(
          item.title,
        );

        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DynamicMenuPage(
            title: item.title,
            menuItems:
                item.children,
            menuService:
                widget.menuService,
            formService:
                widget.formService,
          ),
        ),
      );

      return;
    }

    // =======================================================
    // UNKNOWN / FUTURE PAGE
    // =======================================================

    _showComingSoon(
      item.title,
    );
  }

  // =========================================================
  // ALL LEADS
  // =========================================================

  void _openAllLeads() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AllLeadsPage(
          leadService:
              LeadService(
            ApiClient(),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FOLLOW-UP
  // =========================================================

  void _openFollowUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FollowUpPage(
          leadService:
              LeadService(
            ApiClient(),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TARGETS
  // =========================================================

  void _openTargets() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TargetsPage(
        leadService: LeadService(
          ApiClient(),
        ),
      ),
    ),
  );
}

  // =========================================================
  // MARKETING REPORTS
  // =========================================================

  void _openMarketingReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MarketingReportsPage(
          leadService:
              LeadService(
            ApiClient(),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // COMING SOON
  // =========================================================

  void _showComingSoon(
    String title,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$title screen will be connected later.',
        ),
      ),
    );
  }

  // =========================================================
  // ICONS
  // =========================================================

  IconData _getIcon(
    String icon,
  ) {
    switch (
        icon.trim().toLowerCase()) {
      // Sales
      case 'sales':
        return Icons
            .trending_up_rounded;

      // Lead Entry
      case 'add':
        return Icons
            .add_circle_outline_rounded;

      // All Leads
      case 'list':
        return Icons
            .format_list_bulleted_rounded;

      // Lead Update
      case 'edit':
        return Icons
            .edit_note_rounded;

      // Follow-up
      case 'followup':
        return Icons
            .event_repeat_rounded;

      // Target
      case 'target':
        return Icons
            .track_changes_rounded;

      // Report
      case 'report':
        return Icons
            .analytics_outlined;

      // Installation
      case 'installation':
        return Icons
            .apartment_rounded;

      // Repair
      case 'repair':
        return Icons
            .build_outlined;

      // AMC Service
      case 'service':
        return Icons
            .miscellaneous_services_rounded;

      // Production
      case 'production':
        return Icons
            .precision_manufacturing_outlined;

      // Accounts
      case 'accounts':
        return Icons
            .account_balance_wallet_outlined;

      // Office
      case 'office':
        return Icons
            .business_center_outlined;

      // Performance
      case 'performance':
        return Icons
            .speed_rounded;

      // Dashboard
      case 'dashboard':
        return Icons
            .dashboard_outlined;

      // Customer
      case 'customer':
        return Icons
            .people_outline_rounded;

      // Planning
      case 'planning':
        return Icons
            .calendar_month_outlined;

      // Breakdown
      case 'breakdown':
        return Icons
            .engineering_outlined;

      // Feedback
      case 'feedback':
        return Icons
            .rate_review_outlined;

      // Store
      case 'store':
        return Icons
            .inventory_2_outlined;

      // Payment
      case 'payment':
        return Icons
            .payments_outlined;

      default:
        return Icons
            .folder_outlined;
    }
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

        elevation: 0,

        title: Text(
          widget.title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),

      body: _buildBody(),
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  Widget _buildBody() {
    // -------------------------------------------------------
    // LOADING
    // -------------------------------------------------------

    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    // -------------------------------------------------------
    // ERROR
    // -------------------------------------------------------

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
                'Unable to load menu',
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
                height: 20,
              ),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });

                  _loadMenu();
                },

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

    // -------------------------------------------------------
    // EMPTY
    // -------------------------------------------------------

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No menu items available',
        ),
      );
    }

    // -------------------------------------------------------
    // PROFESSIONAL COMPACT MENU
    // -------------------------------------------------------

    return RefreshIndicator(
      onRefresh: _loadMenu,

      child:
          ListView.separated(
        padding:
            const EdgeInsets.all(
          16,
        ),

        itemCount:
            _items.length,

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
          final item =
              _items[index];

          return Material(
            color:
                Colors.white,

            borderRadius:
                BorderRadius
                    .circular(
              10,
            ),

            child: InkWell(
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),

              onTap: () {
                _openItem(
                  context,
                  item,
                );
              },

              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),

                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFFE6EBF1,
                    ),
                  ),
                ),

                child: Row(
                  children: [
                    // =======================================
                    // ICON BOX
                    // =======================================

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
                                .circular(
                          9,
                        ),
                      ),

                      child: Icon(
                        _getIcon(
                          item.icon,
                        ),

                        color:
                            const Color(
                          0xFF0B5C9E,
                        ),

                        size: 22,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    // =======================================
                    // TEXT
                    // =======================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Text(
                            item.title,

                            style:
                                const TextStyle(
                              fontSize:
                                  15.5,

                              fontWeight:
                                  FontWeight
                                      .w600,

                              color:
                                  Color(
                                0xFF17212B,
                              ),
                            ),
                          ),

                          if (item
                              .subtitle
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              item.subtitle,

                              style:
                                  const TextStyle(
                                fontSize:
                                    12.5,

                                color:
                                    Color(
                                  0xFF6B7785,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // =======================================
                    // ARROW
                    // =======================================

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
        },
      ),
    );
  }
}