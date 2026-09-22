import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({super.key});

  @override
  State<PermissionManagementPage> createState() =>
      _PermissionManagementPageState();
}

class _PermissionManagementPageState
    extends State<PermissionManagementPage> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  bool _saving = false;

  List<dynamic> _users = [];
  List<dynamic> _modules = [];

  String? _selectedUserId;
  String? _selectedModuleId;

  bool _canView = false;
  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _loading = true;
      });

      final users = await _api.get('/api/v1/admin/users');
      final modules = await _api.get('/api/v1/admin/modules');

      if (!mounted) return;

      setState(() {
        _users = users is List ? users : [];
        _modules = modules is List ? modules : [];
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
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  void _resetPermissionSwitches() {
    setState(() {
      _canView = false;
      _canAdd = false;
      _canEdit = false;
      _canDelete = false;
    });
  }

  Future<void> _savePermission() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee'),
        ),
      );
      return;
    }

    if (_selectedModuleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a module'),
        ),
      );
      return;
    }

    try {
      setState(() {
        _saving = true;
      });

      await _api.put(
        '/api/v1/admin/permissions/users/'
        '$_selectedUserId/$_selectedModuleId',
        {
          'can_view': _canView,
          'can_add': _canAdd,
          'can_edit': _canEdit,
          'can_delete': _canDelete,
        },
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission saved successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Management'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 700,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'User Permission Control',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Select employee and module, then '
                            'set View, Add, Edit and Delete access.',
                          ),

                          const SizedBox(height: 24),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedUserId,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.person_outline,
                              ),
                            ),
                            items: _users.map((user) {
                              final id =
                                  user['id']?.toString() ?? '';

                              final name =
                                  user['employee_name']
                                          ?.toString() ??
                                      id;

                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  '$name ($id)',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUserId = value;
                              });

                              _resetPermissionSwitches();
                            },
                          ),

                          const SizedBox(height: 20),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedModuleId,
                            decoration: const InputDecoration(
                              labelText: 'Module',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.apps_outlined,
                              ),
                            ),
                            items: _modules.map((module) {
                              final id =
                                  module['id']?.toString() ?? '';

                              final name =
                                  module['module_name']
                                          ?.toString() ??
                                      id;

                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedModuleId = value;
                              });

                              _resetPermissionSwitches();
                            },
                          ),

                          const SizedBox(height: 28),

                          const Divider(),

                          SwitchListTile(
                            title: const Text('View'),
                            subtitle: const Text(
                              'User can view this module',
                            ),
                            secondary: const Icon(
                              Icons.visibility_outlined,
                            ),
                            value: _canView,
                            onChanged: (value) {
                              setState(() {
                                _canView = value;

                                if (!value) {
                                  _canAdd = false;
                                  _canEdit = false;
                                  _canDelete = false;
                                }
                              });
                            },
                          ),

                          SwitchListTile(
                            title: const Text('Add'),
                            subtitle: const Text(
                              'User can add new records',
                            ),
                            secondary: const Icon(
                              Icons.add_circle_outline,
                            ),
                            value: _canAdd,
                            onChanged: (value) {
                              setState(() {
                                _canAdd = value;

                                if (value) {
                                  _canView = true;
                                }
                              });
                            },
                          ),

                          SwitchListTile(
                            title: const Text('Edit'),
                            subtitle: const Text(
                              'User can edit records',
                            ),
                            secondary: const Icon(
                              Icons.edit_outlined,
                            ),
                            value: _canEdit,
                            onChanged: (value) {
                              setState(() {
                                _canEdit = value;

                                if (value) {
                                  _canView = true;
                                }
                              });
                            },
                          ),

                          SwitchListTile(
                            title: const Text('Delete'),
                            subtitle: const Text(
                              'User can delete/deactivate records',
                            ),
                            secondary: const Icon(
                              Icons.delete_outline,
                            ),
                            value: _canDelete,
                            onChanged: (value) {
                              setState(() {
                                _canDelete = value;

                                if (value) {
                                  _canView = true;
                                }
                              });
                            },
                          ),

                          const Divider(),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed:
                                  _saving ? null : _savePermission,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _saving
                                    ? 'Saving...'
                                    : 'Save Permission',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}