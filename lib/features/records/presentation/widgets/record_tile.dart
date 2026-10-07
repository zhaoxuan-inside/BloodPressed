import 'package:flutter/material.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/i18n/labels.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';
import 'package:blood_pressed/core/widgets/category_badge.dart';
import 'package:blood_pressed/core/utils/formatters.dart';
import 'package:blood_pressed/features/records/domain/bp_record.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';

/// 单条血压记录卡片。
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final BpRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  BpCategory get _category =>
      BpCategory.fromValues(record.systolic, record.diastolic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey('record-${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 52,
                  decoration: BoxDecoration(
                    color: BpCategoryStyle.colorOf(_category),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 窄屏（360dp）下数值行可能超出宽度，整体缩放避免溢出
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            Text(
                              '${record.systolic}/${record.diastolic}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('mmHg',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                            const SizedBox(width: 10),
                            if (record.pulse != null) ...[
                              Icon(Icons.favorite,
                                  size: 13,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 2),
                              Text('${record.pulse}',
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Fmt.full(record.measuredAt)} · ${armLabel(l10n, record.arm)}'
                        '${record.posture != null ? ' · ${postureLabel(l10n, record.posture!)}' : ''}'
                        '${record.note != null ? ' · ${record.note}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CategoryBadge(category: _category),
                    const SizedBox(height: 4),
                    if (record.source != RecordSource.manual)
                      Icon(
                        record.source == RecordSource.ocr
                            ? Icons.photo_camera_outlined
                            : Icons.auto_awesome,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
