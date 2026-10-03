import 'package:flutter/services.dart' show rootBundle;

import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

/// 文章内容加载（assets 数据源），带内存缓存。
class KnowledgeRepository {
  const KnowledgeRepository();

  static final Map<String, String> _contentCache = {};

  Future<String> loadContent(KnowledgeArticle article) async {
    final cached = _contentCache[article.id];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(article.assetPath);
    _contentCache[article.id] = raw;
    return raw;
  }
}
