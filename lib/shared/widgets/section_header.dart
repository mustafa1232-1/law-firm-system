import 'package:flutter/material.dart';
import '../../theme/lexiq_colors.dart';
import '../../core/localization/app_translations.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  Widget _titleBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(title),
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr(subtitle!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: LexiqColors.slateGray),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidget = trailing;
        final useStackedLayout =
            trailingWidget != null && constraints.maxWidth < 980;

        if (!useStackedLayout) {
          final rowChildren = <Widget>[Expanded(child: _titleBlock(context))];
          if (trailingWidget != null) {
            rowChildren.add(trailingWidget);
          }

          return Row(children: rowChildren);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleBlock(context),
            const SizedBox(height: 10),
            Align(
              alignment: _isArabic(context)
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: trailingWidget,
              ),
            ),
          ],
        );
      },
    );
  }
}
