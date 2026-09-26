import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import 'permission_management_page.dart';
import 'user_management_page.dart';

class SettingsPage extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.authService,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _user;

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
    });
  }

  bool get _isAdmin {
    final role =
        (_user?['role'] ?? _user?['app_role'] ?? '')
            .toString()
            .toLowerCase();

    return role == 'admin';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Do you want to logout from Dorado CRM?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await widget.authService.logout();

    if (!mounted) return;

    widget.onLogout();

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name foundation ready. Next we will connect its database/API.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (_user?['employee_name'] ?? 'Dorado User')
            .toString();

    final id = (_user?['id'] ?? '').toString();

    final role =
        (_user?['role'] ?? _user?['app_role'] ?? '')
            .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [id, role]
                              .where(
                                (e) => e.isNotEmpty,
                              )
                              .join(' • '),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (_isAdmin) ...[
            const Text(
              'Administration',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            _SettingTile(
  icon: Icons.manage_accounts_outlined,
  title: 'User Management',
  subtitle: 'Add, edit, activate or deactivate users',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserManagementPage(
          apiClient: widget.authService.apiClient,
        ),
      ),
    );
  },
),

           _SettingTile(
  icon: Icons.security_outlined,
  title: 'User Permissions',
  subtitle: 'Control View, Add, Edit and Delete',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PermissionManagementPage(),
      ),
    );
  },
),

            _SettingTile(
              icon: Icons.badge_outlined,
              title: 'Roles & Departments',
              subtitle:
                  'Department, role and reporting structure',
              onTap: () =>
                  _comingSoon('Roles & Departments'),
            ),

            _SettingTile(
              icon: Icons.dataset_outlined,
              title: 'Data Master',
              subtitle:
                  'Single & bulk master data entry',
              onTap: () =>
                  _comingSoon('Data Master'),
            ),

            const SizedBox(height: 20),
          ],

          const Text(
            'Account',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          _SettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Change your login password',
            onTap: () =>
                _comingSoon('Change Password'),
          ),

          _SettingTile(
            icon: Icons.info_outline,
            title: 'App Information',
            subtitle: 'Dorado CRM v1.0.0',
            onTap: () =>
                _comingSoon('App Information'),
          ),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize:
                  const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF0B5C9E),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing:
            const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}