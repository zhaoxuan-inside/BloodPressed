import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';
import 'package:blood_pressed/features/knowledge/presentation/controllers/knowledge_providers.dart';

/// 文章详情页：Markdown 渲染 + 字号调节 + 收藏。
class KnowledgeDetailPage extends ConsumerStatefulWidget {
  const KnowledgeDetailPage({super.key, required this.article});

  final KnowledgeArticle article;

  @override
  ConsumerState<KnowledgeDetailPage> createState() =>
      _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends ConsumerState<KnowledgeDetailPage> {
  late Future<String> _content;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _content = ref
        .read(knowledgeRepositoryProvider)
        .loadContent(widget.article);
    final settings = ref.read(appSettingsProvider);
    _favorite = settings.isFavorite(widget.article.id);
  }

  Future<void> _toggleFavorite() async {
    final settings = ref.read(appSettingsProvider);
    await settings.toggleFavorite(widget.article.id);
    setState(() => _favorite = settings.isFavorite(widget.article.id));
  }

  void _changeFont(double delta) {
    final settings = ref.read(appSettingsProvider);
    final next = (settings.knowledgeFontScale + delta).clamp(0.8, 1.6);
    settings.setKnowledgeFontScale(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final scale = settings.knowledgeFontScale;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article.category),
        actions: [
          IconButton(
            tooltip: '缩小字号',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeFont(-0.1),
          ),
          IconButton(
            tooltip: '放大字号',
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeFont(0.1),
          ),
          IconButton(
            tooltip: '收藏',
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _content,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('加载失败：${snap.error}'));
          }
          return Markdown(
            data: snap.data!,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 22 * scale),
              h2: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 19 * scale, fontWeight: FontWeight.w700),
              h3: theme.textTheme.titleMedium?.copyWith(fontSize: 17 * scale),
              p: theme.textTheme.bodyMedium
                  ?.copyWith(height: 1.7, fontSize: 15 * scale),
              listBullet: theme.textTheme.bodyMedium
                  ?.copyWith(height: 1.7, fontSize: 15 * scale),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: theme.colorScheme.primary, width: 3),
                ),
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.4),
              ),
              blockquotePadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: theme.dividerColor)),
              ),
            ),
          );
        },
      ),
    );
  }
}
