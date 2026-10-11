import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/widgets/common_widgets.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';
import 'package:blood_pressed/features/knowledge/presentation/controllers/knowledge_providers.dart';
import 'package:blood_pressed/l10n/app_localizations.dart';
import 'knowledge_detail_page.dart';

/// 健康知识列表页。
class KnowledgeListPage extends ConsumerStatefulWidget {
  const KnowledgeListPage({super.key});

  @override
  ConsumerState<KnowledgeListPage> createState() => _KnowledgeListPageState();
}

class _KnowledgeListPageState extends ConsumerState<KnowledgeListPage> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final articles = ref.watch(knowledgeListProvider);
    final filtered = _category == null
        ? articles
        : articles.where((a) => a.category == _category).toList();

    final categories = KnowledgeArticle.categoriesForLocale(AppLocaleService.isEn);
    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.knowledgeTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.categoryAll),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...categories.map((c) => ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    )),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: l10n.noArticlesInCategory,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final a = filtered[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                            a.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                              '${a.category} · ${l10n.minutesRead(a.minutes)}'),
                          trailing:
                              const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  KnowledgeDetailPage(article: a),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
