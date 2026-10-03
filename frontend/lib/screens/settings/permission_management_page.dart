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
  String? _error;

  List<Map<String, dynamic>> _roles = [];
  String? _selectedRoleId;

  // module_id -> { can_view, can_add, can_edit, can_delete, module_name, parent_id }
  final Map<String, Map<String, dynamic>> _permissions = {};

  // Original snapshot for dirty-checking
  final Map<String, Map<String, dynamic>> _original = {};

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  // =========================================================
  // LOAD ROLES
  // =========================================================

  Future<void> _loadRoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.get('/api/v1/admin/roles');

      final roles = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _roles = roles;
        _loading = false;

        if (roles.isNotEmpty) {
          _selectedRoleId = roles.first['id']?.toString();
        }
      });

      if (_selectedRoleId != null) {
        await _loadRolePermissions(_selectedRoleId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // =========================================================
  // LOAD ROLE PERMISSIONS (MATRIX)
  // =========================================================

  Future<void> _loadRolePermissions(String roleId) async {
    setState(() {
      _loading = true;
      _error = null;
      _permissions.clear();
      _original.clear();
    });

    try {
      final data = await _api.get(
        '/api/v1/admin/permissions/roles/$roleId',
      );

      if (data is! List) {
        throw Exception('Invalid permission response');
      }

      for (final item in data) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final moduleId = row['module_id']?.toString() ?? '';
        if (moduleId.isEmpty) continue;

        _permissions[moduleId] = {
          'module_id': moduleId,
          'module_name': row['module_name']?.toString() ?? moduleId,
          'parent_id': row['parent_id']?.toString(),
          'can_view': row['can_view'] == true,
          'can_add': row['can_add'] == true,
          'can_edit': row['can_edit'] == true,
          'can_delete': row['can_delete'] == true,
        };
      }

      // Snapshot for dirty checking
      for (final entry in _permissions.entries) {
        _original[entry.key] =
            Map<String, dynamic>.from(entry.value);
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // =========================================================
  // TOGGLE HANDLER
  // =========================================================

  void _toggle(
    String moduleId,
    String field,
    bool value,
  ) {
    final row = _permissions[moduleId];
    if (row == null) return;

    setState(() {
      row[field] = value;

      // Cascade: unchecking view → clear everything else
      if (field == 'can_view' && value == false) {
        row['can_add'] = false;
        row['can_edit'] = false;
        row['can_delete'] = false;
      }

      // Checking add/edit/delete → ensure view is on
      if (field != 'can_view' && value == true) {
        row['can_view'] = true;
      }
    });
  }

  bool _isDirty(String moduleId) {
    final a = _permissions[moduleId];
    final b = _original[moduleId];
    if (a == null || b == null) return false;

    for (final key in [
      'can_view',
      'can_add',
      'can_edit',
      'can_delete',
    ]) {
      if (a[key] != b[key]) return true;
    }
    return false;
  }

  bool get _hasChanges =>
      _permissions.keys.any((id) => _isDirty(id));

  // =========================================================
  // SAVE ALL CHANGES
  // =========================================================

  Future<void> _saveAll() async {
    if (_selectedRoleId == null) return;

    final dirtyIds = _permissions.keys
        .where((id) => _isDirty(id))
        .toList();

    if (dirtyIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      for (final moduleId in dirtyIds) {
        final row = _permissions[moduleId]!;

        await _api.put(
          '/api/v1/admin/permissions/roles/'
          '$_selectedRoleId/$moduleId',
          {
            'can_view': row['can_view'] == true,
            'can_add': row['can_add'] == true,
            'can_edit': row['can_edit'] == true,
            'can_delete': row['can_delete'] == true,
          },
        );
      }

      // Refresh original snapshot
      for (final id in dirtyIds) {
        _original[id] =
            Map<String, dynamic>.from(_permissions[id]!);
      }

      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${dirtyIds.length} '
            'module${dirtyIds.length == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Management'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  Widget _buildBody() {
    if (_loading && _roles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _roles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadRoles,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildRoleSelector(),
        const Divider(height: 1),
        Expanded(child: _buildMatrix()),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.badge_outlined,
              color: Color(0xFF0B5C9E)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRoleId,
              decoration: const InputDecoration(
                labelText: 'Select Role',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _roles.map((r) {
                final id = r['id']?.toString() ?? '';
                final name = r['role_name']?.toString() ?? id;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text('$name ($id)'),
                );
              }).toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedRoleId = value);
                      _loadRolePermissions(value);
                    },
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildMatrix() {
    if (_permissions.isEmpty) {
      return const Center(
        child: Text('No modules found'),
      );
    }

    // Sort by parent_id (nulls first), then preserve insertion order
    final modules = _permissions.values.toList();

    // Separate parents and children
    final parents = modules
        .where((m) => m['parent_id'] == null)
        .toList();

    final children = modules
        .where((m) => m['parent_id'] != null)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildHeaderRow(),
        ...parents.map((p) {
          final row = _buildModuleRow(p, isChild: false);
          final subChildren = children
              .where((c) => c['parent_id'] == p['module_id'])
              .toList();

          if (subChildren.isEmpty) return row;

          return Column(
            children: [
              row,
              ...subChildren.map(
                (c) => _buildModuleRow(c, isChild: true),
              ),
            ],
          );
        }),
        // Orphan children (parent not visible)
        ...children
            .where((c) => !parents.any(
                (p) => p['module_id'] == c['parent_id']))
            .map((c) => _buildModuleRow(c, isChild: true)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: const Color(0xFFEAF3FA),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Module',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _headerCell('View'),
          _headerCell('Add'),
          _headerCell('Edit'),
          _headerCell('Del'),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return SizedBox(
      width: 52,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildModuleRow(
    Map<String, dynamic> module, {
    required bool isChild,
  }) {
    final moduleId = module['module_id'] as String;
    final name = module['module_name'] as String? ?? moduleId;
    final canView = module['can_view'] == true;
    final dirty = _isDirty(moduleId);

    final rowColor = dirty
        ? const Color(0xFFFFF8E1)
        : (canView
            ? Colors.white
            : const Color(0xFFF5F5F5));

    return Container(
      color: rowColor,
      padding: EdgeInsets.only(
        left: isChild ? 28 : 12,
        right: 12,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (isChild)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isChild ? 13 : 14,
                      fontWeight: isChild
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: canView
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _checkBox(moduleId, 'can_view'),
          _checkBox(moduleId, 'can_add'),
          _checkBox(moduleId, 'can_edit'),
          _checkBox(moduleId, 'can_delete'),
        ],
      ),
    );
  }

  Widget _checkBox(String moduleId, String field) {
    final value = _permissions[moduleId]?[field] == true;
    return SizedBox(
      width: 52,
      child: Checkbox(
        value: value,
        onChanged: _loading
            ? null
            : (v) => _toggle(moduleId, field, v ?? false),
      ),
    );
  }

  Widget _buildSaveBar() {
    if (_selectedRoleId == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            if (_hasChanges)
              const Expanded(
                child: Text(
                  'Unsaved changes',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Expanded(
                child: Text(
                  'All changes saved',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: (_saving || !_hasChanges)
                    ? null
                    : _saveAll,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}