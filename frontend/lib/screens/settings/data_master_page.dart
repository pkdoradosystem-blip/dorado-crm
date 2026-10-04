import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class DataMasterPage extends StatefulWidget {
  final ApiClient apiClient;

  const DataMasterPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<DataMasterPage> createState() => _DataMasterPageState();
}

class _DataMasterPageState extends State<DataMasterPage> {
  bool _loadingTypes = true;
  bool _loadingData = false;

  String? _error;
  String? _selectedTypeId;

  List<Map<String, dynamic>> _masterTypes = [];
  List<Map<String, dynamic>> _records = [];

  final ScrollController _tableHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMasterTypes();
  }

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    super.dispose();
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase().trim();

    return text == 'true' || text == '1' || text == 'yes' || text == 'active';
  }

  Future<void> _loadMasterTypes() async {
    setState(() {
      _loadingTypes = true;
      _error = null;
    });

    try {
      final response = await widget.apiClient.get(
        '/api/v1/admin/master-types',
      );

      final types = <Map<String, dynamic>>[];

      if (response is List) {
        for (final item in response) {
          if (item is Map) {
            types.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      if (!mounted) return;

      String? selected = _selectedTypeId;

      if (selected == null && types.isNotEmpty) {
        selected = types.first['id']?.toString();
      }

      setState(() {
        _masterTypes = types;
        _selectedTypeId = selected;
        _loadingTypes = false;
      });

      if (selected != null && selected.isNotEmpty) {
        await _loadMasterData();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTypes = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _loadMasterData() async {
    final typeId = _selectedTypeId;

    if (typeId == null || typeId.isEmpty) {
      setState(() {
        _records = [];
      });
      return;
    }

    setState(() {
      _loadingData = true;
      _error = null;
    });

    try {
      // active_only=false is important because Admin must
      // also be able to see and reactivate inactive records.
      final response = await widget.apiClient.get(
        '/api/v1/master-data/$typeId?active_only=false',
      );

      final records = <Map<String, dynamic>>[];

      if (response is List) {
        for (final item in response) {
          if (item is Map) {
            records.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _records = records;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingData = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _addMasterType() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final orderController = TextEditingController(text: '0');

    bool allowGlobal = false;
    bool active = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Master Type'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Master Type ID *',
                          hintText: 'Example: DESIGNATION',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Master Type Name *',
                          hintText: 'Example: Designation',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Global'),
                        value: allowGlobal,
                        onChanged: (value) {
                          setDialogState(() {
                            allowGlobal = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final id = idController.text.trim().toUpperCase();
                    final name = nameController.text.trim();

                    if (id.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Master Type ID and Name are required',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await widget.apiClient.post(
                        '/api/v1/admin/master-types',
                        {
                          'id': id,
                          'master_name': name,
                          'description': descriptionController.text.trim(),
                          'allow_global': allowGlobal,
                          'display_order':
                              int.tryParse(orderController.text) ?? 0,
                          'active': active,
                        },
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_cleanError(e)),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    idController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();

    if (saved == true) {
      await _loadMasterTypes();
    }
  }

  Future<void> _editSelectedMasterType() async {
    final typeId = _selectedTypeId;

    if (typeId == null || typeId.isEmpty) {
      return;
    }

    Map<String, dynamic>? selectedType;

    for (final type in _masterTypes) {
      if (type['id']?.toString() == typeId) {
        selectedType = type;
        break;
      }
    }

    if (selectedType == null) {
      return;
    }

    final nameController = TextEditingController(
      text: selectedType['master_name']?.toString() ??
          selectedType['name']?.toString() ??
          '',
    );

    final descriptionController = TextEditingController(
      text: selectedType['description']?.toString() ?? '',
    );

    final orderController = TextEditingController(
      text: selectedType['display_order']?.toString() ?? '0',
    );

    bool allowGlobal = _asBool(selectedType['allow_global']);
    bool active = _asBool(selectedType['active']);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Master Type'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: typeId,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Master Type ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Master Type Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Global'),
                        value: allowGlobal,
                        onChanged: (value) {
                          setDialogState(() {
                            allowGlobal = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: Text(
                          active
                              ? 'This Master Type is available'
                              : 'This Master Type is inactive',
                        ),
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Master Type Name is required',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await widget.apiClient.put(
                        '/api/v1/admin/master-types/$typeId',
                        {
                          'name': name,
                          'description': descriptionController.text.trim(),
                          'display_order':
                              int.tryParse(orderController.text) ?? 0,
                          'allow_global': allowGlobal,
                          'active': active,
                        },
                      );

                      if (!dialogContext.mounted) return;

                      Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_cleanError(e)),
                        ),
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    orderController.dispose();

    if (saved == true) {
      await _loadMasterTypes();
    }
  }

  Future<void> _showRecordDialog({
    Map<String, dynamic>? record,
  }) async {
    final editing = record != null;

    final codeController = TextEditingController(
      text: record?['code']?.toString() ?? '',
    );

    final nameController = TextEditingController(
      text: record?['name']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: record?['description']?.toString() ?? '',
    );

    final departmentController = TextEditingController(
      text: record?['department_id']?.toString() ?? '',
    );

    final orderController = TextEditingController(
      text: record?['display_order']?.toString() ?? '0',
    );

    bool active = record == null ? true : _asBool(record['active']);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                editing ? 'Edit Master Data' : 'Add Master Data',
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Code *',
                          hintText: 'Example: SUPERVISOR',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department ID',
                          hintText: 'Optional â€” e.g. DEP001 or GLOBAL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Display Order',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final typeId = _selectedTypeId;
                    final code = codeController.text.trim().toUpperCase();
                    final name = nameController.text.trim();

                    if (typeId == null ||
                        typeId.isEmpty ||
                        code.isEmpty ||
                        name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Master Type, Code and Name are required',
                          ),
                        ),
                      );
                      return;
                    }

                    final department = departmentController.text.trim();

                    final body = <String, dynamic>{
                      'code': code,
                      'name': name,
                      'description': descriptionController.text.trim(),
                      'department_id': department.isEmpty ? null : department,
                      'display_order': int.tryParse(orderController.text) ?? 0,
                      'active': active,
                    };

                    try {
                      if (editing) {
                        final recordId = record['id'];

                        await widget.apiClient.put(
                          '/api/v1/admin/master-data/$recordId',
                          body,
                        );
                      } else {
                        body['master_type_id'] = typeId;

                        await widget.apiClient.post(
                          '/api/v1/admin/master-data',
                          body,
                        );
                      }

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_cleanError(e)),
                        ),
                      );
                    }
                  },
                  child: Text(editing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    departmentController.dispose();
    orderController.dispose();

    if (saved == true) {
      await _loadMasterData();
    }
  }

  Future<void> _deactivateRecord(
    Map<String, dynamic> record,
  ) async {
    final id = record['id'];
    final name = record['name']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate Master Data'),
          content: Text(
            'Deactivate "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await widget.apiClient.delete(
        '/api/v1/admin/master-data/$id',
      );

      await _loadMasterData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
        ),
      );
    }
  }

  Future<void> _reactivateRecord(
    Map<String, dynamic> record,
  ) async {
    final id = record['id'];

    try {
      await widget.apiClient.put(
        '/api/v1/admin/master-data/$id',
        {
          'active': true,
        },
      );

      await _loadMasterData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Master'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadMasterTypes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _selectedTypeId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showRecordDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Data'),
            ),
      body: _loadingTypes
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadMasterTypes,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Master Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _masterTypes.map((type) {
                            final id = type['id']?.toString() ?? '';

                            final name = type['master_name']?.toString() ?? id;

                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedTypeId = value;
                            });

                            await _loadMasterData();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Edit Master Type',
                        onPressed: _selectedTypeId == null
                            ? null
                            : _editSelectedMasterType,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Add Master Type',
                        onPressed: _addMasterType,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (_masterTypes.isEmpty) ...[
                    const SizedBox(height: 40),
                    const Center(
                      child: Text(
                        'No Master Type found.\n'
                        'Use + to create the first Master Type.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_loadingData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_selectedTypeId != null && _records.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'No master data found.\n'
                          'Click Add Data to create one.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Scrollbar(
                        controller: _tableHorizontalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _tableHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            horizontalMargin: 10,
                            headingRowHeight: 34,
                            dataRowMinHeight: 34,
                            dataRowMaxHeight: 36,
                            headingTextStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            dataTextStyle: const TextStyle(
                              fontSize: 11,
                            ),
                            columns: const [
                              DataColumn(
                                label: SizedBox(
                                  width: 140,
                                  child: Text('Code'),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 165,
                                  child: Text('Name'),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 45,
                                  child: Text('Order'),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 75,
                                  child: Text('Status'),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 40,
                                  child: Text('Edit'),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 70,
                                  child: Text('Active'),
                                ),
                              ),
                            ],
                            rows: _records.map((record) {
                              final active = _asBool(record['active']);
                              final code = record['code']?.toString() ?? '';
                              final name = record['name']?.toString() ?? '';
                              final order =
                                  record['display_order']?.toString() ?? '0';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        code,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 165,
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 45,
                                      child: Text(order),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 75,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            active
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            size: 15,
                                            color: active
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            active ? 'Active' : 'Inactive',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 40,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        tooltip: 'Edit',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _showRecordDialog(
                                            record: record,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 70,
                                      child: Transform.scale(
                                        scale: 0.68,
                                        child: Switch(
                                          value: active,
                                          onChanged: (value) async {
                                            if (value) {
                                              await _reactivateRecord(
                                                record,
                                              );
                                            } else {
                                              await _deactivateRecord(
                                                record,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
