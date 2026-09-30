import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class EmployeeProfilePage extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> user;

  const EmployeeProfilePage({
    super.key,
    required this.apiClient,
    required this.user,
  });

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Map<String, dynamic> _user;

  bool _editMode = false;
  bool _saving = false;
  bool _loadingOptions = false;

  final Map<String, TextEditingController> _c = {};
  String? _gender;
  String? _departmentId;
  String? _roleId;
  String? _reportingManagerId;
  String? _employeeType;
  bool _pfApplicable = false;
  bool _esicApplicable = false;
  bool _active = true;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _employeeTypes = [];

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _tabController = TabController(length: 5, vsync: this);
    _createControllers();
    _loadEditorFromUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(List<String> keys) {
    for (final key in keys) {
      final value = _user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _boolValue(String key, {bool fallback = false}) {
    final value = _user[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  String _dateOnly(List<String> keys) {
    final value = _text(keys);
    if (value.isEmpty) return '';
    final raw =
        value.contains('T') ? value.split('T').first : value.split(' ').first;
    final parts = raw.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}';
    }
    return value;
  }

  String? _apiDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final parts = text.split('-');
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return text.split('T').first;
  }

  String _status() =>
      _boolValue('active', fallback: true) ? 'Active' : 'Inactive';

  String _yesNo(String key) => _boolValue(key) ? 'Yes' : 'No';

  String _money(List<String> keys) {
    final value = _text(keys);
    if (value.isEmpty) return '';
    final number = double.tryParse(value);
    return number == null ? value : 'Rs. ${number.toStringAsFixed(2)}';
  }

  String? _nullText(String key) {
    final value = _c[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _number(String key) {
    final value = _c[key]!.text.trim().replaceAll(',', '');
    return value.isEmpty ? null : double.tryParse(value);
  }

  void _createControllers() {
    for (final key in [
      'employee_name',
      'father_name',
      'date_of_birth',
      'blood_group',
      'mobile',
      'alternate_mobile',
      'email',
      'present_address',
      'permanent_address',
      'emergency_contact_name',
      'emergency_contact_mobile',
      'emergency_contact_relation',
      'designation',
      'date_of_joining',
      'work_location',
      'date_of_exit',
      'uan_number',
      'pf_number',
      'esic_number',
      'employee_pf_contribution',
      'employer_pf_contribution',
      'employee_esic_contribution',
      'employer_esic_contribution',
      'basic_salary',
      'hra',
      'conveyance_allowance',
      'other_allowance',
      'gross_salary',
      'ctc',
      'bank_name',
      'bank_account_holder_name',
      'bank_account_number',
      'bank_ifsc',
      'bank_branch',
      'pan_number',
      'aadhaar_number',
    ]) {
      _c[key] = TextEditingController();
    }
  }

  void _loadEditorFromUser() {
    void setText(String key, List<String> sourceKeys, {bool date = false}) {
      _c[key]!.text = date ? _dateOnly(sourceKeys) : _text(sourceKeys);
    }

    setText('employee_name', ['employee_name', 'name']);
    setText('father_name', ['father_name', 'spouse_name']);
    setText('date_of_birth', ['date_of_birth'], date: true);
    setText('blood_group', ['blood_group']);
    setText('mobile', ['mobile', 'phone']);
    setText('alternate_mobile', ['alternate_mobile']);
    setText('email', ['email']);
    setText('present_address', ['present_address']);
    setText('permanent_address', ['permanent_address']);
    setText('emergency_contact_name', ['emergency_contact_name']);
    setText('emergency_contact_mobile', ['emergency_contact_mobile']);
    setText('emergency_contact_relation', ['emergency_contact_relation']);
    setText('designation', ['designation']);
    setText('date_of_joining', ['date_of_joining'], date: true);
    setText('work_location', ['work_location']);
    setText('date_of_exit', ['date_of_exit'], date: true);
    setText('uan_number', ['uan_number']);
    setText('pf_number', ['pf_number']);
    setText('esic_number', ['esic_number']);
    setText('employee_pf_contribution', ['employee_pf_contribution']);
    setText('employer_pf_contribution', ['employer_pf_contribution']);
    setText('employee_esic_contribution', ['employee_esic_contribution']);
    setText('employer_esic_contribution', ['employer_esic_contribution']);
    setText('basic_salary', ['basic_salary']);
    setText('hra', ['hra']);
    setText('conveyance_allowance', ['conveyance_allowance']);
    setText('other_allowance', ['other_allowance']);
    setText('gross_salary', ['gross_salary']);
    setText('ctc', ['ctc']);
    setText('bank_name', ['bank_name']);
    setText('bank_account_holder_name', ['bank_account_holder_name']);
    setText('bank_account_number', ['bank_account_number']);
    setText('bank_ifsc', ['bank_ifsc']);
    setText('bank_branch', ['bank_branch']);
    setText('pan_number', ['pan_number']);
    setText('aadhaar_number', ['aadhaar_number']);

    _gender = _text(['gender']).isEmpty ? null : _text(['gender']);
    _departmentId =
        _text(['department_id']).isEmpty ? null : _text(['department_id']);
    _roleId = _text(['role_id']).isEmpty ? null : _text(['role_id']);
    _reportingManagerId = _text(['reporting_manager_id']).isEmpty
        ? null
        : _text(['reporting_manager_id']);
    _employeeType =
        _text(['employee_type']).isEmpty ? null : _text(['employee_type']);
    _pfApplicable = _boolValue('pf_applicable');
    _esicApplicable = _boolValue('esic_applicable');
    _active = _boolValue('active', fallback: true);
  }

  List<Map<String, dynamic>> _mapList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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
              .map((e) => Map<String, dynamic>.from(e))
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

  String _nameOf(Map<String, dynamic> item) {
    return (item['name'] ??
            item['employee_name'] ??
            item['department_name'] ??
            item['role_name'] ??
            item['master_name'] ??
            item['title'] ??
            _idOf(item))
        .toString()
        .trim();
  }

  Future<void> _startEdit() async {
    _loadEditorFromUser();
    setState(() {
      _editMode = true;
      _loadingOptions = true;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.get('/api/v1/admin/departments'),
        widget.apiClient.get('/api/v1/admin/roles'),
        widget.apiClient.get('/api/v1/admin/users'),
        widget.apiClient
            .get('/api/v1/master-data/DESIGNATION?active_only=true'),
        widget.apiClient
            .get('/api/v1/master-data/EMPLOYEE_TYPE?active_only=true'),
      ]);

      if (!mounted) return;
      setState(() {
        _departments = _mapList(results[0]);
        _roles = _mapList(results[1]);
        _users = _mapList(results[2]);
        _designations = _mapList(results[3]);
        _employeeTypes = _mapList(results[4]);
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load edit options: $e')),
      );
    }
  }

  void _cancelEdit() {
    _loadEditorFromUser();
    setState(() => _editMode = false);
  }

  Future<void> _pickDate(String key, {required bool birthDate}) async {
    final today = DateTime.now();
    DateTime initial = birthDate ? DateTime(today.year - 25) : today;
    final api = _apiDate(_c[key]!.text);
    if (api != null) {
      initial = DateTime.tryParse(api) ?? initial;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: birthDate ? DateTime(1940) : DateTime(1990),
      lastDate: birthDate ? today : DateTime(today.year + 10),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _c[key]!.text =
          '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
    });
  }

  Future<void> _saveAll() async {
    if (_saving) return;

    if (_c['employee_name']!.text.trim().isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee Name is required')),
      );
      return;
    }

    final employeeId = _text(['id', 'employee_id', 'user_id']);
    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found')),
      );
      return;
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'employee_name': _c['employee_name']!.text.trim(),
      'father_name': _nullText('father_name'),
      'date_of_birth': _apiDate(_c['date_of_birth']!.text),
      'gender': _gender,
      'blood_group': _nullText('blood_group'),
      'mobile': _nullText('mobile'),
      'alternate_mobile': _nullText('alternate_mobile'),
      'email': _nullText('email'),
      'present_address': _nullText('present_address'),
      'permanent_address': _nullText('permanent_address'),
      'emergency_contact_name': _nullText('emergency_contact_name'),
      'emergency_contact_mobile': _nullText('emergency_contact_mobile'),
      'emergency_contact_relation': _nullText('emergency_contact_relation'),
      'designation': _nullText('designation'),
      'department_id': _departmentId,
      'role_id': _roleId,
      'reporting_manager_id': _reportingManagerId,
      'date_of_joining': _apiDate(_c['date_of_joining']!.text),
      'employee_type': _employeeType,
      'work_location': _nullText('work_location'),
      'date_of_exit': _apiDate(_c['date_of_exit']!.text),
      'pf_applicable': _pfApplicable,
      'esic_applicable': _esicApplicable,
      'uan_number': _nullText('uan_number'),
      'pf_number': _nullText('pf_number'),
      'esic_number': _nullText('esic_number'),
      'employee_pf_contribution': _number('employee_pf_contribution'),
      'employer_pf_contribution': _number('employer_pf_contribution'),
      'employee_esic_contribution': _number('employee_esic_contribution'),
      'employer_esic_contribution': _number('employer_esic_contribution'),
      'basic_salary': _number('basic_salary'),
      'hra': _number('hra'),
      'conveyance_allowance': _number('conveyance_allowance'),
      'other_allowance': _number('other_allowance'),
      'gross_salary': _number('gross_salary'),
      'ctc': _number('ctc'),
      'bank_name': _nullText('bank_name'),
      'bank_account_holder_name': _nullText('bank_account_holder_name'),
      'bank_account_number': _nullText('bank_account_number'),
      'bank_ifsc': _nullText('bank_ifsc'),
      'bank_branch': _nullText('bank_branch'),
      'pan_number': _nullText('pan_number'),
      'aadhaar_number': _nullText('aadhaar_number'),
      'active': _active,
    };

    try {
      final response = await widget.apiClient.put(
        '/api/v1/admin/users/$employeeId',
        payload,
      );

      if (!mounted) return;

      final updated = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{..._user, ...payload};

      setState(() {
        _user = {..._user, ...payload, ...updated};
        _editMode = false;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _field(String key, String label,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _decoration(label),
      ),
    );
  }

  Widget _dateField(String key, String label, {bool birthDate = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        readOnly: true,
        onTap: () => _pickDate(key, birthDate: birthDate),
        decoration: _decoration(label).copyWith(
          suffixIcon: IconButton(
            onPressed: () => _pickDate(key, birthDate: birthDate),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
      ),
    );
  }

  List<String> _masterNames(List<Map<String, dynamic>> source,
      {String? current}) {
    final values = <String>[];
    for (final item in source) {
      final name = _nameOf(item);
      if (name.isNotEmpty && !values.contains(name)) values.add(name);
    }
    if (current != null && current.isNotEmpty && !values.contains(current)) {
      values.add(current);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final employeeId = _text(['id', 'employee_id', 'user_id']);
    final employeeName = _text(['employee_name', 'name']);
    final designation = _text(['designation']);
    final initial =
        employeeName.isEmpty ? '?' : employeeName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          if (!_editMode)
            TextButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Employee'),
            )
          else ...[
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _saving || _loadingOptions ? null : _saveAll,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName.isEmpty
                            ? 'Unnamed Employee'
                            : employeeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [employeeId, designation]
                            .where((value) => value.isNotEmpty)
                            .join(' | '),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _status(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              _status() == 'Active' ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loadingOptions) const LinearProgressIndicator(),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Personal'),
              Tab(text: 'Employment'),
              Tab(text: 'PF & ESIC'),
              Tab(text: 'Salary / Bank'),
              Tab(text: 'Documents'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonal(),
                _buildEmployment(),
                _buildPfEsic(),
                _buildSalaryBank(),
                _buildDocuments(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonal() {
    if (_editMode) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('employee_name', 'Employee Name'),
          _field('father_name', 'Father / Spouse Name'),
          _dateField('date_of_birth', 'Date of Birth', birthDate: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: const ['Male', 'Female', 'Other'].contains(_gender)
                  ? _gender
                  : null,
              decoration: _decoration('Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
          ),
          _field('blood_group', 'Blood Group'),
          _field('mobile', 'Mobile', keyboardType: TextInputType.phone),
          _field('alternate_mobile', 'Alternate Mobile',
              keyboardType: TextInputType.phone),
          _field('email', 'Email', keyboardType: TextInputType.emailAddress),
          _field('present_address', 'Present Address', maxLines: 2),
          _field('permanent_address', 'Permanent Address', maxLines: 2),
          const Divider(height: 28),
          const Text(
            'Emergency Contact',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _field('emergency_contact_name', 'Contact Name'),
          _field('emergency_contact_mobile', 'Contact Mobile',
              keyboardType: TextInputType.phone),
          _field('emergency_contact_relation', 'Relation'),
        ],
      );
    }

    return _ProfileList(
      children: [
        _ProfileSection(
          title: 'Personal Information',
          children: [
            _ProfileRow(
                label: 'Employee ID',
                value: _text(['id', 'employee_id', 'user_id'])),
            _ProfileRow(
                label: 'Employee Name',
                value: _text(['employee_name', 'name'])),
            _ProfileRow(
                label: 'Father / Spouse Name',
                value: _text(['father_name', 'spouse_name'])),
            _ProfileRow(
                label: 'Date of Birth', value: _dateOnly(['date_of_birth'])),
            _ProfileRow(label: 'Gender', value: _text(['gender'])),
            _ProfileRow(label: 'Blood Group', value: _text(['blood_group'])),
          ],
        ),
        _ProfileSection(
          title: 'Contact Information',
          children: [
            _ProfileRow(label: 'Mobile', value: _text(['mobile', 'phone'])),
            _ProfileRow(
                label: 'Alternate Mobile', value: _text(['alternate_mobile'])),
            _ProfileRow(label: 'Email', value: _text(['email'])),
            _ProfileRow(
                label: 'Present Address', value: _text(['present_address'])),
            _ProfileRow(
                label: 'Permanent Address',
                value: _text(['permanent_address'])),
          ],
        ),
        _ProfileSection(
          title: 'Emergency Contact',
          children: [
            _ProfileRow(
                label: 'Name', value: _text(['emergency_contact_name'])),
            _ProfileRow(
                label: 'Mobile', value: _text(['emergency_contact_mobile'])),
            _ProfileRow(
                label: 'Relation',
                value: _text(['emergency_contact_relation'])),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployment() {
    if (_editMode) {
      final designations =
          _masterNames(_designations, current: _c['designation']!.text.trim());
      final employeeTypes =
          _masterNames(_employeeTypes, current: _employeeType);

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _c['designation']!.text.trim().isEmpty
                ? null
                : _c['designation']!.text.trim(),
            isExpanded: true,
            decoration: _decoration('Designation'),
            items: designations
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) =>
                setState(() => _c['designation']!.text = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _departments.any((x) => _idOf(x) == _departmentId)
                ? _departmentId
                : null,
            isExpanded: true,
            decoration: _decoration('Department'),
            items: _departments
                .where((x) => _idOf(x).isNotEmpty)
                .map((x) => DropdownMenuItem(
                      value: _idOf(x),
                      child: Text(_nameOf(x)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _departmentId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _roles.any((x) => _idOf(x) == _roleId) ? _roleId : null,
            isExpanded: true,
            decoration: _decoration('Role'),
            items: _roles
                .where((x) => _idOf(x).isNotEmpty)
                .map((x) => DropdownMenuItem(
                      value: _idOf(x),
                      child: Text(_nameOf(x)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _roleId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _users.any((x) => _idOf(x) == _reportingManagerId)
                ? _reportingManagerId
                : null,
            isExpanded: true,
            decoration: _decoration('Reporting Manager'),
            items: _users
                .where((x) =>
                    _idOf(x).isNotEmpty &&
                    _idOf(x) != _text(['id', 'employee_id', 'user_id']))
                .map((x) => DropdownMenuItem(
                      value: _idOf(x),
                      child: Text(_nameOf(x)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _reportingManagerId = value),
          ),
          const SizedBox(height: 12),
          _dateField('date_of_joining', 'Date of Joining'),
          DropdownButtonFormField<String>(
            initialValue: _employeeType == null || _employeeType!.isEmpty
                ? null
                : _employeeType,
            isExpanded: true,
            decoration: _decoration('Employee Type'),
            items: employeeTypes
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(() => _employeeType = value),
          ),
          const SizedBox(height: 12),
          _field('work_location', 'Work Location'),
          _dateField('date_of_exit', 'Date of Exit'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active User'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
        ],
      );
    }

    return _ProfileList(
      children: [
        _ProfileSection(
          title: 'Employment Information',
          children: [
            _ProfileRow(label: 'Designation', value: _text(['designation'])),
            _ProfileRow(
                label: 'Department',
                value: _text(['department', 'department_name'])),
            _ProfileRow(
                label: 'Role', value: _text(['role', 'role_name', 'app_role'])),
            _ProfileRow(
              label: 'Reporting Manager',
              value: _text([
                'reporting_manager_name',
                'reporting_manager',
                'reporting_manager_id',
              ]),
            ),
            _ProfileRow(
                label: 'Date of Joining',
                value: _dateOnly(['date_of_joining'])),
            _ProfileRow(
                label: 'Employee Type', value: _text(['employee_type'])),
            _ProfileRow(
                label: 'Work Location', value: _text(['work_location'])),
            _ProfileRow(
                label: 'Date of Exit', value: _dateOnly(['date_of_exit'])),
            _ProfileRow(label: 'Status', value: _status()),
          ],
        ),
      ],
    );
  }

  Widget _buildPfEsic() {
    if (_editMode) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PF Applicable'),
            value: _pfApplicable,
            onChanged: (value) => setState(() => _pfApplicable = value),
          ),
          _field('uan_number', 'UAN Number'),
          _field('pf_number', 'PF Number'),
          _field('employee_pf_contribution', 'Employee PF Contribution',
              keyboardType: TextInputType.number),
          _field('employer_pf_contribution', 'Employer PF Contribution',
              keyboardType: TextInputType.number),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ESIC Applicable'),
            value: _esicApplicable,
            onChanged: (value) => setState(() => _esicApplicable = value),
          ),
          _field('esic_number', 'ESIC Number'),
          _field('employee_esic_contribution', 'Employee ESIC Contribution',
              keyboardType: TextInputType.number),
          _field('employer_esic_contribution', 'Employer ESIC Contribution',
              keyboardType: TextInputType.number),
        ],
      );
    }

    return _ProfileList(
      children: [
        _ProfileSection(
          title: 'Provident Fund',
          children: [
            _ProfileRow(label: 'PF Applicable', value: _yesNo('pf_applicable')),
            _ProfileRow(label: 'UAN Number', value: _text(['uan_number'])),
            _ProfileRow(label: 'PF Number', value: _text(['pf_number'])),
            _ProfileRow(
                label: 'Employee PF',
                value: _money(['employee_pf_contribution'])),
            _ProfileRow(
                label: 'Employer PF',
                value: _money(['employer_pf_contribution'])),
          ],
        ),
        _ProfileSection(
          title: 'ESIC',
          children: [
            _ProfileRow(
                label: 'ESIC Applicable', value: _yesNo('esic_applicable')),
            _ProfileRow(label: 'ESIC Number', value: _text(['esic_number'])),
            _ProfileRow(
                label: 'Employee ESIC',
                value: _money(['employee_esic_contribution'])),
            _ProfileRow(
                label: 'Employer ESIC',
                value: _money(['employer_esic_contribution'])),
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryBank() {
    if (_editMode) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Salary Information',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field('basic_salary', 'Basic Salary',
              keyboardType: TextInputType.number),
          _field('hra', 'HRA', keyboardType: TextInputType.number),
          _field('conveyance_allowance', 'Conveyance Allowance',
              keyboardType: TextInputType.number),
          _field('other_allowance', 'Other Allowance',
              keyboardType: TextInputType.number),
          _field('gross_salary', 'Gross Salary',
              keyboardType: TextInputType.number),
          _field('ctc', 'CTC', keyboardType: TextInputType.number),
          const Divider(height: 28),
          const Text('Bank Information',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field('bank_name', 'Bank Name'),
          _field('bank_account_holder_name', 'Account Holder'),
          _field('bank_account_number', 'Account Number'),
          _field('bank_ifsc', 'IFSC'),
          _field('bank_branch', 'Branch'),
          const Divider(height: 28),
          const Text('Identity',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field('pan_number', 'PAN Number'),
          _field('aadhaar_number', 'Aadhaar Number'),
        ],
      );
    }

    return _ProfileList(
      children: [
        _ProfileSection(
          title: 'Salary Information',
          children: [
            _ProfileRow(label: 'Basic Salary', value: _money(['basic_salary'])),
            _ProfileRow(label: 'HRA', value: _money(['hra'])),
            _ProfileRow(
                label: 'Conveyance', value: _money(['conveyance_allowance'])),
            _ProfileRow(
                label: 'Other Allowance', value: _money(['other_allowance'])),
            _ProfileRow(label: 'Gross Salary', value: _money(['gross_salary'])),
            _ProfileRow(label: 'CTC', value: _money(['ctc'])),
          ],
        ),
        _ProfileSection(
          title: 'Bank Information',
          children: [
            _ProfileRow(label: 'Bank Name', value: _text(['bank_name'])),
            _ProfileRow(
                label: 'Account Holder',
                value: _text(['bank_account_holder_name'])),
            _ProfileRow(
                label: 'Account Number', value: _text(['bank_account_number'])),
            _ProfileRow(label: 'IFSC', value: _text(['bank_ifsc'])),
            _ProfileRow(label: 'Branch', value: _text(['bank_branch'])),
          ],
        ),
        _ProfileSection(
          title: 'Identity',
          children: [
            _ProfileRow(label: 'PAN Number', value: _text(['pan_number'])),
            _ProfileRow(
                label: 'Aadhaar Number', value: _text(['aadhaar_number'])),
          ],
        ),
      ],
    );
  }

  Widget _buildDocuments() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.folder_copy_outlined, size: 52),
                const SizedBox(height: 12),
                const Text(
                  'Employee Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Employee photo, Aadhaar, PAN, bank proof, appointment letter and certificates will appear here.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Add Document'),
                ),
                const SizedBox(height: 8),
                Text(
                  _editMode
                      ? 'Complete the employee details in the other tabs and press Save once. Document upload will be connected separately.'
                      : 'Document upload will be connected in the next step.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileList extends StatelessWidget {
  final List<Widget> children;

  const _ProfileList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
