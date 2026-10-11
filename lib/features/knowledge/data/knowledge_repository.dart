import 'package:flutter/services.dart' show rootBundle;

import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

/// 文章内容加载（assets 数据源），带内存缓存。
class KnowledgeRepository {
  const KnowledgeRepository();

  /// 以 assetPath 为键：中英文章共享 id，按 id 缓存会跨语言串内容。
  static final Map<String, String> _contentCache = {};

  Future<String> loadContent(KnowledgeArticle article) async {
    final cached = _contentCache[article.assetPath];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(article.assetPath);
    _contentCache[article.assetPath] = raw;
    return raw;
  }
}
