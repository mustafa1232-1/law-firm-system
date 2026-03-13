import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _firmNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _registrationNoController = TextEditingController();
  final _governorateController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _logoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _focusController = TextEditingController();
  final _yearController = TextEditingController();
  final _employeeCountController = TextEditingController(text: '1');
  final _timezoneController = TextEditingController(text: 'Asia/Baghdad');
  final _currencyController = TextEditingController(text: 'IQD');

  bool _loadingFirm = false;
  bool _savingFirm = false;
  bool _bootstrappingLegalData = false;
  String? _error;
  String? _firmId;
  String _firmLocale = 'ar-IQ';
  String? _workforceStrength;
  int _activeUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadFirmContext();
  }

  @override
  void dispose() {
    _firmNameController.dispose();
    _legalNameController.dispose();
    _registrationNoController.dispose();
    _governorateController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _logoController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _focusController.dispose();
    _yearController.dispose();
    _employeeCountController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadFirmContext() async {
    setState(() {
      _loadingFirm = true;
      _error = null;
    });

    try {
      final session = ref.read(authControllerProvider).session;
      final firmId = session?.user.firmId;
      if (firmId == null || firmId.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _firmId = null;
          _loadingFirm = false;
        });
        return;
      }

      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/firms/$firmId',
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final settings =
          (data['settings'] as Map?)?.cast<String, dynamic>() ?? const {};

      if (!mounted) {
        return;
      }

      setState(() {
        _firmId = firmId;
        _firmNameController.text = (data['name'] ?? '').toString();
        _legalNameController.text = (data['legalName'] ?? '').toString();
        _registrationNoController.text = (data['registrationNo'] ?? '')
            .toString();
        _governorateController.text = (data['governorate'] ?? '').toString();
        _addressController.text = (data['address'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _websiteController.text = (data['website'] ?? '').toString();
        _logoController.text = (data['logoUrl'] ?? '').toString();
        _descriptionController.text = (data['description'] ?? '').toString();
        _categoryController.text = (data['category'] ?? '').toString();
        _focusController.text = (data['practiceFocus'] ?? '').toString();
        _yearController.text = (data['establishedYear'] ?? '').toString();
        _employeeCountController.text = ((data['employeeCount'] ?? 1) as num)
            .toInt()
            .toString();
        _firmLocale = (settings['locale'] ?? 'ar-IQ').toString();
        _timezoneController.text = (settings['timezone'] ?? 'Asia/Baghdad')
            .toString();
        _currencyController.text = (settings['currency'] ?? 'IQD').toString();
        _workforceStrength = (data['workforceStrength'] ?? '').toString();
        _activeUsers = ((data['activeUsers'] ?? 0) as num).toInt();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loadingFirm = false);
      }
    }
  }

  Future<void> _saveFirm() async {
    setState(() => _savingFirm = true);
    try {
      if (_firmNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('اسم الشركة مطلوب.')));
        return;
      }

      final dio = ref.read(dioProvider);
      final payload = {
        'name': _firmNameController.text.trim(),
        'legalName': _toNullable(_legalNameController.text),
        'registrationNo': _toNullable(_registrationNoController.text),
        'governorate': _toNullable(_governorateController.text),
        'address': _toNullable(_addressController.text),
        'phone': _toNullable(_phoneController.text),
        'email': _toNullable(_emailController.text),
        'website': _toNullable(_websiteController.text),
        'logoUrl': _toNullable(_logoController.text),
        'description': _toNullable(_descriptionController.text),
        'category': _toNullable(_categoryController.text),
        'practiceFocus': _toNullable(_focusController.text),
        'establishedYear': int.tryParse(_yearController.text.trim()),
        'employeeCount':
            int.tryParse(_employeeCountController.text.trim()) ?? 1,
      };

      final options = Options(headers: authHeaders(ref));
      String? effectiveFirmId = _firmId;
      if (_firmId == null || _firmId!.isEmpty) {
        final createResponse = await dio.post(
          '/firms/my-firm',
          data: payload,
          options: options,
        );
        final createdData = (createResponse.data as Map)
            .cast<String, dynamic>();
        final userData = (createdData['user'] as Map?)?.cast<String, dynamic>();
        final createdFirmId =
            ((createdData['firm'] as Map?)?['_id'] ??
                    (createdData['firm'] as Map?)?['id'])
                ?.toString();
        effectiveFirmId = createdFirmId;

        if (createdFirmId != null && createdFirmId.isNotEmpty) {
          await ref
              .read(authControllerProvider.notifier)
              .updateSessionFirm(
                firmId: createdFirmId,
                roles: ((userData?['roles'] as List?) ?? const [])
                    .map((entry) => entry.toString())
                    .toList(),
              );
        }
      } else {
        await dio.patch('/firms/$_firmId', data: payload, options: options);
      }

      if (effectiveFirmId != null && effectiveFirmId.isNotEmpty) {
        await dio.patch(
          '/firms/$effectiveFirmId/settings',
          data: {
            'locale': _firmLocale,
            'timezone': _timezoneController.text.trim(),
            'currency': _currencyController.text.trim(),
          },
          options: options,
        );
      }

      await _loadFirmContext();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الشركة بنجاح.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _savingFirm = false);
      }
    }
  }

  Future<void> _bootstrapLegalData() async {
    setState(() => _bootstrappingLegalData = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/admin/bootstrap-legal-data',
        data: const {'replace': true},
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final constitution = ((data['constitutionArticles'] ?? 0) as num).toInt();
      final laws = ((data['lawDocuments'] ?? 0) as num).toInt();
      final decisions = ((data['judicialDecisions'] ?? 0) as num).toInt();
      final courts = ((data['courts'] ?? 0) as num).toInt();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إعادة تهيئة المراجع القانونية: دستور $constitution، قوانين $laws، قرارات $decisions، محاكم $courts',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _bootstrappingLegalData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final locale = ref.watch(localeProvider);
    final hasFirm = _firmId != null && _firmId!.isNotEmpty;
    final roles =
        ref.watch(authControllerProvider).session?.user.roles ??
        const <String>[];
    final canBootstrapLegalData = roles.contains('SUPER_ADMIN');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Settings',
            subtitle:
                'Localization, export templates, storage, and AI settings',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingFirm ? null : _loadFirmContext,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحديث'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _savingFirm ? null : _saveFirm,
                  icon: _savingFirm
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('حفظ'),
                ),
                if (canBootstrapLegalData) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _bootstrappingLegalData
                        ? null
                        : _bootstrapLegalData,
                    icon: _bootstrappingLegalData
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.library_add_check_rounded),
                    label: const Text('تهيئة المراجع القانونية'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: LexiqColors.crimsonAlert),
              ),
            ),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Interface Language'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      selected: locale.languageCode == 'ar',
                      label: Text(context.tr('Arabic')),
                      onSelected: (_) =>
                          ref.read(localeProvider.notifier).state =
                              const Locale('ar', 'IQ'),
                    ),
                    ChoiceChip(
                      selected: locale.languageCode == 'en',
                      label: Text(context.tr('English')),
                      onSelected: (_) =>
                          ref.read(localeProvider.notifier).state =
                              const Locale('en'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFirm ? 'بيانات شركة المحاماة' : 'إنشاء شركة المحاماة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_loadingFirm)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (hasFirm) ...[
                    Text('قوة الشركة: ${_workforceStrength ?? '-'}'),
                    Text('الموظفون النشطون: $_activeUsers'),
                    const SizedBox(height: 10),
                  ],
                  _field(_firmNameController, 'اسم الشركة *'),
                  _field(_legalNameController, 'الاسم القانوني'),
                  _field(_registrationNoController, 'رقم التسجيل'),
                  _field(_categoryController, 'الفئة'),
                  _field(_focusController, 'مجال التخصص'),
                  _field(_governorateController, 'المحافظة'),
                  _field(_addressController, 'العنوان'),
                  _field(_phoneController, 'الهاتف'),
                  _field(_emailController, 'البريد'),
                  _field(_websiteController, 'الموقع الإلكتروني'),
                  _field(_logoController, 'رابط الشعار'),
                  _field(
                    _yearController,
                    'سنة التأسيس',
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    _employeeCountController,
                    'عدد الموظفين',
                    keyboardType: TextInputType.number,
                  ),
                  _field(_descriptionController, 'وصف الشركة', maxLines: 3),
                  const SizedBox(height: 10),
                  if (isCompact) ...[
                    _field(_timezoneController, 'المنطقة الزمنية'),
                    _field(_currencyController, 'العملة'),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _field(_timezoneController, 'المنطقة الزمنية'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_currencyController, 'العملة')),
                      ],
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _firmLocale,
                    items: const [
                      DropdownMenuItem(value: 'ar-IQ', child: Text('ar-IQ')),
                      DropdownMenuItem(value: 'en', child: Text('en')),
                    ],
                    onChanged: (value) =>
                        setState(() => _firmLocale = value ?? 'ar-IQ'),
                    decoration: const InputDecoration(labelText: 'لغة الشركة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const GlassPanel(child: _SettingsHighlights()),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String? _toNullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SettingsHighlights extends StatelessWidget {
  const _SettingsHighlights();

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'Arabic-first RTL configuration',
      'PDF and Word export defaults',
      'Provider and integration setup',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Core Capabilities'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr(item))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
