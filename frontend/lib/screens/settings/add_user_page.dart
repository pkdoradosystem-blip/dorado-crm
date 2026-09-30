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

  // =====================================================
  // CONTROLLERS
  // =====================================================

  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _designationController = TextEditingController();

  final _dateOfJoiningController = TextEditingController();

  final _passwordController = TextEditingController();
  final _petNameController = TextEditingController();

  // =====================================================
  // STATE
  // =====================================================

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

  bool _active = true;
  bool _forcePasswordReset = true;

  String? _gender;
  String? _departmentId;
  String? _roleId;
  String? _reportingManagerId;
  String? _employeeType;

  // =====================================================
  // MASTER DATA
  // =====================================================

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _employeeTypes = [];

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    _dateOfBirthController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _designationController.dispose();
    _dateOfJoiningController.dispose();
    _passwordController.dispose();
    _petNameController.dispose();

    super.dispose();
  }

  // =====================================================
  // HELPERS
  // =====================================================

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
    return (item['name'] ?? item['role_name'] ?? item['title'] ?? _idOf(item))
        .toString();
  }

  String _userName(Map<String, dynamic> item) {
    return (item['employee_name'] ?? item['name'] ?? _idOf(item)).toString();
  }

  String _userRoleName(Map<String, dynamic> user) {
    final directRole = (user['role_name'] ?? user['role'] ?? user['role_title'])
        ?.toString()
        .trim();

    if (directRole != null && directRole.isNotEmpty) {
      return directRole;
    }

    final userRoleId = (user['role_id'] ?? '').toString().trim();

    if (userRoleId.isEmpty) {
      return '';
    }

    for (final role in _roles) {
      if (_idOf(role) == userRoleId) {
        return _roleName(role);
      }
    }

    return '';
  }

  String _reportingManagerLabel(
    Map<String, dynamic> user,
  ) {
    final name = _userName(user);
    final role = _userRoleName(user);

    if (role.isEmpty) {
      return name;
    }

    return '$name • $role';
  }

  String _masterName(Map<String, dynamic> item) {
    return (item['name'] ?? item['master_name'] ?? item['title'] ?? '')
        .toString()
        .trim();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // LOAD MASTER DATA
  // =====================================================

  Future<void> _loadOptions() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

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
        widget.apiClient.get(
          '/api/v1/master-data/DESIGNATION?active_only=true',
        ),
        widget.apiClient.get(
          '/api/v1/master-data/EMPLOYEE_TYPE?active_only=true',
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _departments = _toMapList(results[0]);
        _roles = _toMapList(results[1]);
        _users = _toMapList(results[2]);
        _designations = _toMapList(results[3]);
        _employeeTypes = _toMapList(results[4]);

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

    // ===================================================
    // NEXT EMPLOYEE ID
    // ===================================================

    try {
      final response = await widget.apiClient.get(
        '/api/v1/admin/next-user-id',
      );

      debugPrint(
        'NEXT USER ID RESPONSE: $response',
      );

      if (!mounted) return;

      if (response is Map) {
        final nextId = response['next_id']?.toString().trim() ?? '';

        if (nextId.isNotEmpty) {
          setState(() {
            _employeeIdController.text = nextId;
          });
        }
      }
    } catch (e) {
      // Next ID failure must not disable the form.
      debugPrint(
        'NEXT USER ID LOAD ERROR: $e',
      );
    }
  }

  // =====================================================
  // DATE PICKERS
  // =====================================================

  Future<void> _selectDateOfBirth() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 25),
      firstDate: DateTime(1940),
      lastDate: today,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfBirthController.text = _formatDate(selected);
    });
  }

  Future<void> _selectDateOfJoining() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1990),
      lastDate: DateTime(today.year + 1),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfJoiningController.text = _formatDate(selected);
    });
  }

  // =====================================================
  // SAVE USER
  // =====================================================

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
        // Employee Information
        'id': _employeeIdController.text.trim(),
        'employee_name': _employeeNameController.text.trim(),
        'date_of_birth': _dateOfBirthController.text.trim(),
        'gender': _gender,

        'mobile': _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),

        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),

        'designation': _designationController.text.trim().isEmpty
            ? null
            : _designationController.text.trim(),

        // Organisation
        'department_id': _departmentId,
        'role_id': _roleId,
        'reporting_manager_id': _reportingManagerId,

        'date_of_joining': _dateOfJoiningController.text.trim(),

        'employee_type': _employeeType,

        // Login & Security
        'password': _passwordController.text,
        'pet_name': _petNameController.text.trim(),

        'force_password_reset': _forcePasswordReset,

        'active': _active,
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

  // =====================================================
  // UI HELPERS
  // =====================================================

  InputDecoration _decoration({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  // =======================================
                  // EMPLOYEE INFORMATION
                  // =======================================

                  _sectionTitle(
                    'Employee Information',
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _employeeIdController,
                    readOnly: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoration(
                      label: 'Employee ID *',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Employee ID is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _employeeNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      label: 'Employee Name *',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Employee name is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _dateOfBirthController,
                    readOnly: true,
                    decoration: _decoration(
                      label: 'Date of Birth *',
                      icon: Icons.calendar_month_outlined,
                    ),
                    onTap: _selectDateOfBirth,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Date of Birth is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: _decoration(
                      label: 'Gender *',
                      icon: Icons.wc_outlined,
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'Male',
                        child: Text('Male'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Female',
                        child: Text('Female'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gender = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Gender is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration(
                      label: 'Mobile',
                      icon: Icons.phone_outlined,
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _designationController.text.trim().isEmpty
                        ? null
                        : _designationController.text.trim(),
                    decoration: _decoration(
                      label: 'Designation',
                      icon: Icons.work_outline,
                    ),
                    isExpanded: true,
                    items: {
                      for (final item in _designations)
                        if (_masterName(item).isNotEmpty)
                          _masterName(item).toLowerCase(): item,
                    }.values.map(
                      (item) {
                        final name = _masterName(item);

                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _designationController.text = value ?? '';
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // =======================================
                  // ORGANISATION
                  // =======================================

                  _sectionTitle('Organisation'),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _departmentId,
                    decoration: _decoration(
                      label: 'Department',
                      icon: Icons.business_outlined,
                    ),
                    isExpanded: true,
                    items: {
                      for (final item in _departments)
                        if (_idOf(item).isNotEmpty)
                          _departmentName(item).trim().toLowerCase(): item,
                    }.values.map(
                      (item) {
                        return DropdownMenuItem<String>(
                          value: _idOf(item),
                          child: Text(
                            _departmentName(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _departmentId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _roleId,
                    decoration: _decoration(
                      label: 'Role',
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    isExpanded: true,
                    items: {
                      for (final item in _roles)
                        if (_idOf(item).isNotEmpty)
                          _roleName(item).trim().toLowerCase(): item,
                    }.values.map(
                      (item) {
                        return DropdownMenuItem<String>(
                          value: _idOf(item),
                          child: Text(
                            _roleName(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _roleId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _reportingManagerId,
                    decoration: _decoration(
                      label: 'Reporting Manager',
                      icon: Icons.supervisor_account_outlined,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'No Reporting Manager',
                        ),
                      ),
                      ..._users
                          .where(
                            (item) => _idOf(item).isNotEmpty,
                          )
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: _idOf(item),
                              child: Text(
                                _reportingManagerLabel(
                                  item,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _reportingManagerId =
                            value == null || value.isEmpty ? null : value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _dateOfJoiningController,
                    readOnly: true,
                    decoration: _decoration(
                      label: 'Date of Joining *',
                      icon: Icons.event_available_outlined,
                    ),
                    onTap: _selectDateOfJoining,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Date of Joining is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: _employeeType,
                    decoration: _decoration(
                      label: 'Employee Type *',
                      icon: Icons.assignment_ind_outlined,
                    ),
                    isExpanded: true,
                    items: {
                      for (final item in _employeeTypes)
                        if (_masterName(item).isNotEmpty)
                          _masterName(item).toLowerCase(): item,
                    }.values.map(
                      (item) {
                        final name = _masterName(item);

                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      setState(() {
                        _employeeType = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Employee Type is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // =======================================
                  // LOGIN & SECURITY
                  // =======================================

                  _sectionTitle('Login & Security'),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Temporary Password *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }

                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _petNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      label: 'Pet Name / Security Answer *',
                      icon: Icons.security_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pet Name / Security Answer is required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Force Password Reset',
                    ),
                    subtitle: const Text(
                      'User must change password after first login',
                    ),
                    value: _forcePasswordReset,
                    onChanged: (value) {
                      setState(() {
                        _forcePasswordReset = value;
                      });
                    },
                  ),

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

                  const SizedBox(height: 12),

                  // =======================================
                  // CREATE USER
                  // =======================================

                  FilledButton.icon(
                    onPressed: _saving ? null : _saveUser,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_alt_1,
                          ),
                    label: Text(
                      _saving ? 'Creating User...' : 'Create User',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
