import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/knowledge/data/knowledge_repository.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

/// 文章内容仓库。
final knowledgeRepositoryProvider =
    Provider<KnowledgeRepository>((ref) => const KnowledgeRepository());

/// 文章列表：按生效语言参数化（中文：中国指南；英文：美国AHA/ACC指南）。
/// 键是页面从 Localizations 取到的生效语言——语言偏好为 system 时其值
/// 恒定不变，不能作为键；静态快照会在切换后刷新而 provider 不重算
/// （历史缺陷：跟随系统/会话内切换后停留旧语言）。
final knowledgeListProvider =
    Provider.family<List<KnowledgeArticle>, bool>((ref, isEn) {
  return KnowledgeArticle.forLocale(isEn);
});
