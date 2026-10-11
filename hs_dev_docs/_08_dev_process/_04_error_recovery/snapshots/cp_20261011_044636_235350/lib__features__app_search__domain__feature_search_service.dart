/// 功能搜索匹配服务。
///
/// 双层设计：
/// * 确定性层（[match]）：标题/关键词包含匹配，零依赖、零延迟——
///   模型未下载时搜索完全可用；
/// * 语义层（[semanticMatch]）：本地模型 grammar 约束输出
///   `{matches:[{id,score}]}` 做兜底排序——确定性层无结果且模型就绪时
///   由 UI 调用。
library;

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/app_search/domain/feature_registry.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

class FeatureSearchService {
  FeatureSearchService({List<AppFeatureEntry>? registry})
      : _registry = registry ?? kAppFeatureRegistry;

  final List<AppFeatureEntry> _registry;

  /// 确定性匹配：空查询返回空表；按命中强度排序（标题命中 > 关键词命中）。
  List<AppFeatureEntry> match(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final l10n = AppLocaleService.auto;
    final scored = <(int, AppFeatureEntry)>[];
    for (final entry in _registry) {
      final title = entry.title(l10n).toLowerCase();
      var score = 0;
      if (title == q) {
        score = 120;
      } else if (title.contains(q)) {
        score = 100;
      } else {
        for (final kw in entry.keywords) {
          final k = kw.toLowerCase();
          if (k == q) {
            score = 110;
            break;
          }
          if (k.contains(q) || q.contains(k)) {
            score = score == 0 ? 80 : score + 10;
          }
        }
      }
      if (score > 0) scored.add((score, entry));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, e) in scored) e];
  }

  /// 语义匹配（模型兜底）。[chatJson] 由调用方注入（引擎 JSON 问答出口）。
  /// 返回按分数排序的前 [topN] 条目；模型不可用/输出不可解析时返回空表。
  Future<List<AppFeatureEntry>> semanticMatch(
    String query, {
    required Future<Map<String, Object?>?> Function(
            List<ChatMessage> messages, int maxTokens)
        chatJson,
    int topN = 3,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final l10n = AppLocaleService.auto;
    final catalog = [for (final e in _registry) '${e.id}: ${e.title(l10n)}']
        .join('\n');
    final prompt = '你是应用内功能搜索助手。根据用户查询从下列功能中选择最相关的条目。\n'
        '功能列表（id: 标题）：\n$catalog\n\n'
        '只输出 JSON：{"matches": [{"id": "功能id", "score": 0到100的相关度整数}]}。'
        '只列出确有相关的条目（至多 3 个），无关则为空数组。用户查询：$q';

    Map<String, Object?>? json;
    try {
      json = await chatJson([
        ChatMessage(
          id: 'system',
          role: ChatRole.system,
          content: prompt,
          createdAt: DateTime.now(),
        ),
      ], 256);
    } catch (_) {
      return const [];
    }
    if (json == null) return const [];
    final matches = json['matches'];
    if (matches is! List) return const [];
    final byId = {for (final e in _registry) e.id: e};
    final scored = <(int, AppFeatureEntry)>[];
    for (final m in matches) {
      if (m is! Map) continue;
      final id = m['id'];
      final score = m['score'];
      if (id is! String || score is! int) continue;
      final entry = byId[id];
      if (entry == null) continue; // 防幻觉 id
      scored.add((score, entry));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, e) in scored.take(topN)) e];
  }
}
