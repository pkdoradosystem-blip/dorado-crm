
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../models/form_schema_model.dart';
import '../../services/services.dart';

class DynamicFormPage extends StatefulWidget {
  final String formCode;
  final String title;

  const DynamicFormPage({
    super.key,
    required this.formCode,
    required this.title,
  });

  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final FormService _formService;

  FormSchema? _schema;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _executiveManagers = {};

  // Forces dropdown/form widgets to rebuild after successful save.
  int _formVersion = 0;

  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;

  String? _error;

  final ImagePicker _imagePicker = ImagePicker();

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    _formService = FormService(ApiClient());

    _loadExecutiveManagers();
    _loadForm();
  }

  Future<void> _loadExecutiveManagers() async {
    try {
      final result = await ApiClient().get(
        '/api/v1/masters/executives',
      );

      if (result is List) {
        _executiveManagers.clear();

        for (final item in result) {
          if (item is Map) {
            final name =
                item['value']?.toString().trim() ?? '';

            final manager =
                item['reporting_manager']?.toString().trim() ?? '';

            if (name.isNotEmpty) {
              _executiveManagers[name] = manager;
            }
          }
        }
      }
    } catch (_) {
      // Backend can still assign Marketing Head.
    }
  }

  String _today() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadForm() async {
    try {
      final schema = await _formService.loadForm(
        widget.formCode,
      );

      // Dispose old controllers if form is loaded again.
      for (final controller in _controllers.values) {
        controller.dispose();
      }

      _controllers.clear();

      for (final field in schema.fields) {
        _controllers[field.key] = TextEditingController();
      }

      if (widget.formCode == 'lead_entry') {
        _controllers['lead_date']?.text = _today();
      }

      if (!mounted) return;

      setState(() {
        _schema = schema;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickImage(
    String fieldKey,
    ImageSource source,
  ) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        _controllers[fieldKey]?.text = image.path;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImageSource(
    String fieldKey,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _pickImage(
                      fieldKey,
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _pickImage(
                      fieldKey,
                      ImageSource.gallery,
                    );
                  },
                ),
                if ((_controllers[fieldKey]
                            ?.text
                            .trim()
                            .isNotEmpty ??
                        false))
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Remove Image',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      setState(() {
                        _controllers[fieldKey]?.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation(
    String fieldKey,
  ) async {
    if (_gettingLocation) return;

    setState(() {
      _gettingLocation = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please turn on Location/GPS.',
            ),
          ),
        );

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission was denied.',
            ),
          ),
        );

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permission is permanently denied. '
              'Please enable it from app settings.',
            ),
            action: SnackBarAction(
              label: 'SETTINGS',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );

        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // At this stage we store coordinates in the visible
      // location field. Address conversion can be added later.
      _controllers[fieldKey]?.text =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';

      // If schema contains latitude/longitude fields,
      // populate them automatically as well.
      _controllers['latitude']?.text =
          position.latitude.toString();

      _controllers['longitude']?.text =
          position.longitude.toString();

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get current location: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  Future<void> _saveForm() async {
    if (_schema == null) return;

    final currentState = _formKey.currentState;

    if (currentState == null ||
        !currentState.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> values = {};

      for (final field in _schema!.fields) {
        values[field.key] =
            _controllers[field.key]?.text.trim() ?? '';
      }

      if (widget.formCode == 'lead_entry') {
        values['lead_status'] = 'New Lead';

        values['call_done'] = false;
        values['appointment_fixed'] = false;
        values['site_visit_done'] = false;
        values['survey_done'] = false;
        values['quotation_given'] = false;
        values['negotiation_done'] = false;
        values['order_finalized'] = false;

        if (_latitude != null) {
          values['latitude'] = _latitude;
        }

        if (_longitude != null) {
          values['longitude'] = _longitude;
        }
      }

      await _formService.submitForm(
        _schema!.submitEndpoint,
        values,
      );

      if (!mounted) return;

      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lead saved successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: $e',
          ),
          backgroundColor: Colors.red,
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

  void _resetForm() {
    // Reset FormField internal states first.
    _formKey.currentState?.reset();

    for (final controller in _controllers.values) {
      controller.clear();
    }

    _latitude = null;
    _longitude = null;

    if (widget.formCode == 'lead_entry') {
      _controllers['lead_date']?.text = _today();
    }

    // Recreates dropdown widgets so old selected values
    // do not remain visible after save.
    setState(() {
      _formVersion++;
    });
  }

  Widget _buildField(
    FormFieldSchema field,
  ) {
    final controller = _controllers[field.key]!;

    InputDecoration decoration({
      String? hintText,
    }) {
      return InputDecoration(
        labelText: field.label,
        hintText:
            hintText ?? 'Enter ${field.label}',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFDCE3EA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFFDCE3EA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF0B5C9E),
            width: 1.5,
          ),
        ),
      );
    }

    String? validateValue(String? value) {
      if (field.required &&
          (value == null ||
              value.trim().isEmpty)) {
        return '${field.label} is required';
      }

      if (field.type == 'phone' &&
          value != null &&
          value.trim().isNotEmpty &&
          value.trim().length < 10) {
        return 'Enter a valid mobile number';
      }

      return null;
    }

    if (field.type == 'dropdown') {
      final options = field.options;

      final currentValue =
          controller.text.trim();

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          key: ValueKey(
            '${field.key}-$_formVersion',
          ),
          initialValue:
              currentValue.isEmpty ||
                      !options.contains(currentValue)
                  ? null
                  : currentValue,
          isExpanded: true,
          decoration: decoration(
            hintText: 'Select ${field.label}',
          ),
          items: options
              .map(
                (option) =>
                    DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: options.isEmpty
              ? null
              : (value) {
                  controller.text =
                      value ?? '';

                  // Auto assign Marketing Head when
                  // executive/lead collector is selected.
                  if (field.key ==
                          'lead_collector_name' ||
                      field.key == 'executive') {
                    final manager =
                        _executiveManagers[
                                value ?? ''] ??
                            '';

                    final marketingController =
                        _controllers[
                            'marketing_head'];

                    if (marketingController != null) {
                      marketingController.text =
                          manager;
                    }

                    setState(() {});
                  }
                },
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'auto') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: decoration(
            hintText:
                'Auto assigned from Executive',
          ).copyWith(
            suffixIcon: const Icon(
              Icons.auto_awesome_outlined,
            ),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'map') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          decoration: decoration(
            hintText:
                'Enter location or use GPS',
          ).copyWith(
            prefixIcon: const Icon(
              Icons.location_on_outlined,
            ),
            suffixIcon: _gettingLocation
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip:
                        'Use Current Location',
                    icon: const Icon(
                      Icons.my_location,
                    ),
                    onPressed: () =>
                        _getCurrentLocation(
                      field.key,
                    ),
                  ),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'image') {
      final hasImage =
          controller.text.trim().isNotEmpty;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          key: ValueKey(
            '${field.key}-image-$_formVersion',
          ),
          controller: controller,
          readOnly: true,
          onTap: () =>
              _showImageSource(field.key),
          decoration: decoration(
            hintText: 'Camera / Gallery',
          ).copyWith(
            prefixIcon: Icon(
              hasImage
                  ? Icons.check_circle_outline
                  : Icons.image_outlined,
              color: hasImage
                  ? Colors.green
                  : null,
            ),
            suffixIcon: IconButton(
              tooltip: 'Camera / Gallery',
              icon: const Icon(
                Icons.add_a_photo_outlined,
              ),
              onPressed: () =>
                  _showImageSource(field.key),
            ),
          ),
          validator: validateValue,
        ),
      );
    }

    if (field.type == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: decoration(
            hintText: 'Select ${field.label}',
          ).copyWith(
            suffixIcon: const Icon(
              Icons.calendar_month_outlined,
            ),
          ),
          validator: validateValue,
          onTap: () async {
            final now = DateTime.now();

            DateTime initialDate = now;

            final current = DateTime.tryParse(
              controller.text.trim(),
            );

            if (current != null) {
              initialDate = current;
            }

            final selected =
                await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (selected == null) return;

            controller.text =
                '${selected.year.toString().padLeft(4, '0')}-'
                '${selected.month.toString().padLeft(2, '0')}-'
                '${selected.day.toString().padLeft(2, '0')}';

            if (mounted) {
              setState(() {});
            }
          },
        ),
      );
    }

    int maxLines = 1;

    if (field.type == 'textarea') {
      maxLines = 4;
    }

    TextInputType keyboardType =
        TextInputType.text;

    if (field.type == 'phone') {
      keyboardType = TextInputType.phone;
    } else if (field.type == 'number') {
      keyboardType =
          const TextInputType.numberWithOptions(
        decimal: true,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: decoration(),
        validator: validateValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0B5C9E),
        foregroundColor: Colors.white,
        title: Text(widget.title),
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
                'Unable to load form',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_schema == null) {
      return const Center(
        child: Text('Form not available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 980),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          const Color(0xFFE3E9EF),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _schema!.title,
                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              Color(0xFF17212B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      LayoutBuilder(
                        builder:
                            (context, constraints) {
                          final fields =
                              _schema!.fields;

                          final useTwoColumns =
                              constraints.maxWidth >=
                                  620;

                          if (!useTwoColumns) {
                            return Column(
                              children: fields
                                  .map(_buildField)
                                  .toList(),
                            );
                          }

                          final rows = <Widget>[];

                          for (int i = 0;
                              i < fields.length;
                              i += 2) {
                            final left =
                                fields[i];

                            final hasRight =
                                i + 1 <
                                    fields.length;

                            final right = hasRight
                                ? fields[i + 1]
                                : null;

                            if (left.type ==
                                'auto') {
                              rows.add(
                                _buildField(left),
                              );

                              if (right != null) {
                                rows.add(
                                  _buildField(
                                    right,
                                  ),
                                );
                              }

                              continue;
                            }

                            rows.add(
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Expanded(
                                    child:
                                        _buildField(
                                      left,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 14,
                                  ),
                                  Expanded(
                                    child: right ==
                                            null
                                        ? const SizedBox
                                            .shrink()
                                        : _buildField(
                                            right,
                                          ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: rows,
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      SizedBox(
                        height: 48,
                        child:
                            ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : _saveForm,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF0B5C9E,
                            ),
                            foregroundColor:
                                Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(9),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_outlined,
                                ),
                          label: Text(
                            _saving
                                ? 'Saving...'
                                : 'Save Lead',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller
        in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}