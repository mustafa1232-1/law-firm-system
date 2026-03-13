import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class AuthorityReaderPage extends ConsumerStatefulWidget {
  const AuthorityReaderPage({
    super.key,
    required this.authorityType,
    required this.authorityId,
  });

  final String authorityType;
  final String authorityId;

  @override
  ConsumerState<AuthorityReaderPage> createState() => _AuthorityReaderPageState();
}

class _AuthorityReaderPageState extends ConsumerState<AuthorityReaderPage> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _item;

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  Future<void> _loadReference() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      late final Response response;
      if (_isConstitution) {
        response = await dio.get(
          '/constitution/articles/${widget.authorityId}',
          options: Options(headers: authHeaders(ref)),
        );
      } else if (_isLaw) {
        response = await dio.get(
          '/laws/articles/${widget.authorityId}',
          options: Options(headers: authHeaders(ref)),
        );
      } else {
        response = await dio.get(
          '/decisions/${widget.authorityId}',
          options: Options(headers: authHeaders(ref)),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() => _item = (response.data as Map).cast<String, dynamic>());
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

  bool get _isConstitution => widget.authorityType.toLowerCase() == 'constitution';
  bool get _isLaw => widget.authorityType.toLowerCase() == 'law';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: _title,
            subtitle: 'النص القانوني الكامل للمرجعية المختارة',
            trailing: OutlinedButton.icon(
              onPressed: _loading ? null : _loadReference,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث'),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            GlassPanel(
              child: Text(
                _error!,
                style: const TextStyle(color: LexiqColors.crimsonAlert),
              ),
            )
          else if (_item == null)
            const GlassPanel(child: Text('تعذر تحميل المرجعية.'))
          else
            _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isConstitution) {
      return _buildConstitution(context);
    }
    if (_isLaw) {
      return _buildLaw(context);
    }
    return _buildDecision(context);
  }

  Widget _buildConstitution(BuildContext context) {
    final item = _item!;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المادة ${(item['articleNumber'] ?? '-').toString()}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text((item['title'] ?? '').toString()),
          const SizedBox(height: 10),
          Text((item['text'] ?? '').toString(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildLaw(BuildContext context) {
    final item = _item!;
    final law = (item['lawId'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (law['title'] ?? 'مادة قانونية').toString(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('رقم القانون: ${(law['lawNumber'] ?? '-').toString()}')),
              Chip(label: Text('السنة: ${(law['year'] ?? '-').toString()}')),
              Chip(label: Text('المادة: ${(item['articleNumber'] ?? '-').toString()}')),
            ],
          ),
          const SizedBox(height: 10),
          Text((item['text'] ?? '').toString(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildDecision(BuildContext context) {
    final item = _item!;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(item['courtName'] ?? '-').toString()} - ${(item['decisionNumber'] ?? '-').toString()}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('التاريخ: ${(item['decisionDate'] ?? '').toString().split('T').first}'),
          const SizedBox(height: 10),
          if ((item['summary'] ?? '').toString().trim().isNotEmpty)
            Text((item['summary'] ?? '').toString()),
          const SizedBox(height: 10),
          if ((item['fullText'] ?? '').toString().trim().isNotEmpty)
            Text((item['fullText'] ?? '').toString(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  String get _title {
    if (_isConstitution) {
      return 'مرجعية دستورية';
    }
    if (_isLaw) {
      return 'مرجعية قانونية';
    }
    return 'مرجعية قضائية';
  }
}
