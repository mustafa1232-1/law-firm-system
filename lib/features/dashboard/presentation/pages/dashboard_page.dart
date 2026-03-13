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
  Map<String, dynamic>? _summary;

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
      final response = await dio.get(
        '/admin/dashboard-summary',
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }
      setState(() => _summary = (response.data as Map).cast<String, dynamic>());
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        try {
          final fallback = await _loadLegacyDashboardSummary();
          if (!mounted) {
            return;
          }
          setState(() => _summary = fallback);
          return;
        } catch (_) {
          // Falls through.
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
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

  Future<Map<String, dynamic>> _loadLegacyDashboardSummary() async {
    final dio = ref.read(dioProvider);
    final options = Options(headers: authHeaders(ref));

    final responses = await Future.wait([
      dio.get(
        '/cases',
        queryParameters: const {'limit': 250},
        options: options,
      ),
      dio.get(
        '/hearings',
        queryParameters: const {'limit': 250},
        options: options,
      ),
      dio.get(
        '/tasks',
        queryParameters: const {'limit': 250},
        options: options,
      ),
      dio.get(
        '/billing/payments',
        queryParameters: const {'limit': 250},
        options: options,
      ),
      dio.get(
        '/notifications',
        queryParameters: const {'limit': 250},
        options: options,
      ),
    ]);

    final cases = _extractItems(responses[0].data);
    final hearings = _extractItems(responses[1].data);
    final tasks = _extractItems(responses[2].data);
    final payments = _extractItems(responses[3].data);
    final notifications = responses[4].data is List
        ? ((responses[4].data as List)
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList())
        : _extractItems(responses[4].data);

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: (now.weekday + 6) % 7));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final activeCases = cases.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status != 'closed' && status != 'archived';
    }).length;

    final hearingsThisWeek = hearings.where((item) {
      final date = DateTime.tryParse((item['hearingDate'] ?? '').toString());
      if (date == null) {
        return false;
      }
      return !date.isBefore(weekStart) && date.isBefore(weekEnd);
    }).length;

    final overdueTasks = tasks.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      final due = DateTime.tryParse((item['dueDate'] ?? '').toString());
      if (status == 'done' || status == 'cancelled' || due == null) {
        return false;
      }
      return due.isBefore(now);
    }).length;

    final billingCollected = payments.fold<double>(0, (sum, item) {
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      return sum + amount;
    });

    final caseTypeMap = <String, int>{};
    for (final item in cases) {
      final type = (item['caseType'] ?? 'other').toString();
      caseTypeMap[type] = (caseTypeMap[type] ?? 0) + 1;
    }
    final caseTypeDistribution =
        caseTypeMap.entries
            .map((entry) => {'caseType': entry.key, 'count': entry.value})
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final upcomingHearings = [...hearings]
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['hearingDate'] ?? '').toString());
        final bDate = DateTime.tryParse((b['hearingDate'] ?? '').toString());
        return (aDate ?? DateTime(now.year + 10)).compareTo(
          bDate ?? DateTime(now.year + 10),
        );
      });

    final urgentTasks =
        tasks.where((item) {
          final status = (item['status'] ?? '').toString().toLowerCase();
          final priority = (item['priority'] ?? '').toString().toLowerCase();
          if (status == 'done' || status == 'cancelled') {
            return false;
          }
          return priority == 'high' || priority == 'urgent';
        }).toList()..sort((a, b) {
          final aDate = DateTime.tryParse((a['dueDate'] ?? '').toString());
          final bDate = DateTime.tryParse((b['dueDate'] ?? '').toString());
          return (aDate ?? DateTime(now.year + 10)).compareTo(
            bDate ?? DateTime(now.year + 10),
          );
        });

    final alerts = notifications
        .where((item) => item['isRead'] != true)
        .map(
          (item) => {
            'type': 'notification',
            'title': (item['title'] ?? 'alert').toString(),
            'subtitle': (item['message'] ?? '').toString(),
            'level': (item['level'] ?? 'info').toString(),
          },
        )
        .toList();

    final openCases = cases.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status != 'closed' && status != 'archived';
    }).toList();
    final closedCases = cases.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status == 'closed' || status == 'archived';
    }).toList();

    num outstandingOf(Map<String, dynamic> item) =>
        (item['outstandingAmount'] as num?) ?? 0;
    final openWithDebt = openCases
        .where((item) => outstandingOf(item) > 0)
        .length;
    final openFullyPaid = openCases
        .where((item) => outstandingOf(item) <= 0)
        .length;
    final closedWithDebt = closedCases
        .where((item) => outstandingOf(item) > 0)
        .length;
    final closedFullyPaid = closedCases
        .where((item) => outstandingOf(item) <= 0)
        .length;
    final wonCases = cases
        .where(
          (item) => (item['outcome'] ?? '').toString().toLowerCase() == 'won',
        )
        .length;
    final lostCases = cases
        .where(
          (item) => (item['outcome'] ?? '').toString().toLowerCase() == 'lost',
        )
        .length;
    final totalOutstanding = cases.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['outstandingAmount'] as num?)?.toDouble() ?? 0),
    );
    final totalContractValue = cases.fold<double>(
      0,
      (sum, item) => sum + ((item['contractAmount'] as num?)?.toDouble() ?? 0),
    );
    final totalPaidAmount = cases.fold<double>(
      0,
      (sum, item) => sum + ((item['paidAmount'] as num?)?.toDouble() ?? 0),
    );
    final resolvedCases = wonCases + lostCases;
    final winRatePercent = resolvedCases > 0
        ? (wonCases / resolvedCases) * 100
        : 0;
    final collectionRatePercent = totalContractValue > 0
        ? (totalPaidAmount / totalContractValue) * 100
        : 0;

    return {
      'kpis': {
        'totalCases': cases.length,
        'activeCases': activeCases,
        'hearingsThisWeek': hearingsThisWeek,
        'overdueTasks': overdueTasks,
        'billingCollected': billingCollected,
        'paymentsCount': payments.length,
        'resolvedCases': resolvedCases,
      },
      'financeCaseIndicators': {
        'openCasesCount': openCases.length,
        'closedCasesCount': closedCases.length,
        'openWithDebt': openWithDebt,
        'openFullyPaid': openFullyPaid,
        'closedWithDebt': closedWithDebt,
        'closedFullyPaid': closedFullyPaid,
        'wonCases': wonCases,
        'lostCases': lostCases,
        'totalOutstanding': totalOutstanding,
        'totalContractValue': totalContractValue,
        'totalPaidAmount': totalPaidAmount,
        'collectionRatePercent': collectionRatePercent,
        'winRatePercent': winRatePercent,
      },
      'caseTypeDistribution': caseTypeDistribution.take(10).toList(),
      'lawyerAgenda': upcomingHearings
          .where(
            (hearing) =>
                DateTime.tryParse((hearing['hearingDate'] ?? '').toString()) !=
                null,
          )
          .take(12)
          .map((hearing) {
            final hearingDate = DateTime.parse(
              (hearing['hearingDate'] ?? '').toString(),
            );
            return {
              'hearingDate': hearingDate.toIso8601String(),
              'case': hearing['caseId'],
              'court': hearing['court'],
              'courtGovernorate': hearing['courtGovernorate'],
              'courtCity': hearing['courtCity'],
              'courtDistrict': hearing['courtDistrict'],
              'courtArea': hearing['courtArea'],
              'courtLocationDescription': hearing['courtLocationDescription'],
              'room': hearing['room'],
              'judge': hearing['judge'],
              'nextReminder': _buildNextReminder(hearingDate, now),
            };
          })
          .toList(),
      'upcomingHearings': upcomingHearings.take(8).toList(),
      'urgentTasks': urgentTasks.take(8).toList(),
      'alerts': alerts.take(10).toList(),
    };
  }

  static Map<String, dynamic>? _buildNextReminder(
    DateTime hearingDate,
    DateTime now,
  ) {
    final checkpoints = <Map<String, dynamic>>[
      {
        'label': '1 day before',
        'remindAt': hearingDate
            .subtract(const Duration(hours: 24))
            .toIso8601String(),
      },
      {
        'label': '6 hours before',
        'remindAt': hearingDate
            .subtract(const Duration(hours: 6))
            .toIso8601String(),
      },
      {
        'label': '2 hours before',
        'remindAt': hearingDate
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
      },
      {
        'label': '1 hour before',
        'remindAt': hearingDate
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      },
    ];

    for (final point in checkpoints) {
      final remindAt = DateTime.parse((point['remindAt'] ?? '').toString());
      if (remindAt.isAfter(now)) {
        return point;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractItems(dynamic payload) {
    if (payload is Map && payload['items'] is List) {
      return (payload['items'] as List)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
    }
    if (payload is List) {
      return payload
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1320
        ? 4
        : width >= 980
        ? 2
        : 1;

    final kpis =
        (_summary?['kpis'] as Map?)?.cast<String, dynamic>() ?? const {};
    final financeIndicators =
        (_summary?['financeCaseIndicators'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final upcomingHearings =
        ((_summary?['upcomingHearings'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();
    final lawyerAgenda = ((_summary?['lawyerAgenda'] as List?) ?? const [])
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();
    final urgentTasks = ((_summary?['urgentTasks'] as List?) ?? const [])
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();
    final alerts = ((_summary?['alerts'] as List?) ?? const [])
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();
    final caseTypeDistribution =
        ((_summary?['caseTypeDistribution'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();

    final activeCases = ((kpis['activeCases'] ?? 0) as num).toInt();
    final totalCases = ((kpis['totalCases'] ?? 0) as num).toInt();
    final resolvedCases = ((kpis['resolvedCases'] ?? 0) as num).toInt();
    final hearingsThisWeek = ((kpis['hearingsThisWeek'] ?? 0) as num).toInt();
    final overdueTasks = ((kpis['overdueTasks'] ?? 0) as num).toInt();
    final billingCollected = ((kpis['billingCollected'] ?? 0) as num)
        .toDouble();
    final paymentsCount = ((kpis['paymentsCount'] ?? 0) as num).toInt();
    final winRate = ((financeIndicators['winRatePercent'] ?? 0) as num)
        .toDouble();
    final collectionRate =
        ((financeIndicators['collectionRatePercent'] ?? 0) as num).toDouble();

    final cards = <Widget>[
      MetricCard(
        title: 'Active Cases',
        value: activeCases.toString(),
        delta: isArabic
            ? '$activeCases ملفًا قيد العمل'
            : '$activeCases active files',
      ),
      MetricCard(
        title: 'Hearings This Week',
        value: hearingsThisWeek.toString(),
        delta: isArabic
            ? '$hearingsThisWeek جلسة هذا الأسبوع'
            : '$hearingsThisWeek hearings this week',
        positive: true,
      ),
      MetricCard(
        title: 'Overdue Tasks',
        value: overdueTasks.toString(),
        delta: overdueTasks == 0
            ? _loc(context, 'لا توجد مهام متأخرة', 'No overdue tasks')
            : _loc(context, 'تحتاج متابعة عاجلة', 'Needs urgent follow-up'),
        positive: overdueTasks == 0,
      ),
      MetricCard(
        title: 'Billing Collected',
        value: 'IQD ${billingCollected.toStringAsFixed(0)}',
        delta: isArabic
            ? '$paymentsCount دفعة مسجلة'
            : '$paymentsCount recorded payments',
      ),
      MetricCard(
        title: 'Case Win Rate',
        value: '${winRate.toStringAsFixed(1)}%',
        delta: isArabic
            ? '$resolvedCases قضية محسومة'
            : '$resolvedCases resolved cases',
        positive: winRate >= 50,
      ),
      MetricCard(
        title: 'Collection Rate',
        value: '${collectionRate.toStringAsFixed(1)}%',
        delta: isArabic
            ? '$totalCases إجمالي القضايا'
            : '$totalCases total cases',
        positive: collectionRate >= 70,
      ),
    ];

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
              tooltip: _loc(context, 'تحديث', 'Refresh'),
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
                  _loc(context, 'مفكرة المحامي', 'Lawyer Agenda'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _loc(
                    context,
                    'تنبيهات الجلسات والمرافعات مع المحكمة والموقع ونقطة التذكير القادمة.',
                    'Hearing and pleading reminders with court details and next reminder checkpoint.',
                  ),
                ),
                const SizedBox(height: 10),
                if (lawyerAgenda.isEmpty)
                  Text(
                    _loc(
                      context,
                      'لا توجد جلسات قادمة ضمن مفكرة المحامي.',
                      'No upcoming hearings in the lawyer agenda.',
                    ),
                  )
                else
                  ...lawyerAgenda
                      .take(8)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _agendaTile(item),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loc(
                    context,
                    'مؤشرات القضايا المالية والنتائج',
                    'Financial and Case Outcome Indicators',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _indicatorChip(
                      _loc(context, 'مفتوحة عليها ديون', 'Open with debt'),
                      ((financeIndicators['openWithDebt'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.crimsonAlert,
                    ),
                    _indicatorChip(
                      _loc(
                        context,
                        'مفتوحة مسددة بالكامل',
                        'Open and fully paid',
                      ),
                      ((financeIndicators['openFullyPaid'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.emeraldJustice,
                    ),
                    _indicatorChip(
                      _loc(context, 'مغلقة عليها ديون', 'Closed with debt'),
                      ((financeIndicators['closedWithDebt'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.brassGold,
                    ),
                    _indicatorChip(
                      _loc(
                        context,
                        'مغلقة مسددة بالكامل',
                        'Closed and fully paid',
                      ),
                      ((financeIndicators['closedFullyPaid'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.imperialBlue,
                    ),
                    _indicatorChip(
                      _loc(context, 'قضايا رابحة', 'Won cases'),
                      ((financeIndicators['wonCases'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.emeraldJustice,
                    ),
                    _indicatorChip(
                      _loc(context, 'قضايا خاسرة', 'Lost cases'),
                      ((financeIndicators['lostCases'] ?? 0) as num)
                          .toInt()
                          .toString(),
                      LexiqColors.crimsonAlert,
                    ),
                    _indicatorChip(
                      _loc(context, 'إجمالي المديونية', 'Total outstanding'),
                      'IQD ${((financeIndicators['totalOutstanding'] ?? 0) as num).toStringAsFixed(0)}',
                      LexiqColors.brassGold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Hearing Timeline'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (upcomingHearings.isEmpty)
                              Text(
                                _loc(
                                  context,
                                  'لا توجد جلسات قادمة.',
                                  'No upcoming hearings.',
                                ),
                              )
                            else
                              ...upcomingHearings.map((item) {
                                final caseTitle =
                                    ((item['caseId'] as Map?)?['title'] ??
                                            _loc(context, 'جلسة', 'Hearing'))
                                        .toString();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
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
                                      Expanded(child: Text(caseTitle)),
                                      Text(
                                        _dateTimeShort(item['hearingDate']),
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
                      const SizedBox(height: 12),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loc(context, 'المهام العاجلة', 'Urgent Tasks'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (urgentTasks.isEmpty)
                              Text(
                                _loc(
                                  context,
                                  'لا توجد مهام عاجلة حاليًا.',
                                  'No urgent tasks for now.',
                                ),
                              )
                            else
                              ...urgentTasks.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.priority_high_rounded,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${(item['title'] ?? '-').toString()} - ${_dateOnly(item['dueDate'])}',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Legal Alerts'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (alerts.isEmpty)
                              Text(
                                _loc(
                                  context,
                                  'لا توجد تنبيهات حاليًا.',
                                  'No alerts for now.',
                                ),
                              )
                            else
                              ...alerts.map(
                                (alert) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _alertTile(
                                    context,
                                    _localizeAlertTitle(
                                      context,
                                      (alert['title'] ?? '').toString(),
                                    ),
                                    (alert['subtitle'] ?? '').toString(),
                                    _alertColor(
                                      (alert['level'] ?? 'info').toString(),
                                    ),
                                  ),
                                ),
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
                              _loc(
                                context,
                                'توزيع أنواع القضايا',
                                'Case Type Distribution',
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (caseTypeDistribution.isEmpty)
                              Text(
                                _loc(
                                  context,
                                  'لا توجد بيانات كافية.',
                                  'No sufficient data.',
                                ),
                              )
                            else
                              ...caseTypeDistribution.map((entry) {
                                final caseType = _localizeCaseType(
                                  context,
                                  (entry['caseType'] ?? 'other').toString(),
                                );
                                final count = ((entry['count'] ?? 0) as num)
                                    .toInt();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(caseType)),
                                      Text(count.toString()),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _agendaTile(Map<String, dynamic> item) {
    final hearingDate = _dateTimeShort(item['hearingDate']);
    final caseData =
        (item['case'] as Map?)?.cast<String, dynamic>() ?? const {};
    final caseLabel = [
      (caseData['caseNumber'] ?? '').toString(),
      (caseData['title'] ?? '').toString(),
    ].where((e) => e.trim().isNotEmpty).join(' - ');
    final court = (item['court'] ?? '-').toString();
    final location = [
      (item['courtGovernorate'] ?? '').toString(),
      (item['courtCity'] ?? '').toString(),
      (item['courtDistrict'] ?? '').toString(),
      (item['courtArea'] ?? '').toString(),
    ].where((e) => e.trim().isNotEmpty).join(' - ');
    final locationDetails = (item['courtLocationDescription'] ?? '').toString();
    final nextReminder = (item['nextReminder'] as Map?)
        ?.cast<String, dynamic>();
    final reminderLabel = nextReminder == null
        ? _loc(
            context,
            'تم تجاوز جميع نقاط التنبيه',
            'All reminder checkpoints have passed',
          )
        : '${_localizeReminderLabel(context, (nextReminder['label'] ?? '').toString())} - ${_dateTimeShort(nextReminder['remindAt'])}';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LexiqColors.imperialBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caseLabel.isEmpty ? _loc(context, 'جلسة', 'Hearing') : caseLabel,
          ),
          const SizedBox(height: 4),
          Text(_loc(context, 'الموعد: $hearingDate', 'Date: $hearingDate')),
          Text(_loc(context, 'المحكمة: $court', 'Court: $court')),
          if (location.isNotEmpty)
            Text(
              _loc(
                context,
                'الموقع الإداري: $location',
                'Administrative location: $location',
              ),
            ),
          if (locationDetails.trim().isNotEmpty)
            Text(
              _loc(
                context,
                'وصف المكان: $locationDetails',
                'Location details: $locationDetails',
              ),
            ),
          if ((item['room'] ?? '').toString().isNotEmpty)
            Text(
              _loc(
                context,
                'القاعة: ${(item['room'] ?? '').toString()}',
                'Room: ${(item['room'] ?? '').toString()}',
              ),
            ),
          if ((item['judge'] ?? '').toString().isNotEmpty)
            Text(
              _loc(
                context,
                'القاضي: ${(item['judge'] ?? '').toString()}',
                'Judge: ${(item['judge'] ?? '').toString()}',
              ),
            ),
          const SizedBox(height: 4),
          Text(
            _loc(
              context,
              'التنبيه القادم: $reminderLabel',
              'Next reminder: $reminderLabel',
            ),
            style: const TextStyle(color: LexiqColors.emeraldJustice),
          ),
        ],
      ),
    );
  }

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

  String _localizeAlertTitle(BuildContext context, String title) {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'alert' ||
        title.trim() == 'تنبيه') {
      return _loc(context, 'تنبيه', 'Alert');
    }
    return title;
  }

  String _localizeCaseType(BuildContext context, String caseType) {
    const arToEn = <String, String>{
      'مدني': 'Civil',
      'تجاري': 'Commercial',
      'جزائي': 'Criminal',
      'جنائي': 'Criminal',
      'أحوال شخصية': 'Personal Status',
      'عمالي': 'Labor',
      'إداري': 'Administrative',
      'عقاري': 'Real Estate',
      'تنفيذ': 'Enforcement',
      'دستوري': 'Constitutional',
      'تحكيم': 'Arbitration',
      'ضريبي': 'Tax',
      'أخرى': 'Other',
      'other': 'Other',
    };
    const enToAr = <String, String>{
      'civil': 'مدني',
      'commercial': 'تجاري',
      'criminal': 'جنائي',
      'personal status': 'أحوال شخصية',
      'labor': 'عمالي',
      'administrative': 'إداري',
      'real estate': 'عقاري',
      'enforcement': 'تنفيذ',
      'constitutional': 'دستوري',
      'arbitration': 'تحكيم',
      'tax': 'ضريبي',
      'other': 'أخرى',
    };

    final raw = caseType.trim();
    if (_isArabic(context)) {
      return enToAr[raw.toLowerCase()] ?? raw;
    }
    return arToEn[raw] ?? raw;
  }

  String _localizeReminderLabel(BuildContext context, String label) {
    const mapAr = <String, String>{
      '1 day before': 'قبل يوم',
      '6 hours before': 'قبل 6 ساعات',
      '2 hours before': 'قبل ساعتين',
      '1 hour before': 'قبل ساعة',
    };
    const mapEn = <String, String>{
      'قبل يوم': '1 day before',
      'قبل 6 ساعات': '6 hours before',
      'قبل ساعتين': '2 hours before',
      'قبل ساعة': '1 hour before',
    };

    final raw = label.trim();
    if (_isArabic(context)) {
      return mapAr[raw] ?? raw;
    }
    return mapEn[raw] ?? raw;
  }

  Widget _indicatorChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
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

  Color _alertColor(String level) {
    final value = level.toLowerCase();
    if (value == 'critical' || value == 'high') {
      return LexiqColors.crimsonAlert;
    }
    if (value == 'warning' || value == 'medium') {
      return LexiqColors.brassGold;
    }
    return LexiqColors.emeraldJustice;
  }

  String _dateOnly(dynamic value) {
    final raw = (value ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return '-';
    }
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String _dateTimeShort(dynamic value) {
    final raw = (value ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return '-';
    }
    return '${_dateOnly(parsed.toIso8601String())} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
