import 'package:flutter/material.dart';

import 'package:blood_pressed/core/design/bp_category_style.dart';
import 'package:blood_pressed/core/utils/bp_category.dart';

/// 血压分级徽章（圆角 pill），全应用统一的分级展示组件。
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});

  final BpCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = BpCategoryStyle.colorOf(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BpCategoryStyle.containerOf(category),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
