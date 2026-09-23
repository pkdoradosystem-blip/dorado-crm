import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'add_user_page.dart';

class UserManagementPage extends StatefulWidget {
  final ApiClient apiClient;

  const UserManagementPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<UserManagementPage> createState() =>
      _UserManagementPageState();
}

class _UserManagementPageState
    extends State<UserManagementPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.apiClient.get(
        '/api/v1/admin/users',
      );

      List<dynamic> rawUsers = [];

      if (response is List) {
        rawUsers = response;
      } else if (response is Map) {
        if (response['users'] is List) {
          rawUsers = response['users'];
        } else if (response['data'] is List) {
          rawUsers = response['data'];
        }
      }

      final users = rawUsers
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  String _text(
    Map<String, dynamic> user,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = user[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  bool _isActive(Map<String, dynamic> user) {
    final value = user['active'] ??
        user['is_active'] ??
        user['Active'];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().toLowerCase();

    return text == null ||
        text.isEmpty ||
        text == 'true' ||
        text == 'yes' ||
        text == '1' ||
        text == 'active';
  }

  void _showUser(Map<String, dynamic> user) {
    final id = _text(
      user,
      ['id', 'user_id', 'employee_id'],
    );

    final name = _text(
      user,
      ['employee_name', 'name'],
    );

    final mobile = _text(
      user,
      ['mobile', 'phone'],
    );

    final designation = _text(
      user,
      ['designation'],
    );

    final role = _text(
      user,
      ['role', 'app_role', 'role_name'],
    );

    final department = _text(
      user,
      ['department', 'department_name'],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            name.isEmpty ? id : name,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Employee ID',
                value: id,
              ),
              _DetailRow(
                label: 'Mobile',
                value: mobile,
              ),
              _DetailRow(
                label: 'Designation',
                value: designation,
              ),
              _DetailRow(
                label: 'Role',
                value: role,
              ),
              _DetailRow(
                label: 'Department',
                value: department,
              ),
              _DetailRow(
                label: 'Status',
                value: _isActive(user)
                    ? 'Active'
                    : 'Inactive',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
  final created = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddUserPage(
        apiClient: widget.apiClient,
      ),
    ),
  );

  if (created == true) {
    await _loadUsers();
  }
},
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add User'),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Icon(
              Icons.people_outline,
              size: 60,
            ),
            SizedBox(height: 12),
            Center(
              child: Text('No users found'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          90,
        ),
        itemCount: _users.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = _users[index];

          final id = _text(
            user,
            ['id', 'user_id', 'employee_id'],
          );

          final name = _text(
            user,
            ['employee_name', 'name'],
          );

          final mobile = _text(
            user,
            ['mobile', 'phone'],
          );

          final role = _text(
            user,
            [
              'role',
              'app_role',
              'role_name',
              'designation',
            ],
          );

          final active = _isActive(user);

          final initial = name.isNotEmpty
              ? name.substring(0, 1).toUpperCase()
              : '?';

          return Card(
            elevation: 0,
            child: ListTile(
              onTap: () => _showUser(user),
              leading: CircleAvatar(
                child: Text(initial),
              ),
              title: Text(
                name.isEmpty
                    ? 'Unnamed User'
                    : name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    [
                      id,
                      role,
                    ]
                        .where(
                          (value) =>
                              value.isNotEmpty,
                        )
                        .join(' • '),
                  ),
                  if (mobile.isNotEmpty)
                    Text(mobile),
                ],
              ),
              trailing: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    active
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: active
                        ? Colors.green
                        : Colors.red,
                  ),
                  Text(
                    active
                        ? 'Active'
                        : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
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
}