import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../services/services.dart';
import '../menu/dynamic_menu_page.dart';
import '../settings/settings_page.dart';

class DashboardPage extends StatefulWidget {
  final AuthService authService;
  final MenuService menuService;
  final FormService formService;
  final VoidCallback onLogout;

  const DashboardPage({
    super.key,
    required this.authService,
    required this.menuService,
    required this.formService,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await widget.authService.getSavedUser();

    if (!mounted) return;

    setState(() {
      _user = user;
      _loading = false;
    });
  }

  String _value(String key, {String fallback = ''}) {
    final value = _user?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final employeeName = _value(
      'employee_name',
      fallback: 'Dorado User',
    );

    final employeeId = _value('id');
    final role = _value(
      'role',
      fallback: _value('app_role'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dorado CRM',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    authService: widget.authService,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadUser,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0B5C9E),
                          Color(0xFF1479C9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Text(
                            employeeName.isNotEmpty
                                ? employeeName[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B5C9E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                employeeName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (employeeId.isNotEmpty)
                                    employeeId,
                                  if (role.isNotEmpty) role,
                                ].join(' • '),
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _DashboardCard(
                          icon: Icons.people_alt_outlined,
                          title: 'Leads',
                          value: '--',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardCard(
                          icon: Icons.task_alt,
                          title: 'Follow-up',
                          value: '--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _DashboardCard(
                          icon: Icons.handshake_outlined,
                          title: 'Orders',
                          value: '--',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardCard(
                          icon: Icons.build_circle_outlined,
                          title: 'AMC',
                          value: '--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Quick Access',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _ActionTile(
                    icon: Icons.apps,
                    title: 'Main Menu',
                    subtitle: 'Open all departments and modules',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DynamicMenuPage(
                            title: 'Dorado CRM',
                            menuService: widget.menuService,
                            formService: widget.formService,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  _ActionTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle:
                        'Users, permissions and data masters',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(
                            authService: widget.authService,
                            onLogout: widget.onLogout,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE1E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF0B5C9E),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0B5C9E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}