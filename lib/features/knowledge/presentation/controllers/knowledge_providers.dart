import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pressed/features/knowledge/data/knowledge_repository.dart';
import 'package:blood_pressed/features/knowledge/domain/knowledge_article.dart';

/// 文章内容仓库。
final knowledgeRepositoryProvider =
    Provider<KnowledgeRepository>((ref) => const KnowledgeRepository());

/// 文章列表。
final knowledgeListProvider =
    Provider<List<KnowledgeArticle>>((ref) => KnowledgeArticle.all);
