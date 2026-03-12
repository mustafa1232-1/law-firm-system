import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _cases = const [];
  List<Map<String, dynamic>> _hearings = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final options = Options(headers: authHeaders(ref));

      final responses = await Future.wait([
        dio.get(
          '/cases',
          queryParameters: const {'limit': 300},
          options: options,
        ),
        dio.get(
          '/hearings',
          queryParameters: const {'limit': 300},
          options: options,
        ),
        dio.get(
          '/tasks',
          queryParameters: const {'limit': 300},
          options: options,
        ),
        dio.get(
          '/billing/payments',
          queryParameters: const {'limit': 300},
          options: options,
        ),
        dio.get(
          '/notifications',
          queryParameters: const {'limit': 50},
          options: options,
        ),
      ]);

      final casesData = (responses[0].data as Map).cast<String, dynamic>();
      final hearingsData = (responses[1].data as Map).cast<String, dynamic>();
      final tasksData = (responses[2].data as Map).cast<String, dynamic>();
      final paymentsData = (responses[3].data as Map).cast<String, dynamic>();

      if (!mounted) {
        return;
      }

      setState(() {
        _cases = ((casesData['items'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
        _hearings = ((hearingsData['items'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
        _tasks = ((tasksData['items'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
        _payments = ((paymentsData['items'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
        _notifications = ((responses[4].data as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeCases = _cases.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status != 'closed' && status != 'archived';
    }).toList();

    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final hearingsThisWeek = _hearings.where((item) {
      final date = DateTime.tryParse((item['hearingDate'] ?? '').toString());
      if (date == null) {
        return false;
      }
      return date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          date.isBefore(weekEnd);
    }).toList();

    final overdueTasks = _tasks.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      if (status == 'done' || status == 'cancelled') {
        return false;
      }
      final due = DateTime.tryParse((item['dueDate'] ?? '').toString());
      if (due == null) {
        return false;
      }
      return due.isBefore(now);
    }).toList();

    final billingCollected = _payments.fold<double>(0, (sum, payment) {
      final amount = payment['amount'];
      if (amount is num) {
        return sum + amount.toDouble();
      }
      return sum;
    });

    final upcomingHearings =
        _hearings.where((item) {
          final date = DateTime.tryParse(
            (item['hearingDate'] ?? '').toString(),
          );
          return date != null &&
              date.isAfter(now.subtract(const Duration(days: 1)));
        }).toList()..sort((a, b) {
          final aDate = DateTime.tryParse((a['hearingDate'] ?? '').toString());
          final bDate = DateTime.tryParse((b['hearingDate'] ?? '').toString());
          return (aDate ?? now).compareTo(bDate ?? now);
        });

    final alerts = <_AlertEntry>[
      ..._notifications.take(5).map((item) {
        final level = (item['level'] ?? '').toString().toLowerCase();
        return _AlertEntry(
          title: (item['title'] ?? 'تنبيه').toString(),
          subtitle: (item['message'] ?? '').toString(),
          color: level == 'high'
              ? LexiqColors.crimsonAlert
              : level == 'medium'
              ? LexiqColors.brassGold
              : LexiqColors.emeraldJustice,
        );
      }),
      ...overdueTasks
          .take(3)
          .map(
            (task) => _AlertEntry(
              title: 'مهمة متأخرة: ${(task['title'] ?? '-').toString()}',
              subtitle: 'تاريخ الاستحقاق: ${_dateOnly(task['dueDate'])}',
              color: LexiqColors.crimsonAlert,
            ),
          ),
      ...activeCases
          .where(
            (item) =>
                (item['riskScore'] is num) && (item['riskScore'] as num) >= 70,
          )
          .take(3)
          .map(
            (caseItem) => _AlertEntry(
              title:
                  'مخاطر مرتفعة: ${(caseItem['caseNumber'] ?? '-').toString()}',
              subtitle: (caseItem['title'] ?? '').toString(),
              color: LexiqColors.brassGold,
            ),
          ),
    ];

    final cards = <Widget>[
      MetricCard(
        title: 'Active Cases',
        value: activeCases.length.toString(),
        delta: '${activeCases.length} ملفات قيد العمل',
      ),
      MetricCard(
        title: 'Hearings This Week',
        value: hearingsThisWeek.length.toString(),
        delta: '${hearingsThisWeek.length} جلسة هذا الأسبوع',
        positive: true,
      ),
      MetricCard(
        title: 'Overdue Tasks',
        value: overdueTasks.length.toString(),
        delta: overdueTasks.isEmpty
            ? 'لا توجد مهام متأخرة'
            : 'تحتاج متابعة عاجلة',
        positive: overdueTasks.isEmpty,
      ),
      MetricCard(
        title: 'Billing Collected',
        value: 'IQD ${billingCollected.toStringAsFixed(0)}',
        delta: '${_payments.length} دفعة مسجلة',
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1320
        ? 4
        : width >= 980
        ? 2
        : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Executive Legal Dashboard',
            subtitle:
                'Firm operations, litigation activity, and intelligence insights',
            trailing: IconButton(
              onPressed: _loading ? null : _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 2.3 : 1.45,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              return cards[index]
                  .animate(delay: (index * 80).ms)
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.12);
            },
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Hearing Timeline'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (upcomingHearings.isEmpty)
                          const Text('لا توجد جلسات قادمة.')
                        else
                          ...upcomingHearings.take(8).map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: LexiqColors.imperialBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (((item['caseId'] as Map?)?['title']) ??
                                              'جلسة قضائية')
                                          .toString(),
                                    ),
                                  ),
                                  Text(
                                    _timeOnly(item['hearingDate']),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Legal Alerts'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (alerts.isEmpty)
                          const Text('لا توجد تنبيهات حالياً.')
                        else
                          ...alerts
                              .take(8)
                              .map(
                                (alert) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _alertTile(
                                    context,
                                    alert.title,
                                    alert.subtitle,
                                    alert.color,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _alertTile(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeOnly(dynamic value) {
    final raw = (value ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return '-';
    }

    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _dateOnly(dynamic value) {
    final raw = (value ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return '-';
    }

    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}

class _AlertEntry {
  const _AlertEntry({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;
}
