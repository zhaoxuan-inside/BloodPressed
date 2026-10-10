import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/core/providers.dart';
import 'package:blood_pressed/features/knowledge/data/knowledge_repository.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

/// 文章内容仓库。
final knowledgeRepositoryProvider =
    Provider<KnowledgeRepository>((ref) => const KnowledgeRepository());

/// 文章列表：跟随界面语言偏好动态响应（中文：中国指南；英文：美国AHA/ACC指南）。
final knowledgeListProvider = Provider<List<KnowledgeArticle>>((ref) {
  // 监听语言偏好变动，驱动知识列表自动重算
  ref.watch(localePrefProvider);
  return KnowledgeArticle.forLocale(AppLocaleService.isEn);
});
