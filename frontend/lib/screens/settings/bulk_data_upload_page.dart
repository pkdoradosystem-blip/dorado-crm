import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class BulkDataUploadPage extends StatefulWidget {
  final ApiClient apiClient;

  const BulkDataUploadPage({
    super.key,
    required this.apiClient,
  });

  @override
  State<BulkDataUploadPage> createState() => _BulkDataUploadPageState();
}

class _BulkDataUploadPageState extends State<BulkDataUploadPage> {
  bool _loadingOptions = true;
  bool _previewing = false;
  bool _importing = false;
  bool _downloadingTemplate = false;
  bool _updateExisting = true;

  String? _error;

  String _importType = 'MASTER_DATA';
  String? _masterTypeId;
  String? _selectedSheet;

  PlatformFile? _file;
  List<int>? _fileBytes;

  List<Map<String, dynamic>> _importTypes = [];
  List<Map<String, dynamic>> _masterTypes = [];

  List<String> _availableSheets = [];
  List<String> _headers = [];

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _validation = [];

  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.get(
          '/api/v1/admin/bulk-import/types',
        ),
        widget.apiClient.get(
          '/api/v1/admin/bulk-import/master-types',
        ),
      ]);

      final typeResponse = results[0];
      final masterResponse = results[1];

      List<Map<String, dynamic>> types = [];

      if (typeResponse is Map) {
        types = _mapList(
          typeResponse['import_types'],
        );
      }

      final masters = _mapList(masterResponse);

      if (!mounted) return;

      setState(() {
        _importTypes = types;
        _masterTypes = masters;

        if (_importTypes.isNotEmpty &&
            !_importTypes.any(
              (item) => item['id']?.toString() == _importType,
            )) {
          _importType = _importTypes.first['id'].toString();
        }

        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingOptions = false;
        _error = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String get _selectedTemplateName {
    if (_importType == 'MASTER_DATA') {
      for (final item in _masterTypes) {
        if (item['id']?.toString() == _masterTypeId) {
          return item['name']?.toString() ?? 'Master Data';
        }
      }

      return 'Master Data';
    }

    for (final item in _importTypes) {
      if (item['id']?.toString() == _importType) {
        return item['name']?.toString() ?? _importType;
      }
    }

    return _importType;
  }

  Future<void> _downloadTemplate() async {
    if (_importType == 'MASTER_DATA' &&
        (_masterTypeId == null || _masterTypeId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Master Type first.'),
        ),
      );
      return;
    }

    setState(() {
      _downloadingTemplate = true;
      _error = null;
    });

    try {
      final query = <String>[
        'import_type=${Uri.encodeQueryComponent(_importType)}',
      ];

      if (_masterTypeId != null && _masterTypeId!.isNotEmpty) {
        query.add(
          'master_type_id=${Uri.encodeQueryComponent(_masterTypeId!)}',
        );
      }

      final response = await widget.apiClient.getBytes(
        '/api/v1/admin/bulk-import/template?${query.join('&')}',
      );

      String fileName;

      final disposition = response.headers['content-disposition'];

      final match = disposition == null
          ? null
          : RegExp(
              r'filename="?([^";]+)"?',
              caseSensitive: false,
            ).firstMatch(disposition);

      if (match != null) {
        fileName = match.group(1)!;
      } else {
        final safeName =
            _selectedTemplateName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

        fileName = '${safeName}_Import_Template.xlsx';
      }

      await FilePicker.saveFile(
        dialogTitle: 'Save $_selectedTemplateName Template',
        fileName: fileName,
        bytes: response.bodyBytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_selectedTemplateName template downloaded.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloadingTemplate = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (files.isEmpty) {
      return;
    }

    final selected = files.first;
    final bytes = await selected.xFile.readAsBytes();

    if (bytes.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to read selected Excel file.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _file = selected;
      _fileBytes = bytes;
      _availableSheets = [];
      _selectedSheet = null;
      _headers = [];
      _rows = [];
      _validation = [];
      _summary = null;
      _error = null;
    });
  }

  Map<String, String> _fields({
    bool includeUpdate = false,
  }) {
    final fields = <String, String>{
      'import_type': _importType,
    };

    if (_masterTypeId != null && _masterTypeId!.isNotEmpty) {
      fields['master_type_id'] = _masterTypeId!;
    }

    if (_selectedSheet != null && _selectedSheet!.isNotEmpty) {
      fields['sheet_name'] = _selectedSheet!;
    }

    if (includeUpdate) {
      fields['update_existing'] = _updateExisting ? 'true' : 'false';
    }

    return fields;
  }

  bool _validateSelection() {
    if (_file == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an Excel file first.',
          ),
        ),
      );

      return false;
    }

    if (_importType == 'MASTER_DATA' &&
        (_masterTypeId == null || _masterTypeId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select Master Type.',
          ),
        ),
      );

      return false;
    }

    return true;
  }

  Future<void> _preview() async {
    if (!_validateSelection()) return;

    setState(() {
      _previewing = true;
      _error = null;
      _summary = null;
    });

    try {
      final response = await widget.apiClient.multipartPost(
        '/api/v1/admin/bulk-import/preview',
        fileBytes: _fileBytes!,
        fileName: _file!.name,
        fields: _fields(),
      );

      if (response is! Map) {
        throw Exception(
          'Invalid preview response from server.',
        );
      }

      final map = Map<String, dynamic>.from(response);

      final sheets = (map['available_sheets'] is List)
          ? List<String>.from(
              map['available_sheets'].map(
                (item) => item.toString(),
              ),
            )
          : <String>[];

      final headers = (map['headers'] is List)
          ? List<String>.from(
              map['headers'].map(
                (item) => item.toString(),
              ),
            )
          : <String>[];

      final rows = _mapList(map['rows']);
      final validation = _mapList(map['validation']);

      if (!mounted) return;

      setState(() {
        _availableSheets = sheets;

        _selectedSheet = map['selected_sheet']?.toString();

        _headers = headers;
        _rows = rows;
        _validation = validation;

        _previewing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _previewing = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _importData() async {
    if (!_validateSelection()) return;

    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preview the Excel file before import.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Import'),
          content: Text(
            'Import ${_file!.name} into $_importType?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final response = await widget.apiClient.multipartPost(
        '/api/v1/admin/bulk-import/import',
        fileBytes: _fileBytes!,
        fileName: _file!.name,
        fields: _fields(
          includeUpdate: true,
        ),
      );

      if (response is! Map) {
        throw Exception(
          'Invalid import response from server.',
        );
      }

      final map = Map<String, dynamic>.from(response);

      final rawSummary = map['summary'];

      if (!mounted) return;

      setState(() {
        _summary = rawSummary is Map
            ? Map<String, dynamic>.from(
                rawSummary,
              )
            : null;

        _validation = _mapList(map['results']);

        _importing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bulk import completed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _importing = false;
        _error = _cleanError(e);
      });
    }
  }

  void _changeImportType(String? value) {
    if (value == null) return;

    setState(() {
      _importType = value;
      _masterTypeId = null;

      _availableSheets = [];
      _selectedSheet = null;
      _headers = [];
      _rows = [];
      _validation = [];
      _summary = null;
      _error = null;
    });
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguration() {
    return _section(
      title: 'Import Configuration',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _importType,
            decoration: const InputDecoration(
              labelText: 'Import Type',
              border: OutlineInputBorder(),
            ),
            items: _importTypes.map((item) {
              final id = item['id'].toString();

              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  item['name']?.toString() ?? id,
                ),
              );
            }).toList(),
            onChanged: _previewing || _importing ? null : _changeImportType,
          ),
          if (_importType == 'MASTER_DATA') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _masterTypeId,
              decoration: const InputDecoration(
                labelText: 'Master Type',
                border: OutlineInputBorder(),
              ),
              items: _masterTypes.map((item) {
                final id = item['id'].toString();

                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(
                    item['name']?.toString() ?? id,
                  ),
                );
              }).toList(),
              onChanged: _previewing || _importing
                  ? null
                  : (value) {
                      setState(() {
                        _masterTypeId = value;
                        _rows = [];
                        _validation = [];
                        _summary = null;
                      });
                    },
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _previewing ||
                      _importing ||
                      _downloadingTemplate ||
                      (_importType == 'MASTER_DATA' &&
                          (_masterTypeId == null || _masterTypeId!.isEmpty))
                  ? null
                  : _downloadTemplate,
              icon: _downloadingTemplate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.download_outlined,
                    ),
              label: Text(
                _downloadingTemplate
                    ? 'Preparing Template...'
                    : 'Download $_selectedTemplateName Template',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _file == null ? 'No Excel file selected' : _file!.name,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _previewing || _importing ? null : _pickFile,
                icon: const Icon(
                  Icons.upload_file,
                ),
                label: const Text(
                  'Select Filled Excel',
                ),
              ),
            ],
          ),
          if (_availableSheets.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedSheet,
              decoration: const InputDecoration(
                labelText: 'Worksheet',
                border: OutlineInputBorder(),
              ),
              items: _availableSheets.map((sheet) {
                return DropdownMenuItem<String>(
                  value: sheet,
                  child: Text(sheet),
                );
              }).toList(),
              onChanged: _previewing || _importing
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSheet = value;
                        _rows = [];
                        _validation = [];
                        _summary = null;
                      });
                    },
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Update Existing Records',
            ),
            subtitle: const Text(
              'If OFF, existing records will be skipped.',
            ),
            value: _updateExisting,
            onChanged: _importing
                ? null
                : (value) {
                    setState(() {
                      _updateExisting = value;
                    });
                  },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _previewing || _importing ? null : _preview,
              icon: _previewing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.preview,
                    ),
              label: Text(
                _previewing ? 'Reading Excel...' : 'Preview & Validate',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_summary == null) {
      return const SizedBox.shrink();
    }

    Widget item(
      String label,
      dynamic value,
    ) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 8,
            ),
            child: Column(
              children: [
                Text(
                  value?.toString() ?? '0',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
          ),
        ),
      );
    }

    return _section(
      title: 'Import Summary',
      child: Row(
        children: [
          item('Total', _summary!['total']),
          item('Created', _summary!['created']),
          item('Updated', _summary!['updated']),
          item('Skipped', _summary!['skipped']),
          item('Failed', _summary!['failed']),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final validationByRow = <String, Map<String, dynamic>>{};

    for (final item in _validation) {
      final key = item['excel_row']?.toString();

      if (key != null) {
        validationByRow[key] = item;
      }
    }

    final displayHeaders = _headers
        .where(
          (header) => header != '_excel_row',
        )
        .toList();

    final hasValidationErrors = _validation.any(
      (item) => item['valid'] == false,
    );

    return _section(
      title: 'Preview (${_rows.length} rows shown)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(
                  label: Text('Row'),
                ),
                ...displayHeaders.map(
                  (header) => DataColumn(
                    label: Text(header),
                  ),
                ),
                const DataColumn(
                  label: Text('Validation'),
                ),
              ],
              rows: _rows.map((row) {
                final excelRow = row['_excel_row']?.toString() ?? '';

                final validation = validationByRow[excelRow];

                final valid = validation?['valid'] != false;

                final action = validation?['action']?.toString() ?? '';

                final errors = validation?['errors'];

                String status = action;

                if (!valid) {
                  if (errors is List && errors.isNotEmpty) {
                    status = errors.join(', ');
                  } else {
                    status = 'Error';
                  }
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Text(excelRow),
                    ),
                    ...displayHeaders.map(
                      (header) => DataCell(
                        Text(
                          header == 'temporary_password' ||
                                  header == 'password'
                              ? ((row[header]?.toString().isNotEmpty ?? false)
                                  ? '********'
                                  : '')
                              : row[header]?.toString() ?? '',
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            valid
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.isEmpty ? 'Ready' : status,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _importing || _previewing || hasValidationErrors
                      ? null
                      : _importData,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.cloud_upload,
                    ),
              label: Text(
                _importing ? 'Importing...' : 'Import Data',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bulk Data Upload',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingOptions ? null : _loadOptions,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _loadingOptions
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadOptions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                _error!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildConfiguration(),
                  _buildSummary(),
                  _buildPreview(),
                ],
              ),
            ),
    );
  }
}
