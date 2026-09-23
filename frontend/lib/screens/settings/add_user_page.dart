import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class AddUserPage extends StatefulWidget {
  final ApiClient apiClient;

  const AddUserPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

  bool _active = true;
  bool _forcePasswordReset = true;

  String? _departmentId;
  String? _roleId;
  String? _reportingManagerId;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _toMapList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);

      for (final key in [
        'items',
        'data',
        'results',
        'departments',
        'roles',
        'users',
      ]) {
        final value = map[key];

        if (value is List) {
          return value
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      }
    }

    return [];
  }

  String _idOf(Map<String, dynamic> item) {
    return (item['id'] ??
            item['department_id'] ??
            item['role_id'] ??
            item['user_id'] ??
            '')
        .toString();
  }

  String _departmentName(Map<String, dynamic> item) {
    return (item['name'] ??
            item['department_name'] ??
            item['title'] ??
            _idOf(item))
        .toString();
  }

  String _roleName(Map<String, dynamic> item) {
    return (item['name'] ??
            item['role_name'] ??
            item['title'] ??
            _idOf(item))
        .toString();
  }

  String _userName(Map<String, dynamic> item) {
    return (item['employee_name'] ??
            item['name'] ??
            _idOf(item))
        .toString();
  }

  Future<void> _loadOptions() async {
  if (mounted) {
    setState(() {
      _loading = true;
    });
  }

  // --------------------------------------------------
  // 1. LOAD DEPARTMENT, ROLE AND USERS
  // --------------------------------------------------
  try {
    final results = await Future.wait([
      widget.apiClient.get(
        '/api/v1/admin/departments',
      ),
      widget.apiClient.get(
        '/api/v1/admin/roles',
      ),
      widget.apiClient.get(
        '/api/v1/admin/users',
      ),
    ]);

    if (!mounted) return;

    setState(() {
      _departments = _toMapList(results[0]);
      _roles = _toMapList(results[1]);
      _users = _toMapList(results[2]);

      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not load form options: $e',
        ),
      ),
    );

    return;
  }

  // --------------------------------------------------
  // 2. LOAD NEXT EMPLOYEE ID SEPARATELY
  // --------------------------------------------------
  try {
    final response = await widget.apiClient.get(
      '/api/v1/admin/next-user-id',
    );

    debugPrint(
      'NEXT USER ID RESPONSE: $response',
    );

    if (!mounted) return;

    if (response is Map) {
      final nextId =
          response['next_id']?.toString().trim() ?? '';

      if (nextId.isNotEmpty) {
        setState(() {
          _employeeIdController.text = nextId;
        });
      }
    }
  } catch (e) {
    // Next ID failure must NOT disable the form.
    debugPrint(
      'NEXT USER ID LOAD ERROR: $e',
    );
  }
}

  Future<void> _saveUser() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = <String, dynamic>{
        'id': _employeeIdController.text.trim(),
        'employee_name':
            _employeeNameController.text.trim(),
        'password': _passwordController.text,
        'mobile': _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'designation':
            _designationController.text.trim().isEmpty
                ? null
                : _designationController.text.trim(),
        'department_id': _departmentId,
        'role_id': _roleId,
        'reporting_manager_id':
            _reportingManagerId,
        'active': _active,
        'force_password_reset':
            _forcePasswordReset,
      };

      await widget.apiClient.post(
        '/api/v1/admin/users',
        payload,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User created successfully',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User could not be created: $e',
          ),
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

  InputDecoration _decoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Employee Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _employeeIdController,
                    readOnly: true,
                    textCapitalization:
                        TextCapitalization.characters,
                    decoration: _decoration(
                      label: 'Employee ID *',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Employee ID is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller:
                        _employeeNameController,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: _decoration(
                      label: 'Employee Name *',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Employee name is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration(
                      label: 'Mobile',
                      icon: Icons.phone_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: _decoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller:
                        _designationController,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: _decoration(
                      label: 'Designation',
                      icon: Icons.work_outline,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Organisation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _departmentId,
                    decoration: _decoration(
                      label: 'Department',
                      icon:
                          Icons.business_outlined,
                    ),
                    items: _departments
                        .where(
                          (item) =>
                              _idOf(item).isNotEmpty,
                        )
                        .map(
                          (item) =>
                              DropdownMenuItem<String>(
                            value: _idOf(item),
                            child: Text(
                              _departmentName(item),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _departmentId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _roleId,
                    decoration: _decoration(
                      label: 'Role',
                      icon:
                          Icons.admin_panel_settings_outlined,
                    ),
                    items: _roles
                        .where(
                          (item) =>
                              _idOf(item).isNotEmpty,
                        )
                        .map(
                          (item) =>
                              DropdownMenuItem<String>(
                            value: _idOf(item),
                            child: Text(
                              _roleName(item),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _roleId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue:
                        _reportingManagerId,
                    decoration: _decoration(
                      label: 'Reporting Manager',
                      icon:
                          Icons.supervisor_account_outlined,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'No Reporting Manager',
                        ),
                      ),
                      ..._users
                          .where(
                            (item) =>
                                _idOf(item).isNotEmpty,
                          )
                          .map(
                            (item) =>
                                DropdownMenuItem<String>(
                              value: _idOf(item),
                              child: Text(
                                _userName(item),
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _reportingManagerId =
                            value == null ||
                                    value.isEmpty
                                ? null
                                : value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Login & Security',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText:
                          'Temporary Password *',
                      prefixIcon:
                          const Icon(Icons.lock_outline),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Password is required';
                      }

                      if (value.length < 4) {
                        return 'Password is too short';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Active User',
                    ),
                    subtitle: const Text(
                      'User can login to Dorado CRM',
                    ),
                    value: _active,
                    onChanged: (value) {
                      setState(() {
                        _active = value;
                      });
                    },
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Force Password Reset',
                    ),
                    subtitle: const Text(
                      'User must change password after login',
                    ),
                    value: _forcePasswordReset,
                    onChanged: (value) {
                      setState(() {
                        _forcePasswordReset =
                            value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed:
                        _saving ? null : _saveUser,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_alt_1,
                          ),
                    label: Text(
                      _saving
                          ? 'Creating User...'
                          : 'Create User',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(52),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}