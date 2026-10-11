/// 功能搜索匹配服务。
///
/// 分级管线：T1 精确 → T2 前缀/包含 → T3 编辑距离 → T4 bigram 重合度，
/// 全部未命中才轮到 **T5 模型语义兜底**（[semanticMatch]）——关键词与
/// 传统 NLP 技术优先，速度可控；模型只补语义长尾。
library;

import 'dart:math' as math;

import 'package:blood_pressed/core/i18n/app_locale_service.dart';
import 'package:blood_pressed/features/app_search/domain/feature_registry.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

class FeatureSearchService {
  FeatureSearchService({List<AppFeatureEntry>? registry})
      : _registry = registry ?? kAppFeatureRegistry;

  final List<AppFeatureEntry> _registry;

  /// 分级匹配管线（T1~T4，模型为 T5 兜底见 [semanticMatch]）。
  ///
  /// * **T1 精确**：查询 == 标题 / 关键词 / 拼音（1000~980）
  /// * **T2 前缀/包含**：标题前缀 > 标题包含 > 关键词前缀/包含 > 查询含关键词
  ///   > 拼音前缀/包含（900~750）
  /// * **T3 编辑距离**：容错错别字，短查询（≤3 字）容错 1、更长容错 2（700~660）
  /// * **T4 bigram/字符覆盖**：容错乱序词组（「提醒测量」→测量提醒）与
  ///   弱包含，Jaccard/覆盖率 ≥0.5（600 以下）
  ///
  /// 返回按 tier 升序、同 tier 按分数降序、注册表顺序稳定的命中表；
  /// 空查询返回空表。全部零依赖、纯字符串运算，15 条目规模下微秒级——
  /// **T1~T4 任一命中即不再请求模型**。
  List<AppFeatureEntry> match(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final l10n = AppLocaleService.auto;
    final scored = <(int, int, AppFeatureEntry, int)>[];
    var order = 0;
    for (final entry in _registry) {
      final title = _normalize(entry.title(l10n));
      final keywords = [for (final k in entry.keywords) _normalize(k)];
      final pinyins = [
        for (final p in entry.pinyin) p.replaceAll(' ', ''),
      ];
      (int, int)? best;

      void consider(int tier, int score) {
        final b = best;
        if (b == null ||
            tier < b.$1 ||
            (tier == b.$1 && score > b.$2)) {
          best = (tier, score);
        }
      }

      // T1 精确
      if (title == q) consider(1, 1000);
      for (final k in keywords) {
        if (k == q) consider(1, 990);
      }
      for (final p in pinyins) {
        if (p == q) consider(1, 980);
      }

      // T2 前缀 / 包含（查询包含短关键词的弱信号不入此级——见 T4）
      if (title.startsWith(q)) {
        consider(2, 900);
      } else if (title.contains(q)) {
        consider(2, 850);
      }
      for (final k in keywords) {
        if (k.startsWith(q)) {
          consider(2, 840);
        } else if (k.contains(q)) {
          consider(2, 800);
        }
      }
      for (final p in pinyins) {
        if (p.startsWith(q)) {
          consider(2, 780);
        } else if (p.contains(q) && q.length >= 2) {
          consider(2, 750);
        }
      }

      // T3 编辑距离（错别字容错）。包含关系（LD 恰为长度差）不是错别字
      // 信号——查询包含短关键词会伪装出小距离，已在 T2/T4 分级，此处跳过
      if (q.length >= 2) {
        final limit = q.length <= 3 ? 1 : 2;
        if (!title.contains(q)) {
          final dt = _levenshtein(title, q);
          if (dt <= limit) consider(3, 700 - dt * 20);
        }
        for (final k in keywords) {
          if (k.contains(q) || q.contains(k)) continue;
          final d = _levenshtein(k, q);
          if (d <= limit) consider(3, 680 - d * 20);
        }
      }

      // T4 bigram Jaccard 与查询字符覆盖率取最大（乱序词组与弱包含：
      // 「提醒测量」对「测量提醒」覆盖率 1.0，而「测量」对它仅 0.5，
      // 短关键词被查询包含这类弱关联因此天然排在整查询被解释之后）
      if (q.length >= 2) {
        var sigT = math.max(_bigramOverlap(q, title), _charCoverage(q, title));
        if (sigT >= 0.5) consider(4, (600 * sigT).round());
        var bestKw = 0.0;
        for (final k in keywords) {
          final o = math.max(_bigramOverlap(q, k), _charCoverage(q, k));
          if (o > bestKw) bestKw = o;
        }
        if (bestKw >= 0.5) consider(4, (600 * bestKw).round());
      }

      if (best != null) scored.add((best!.$1, best!.$2, entry, order));
      order++;
    }
    scored.sort((a, b) {
      final byTier = a.$1.compareTo(b.$1);
      if (byTier != 0) return byTier;
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return a.$4.compareTo(b.$4);
    });
    return [for (final s in scored) s.$3];
  }

  /// 归一化：小写、去全部空白、全角转半角。
  static String _normalize(String s) {
    final sb = StringBuffer();
    for (final code in s.runes) {
      // 全角 ASCII 区（！~ FF01~FF5E）平移到半角
      final c = code >= 0xFF01 && code <= 0xFF5E ? code - 0xFEE0 : code;
      if (c == 0x20 || c == 0x3000) continue; // 半角/全角空格
      sb.writeCharCode(c);
    }
    return sb.toString().toLowerCase();
  }

  /// 经典 Levenshtein（两行 DP；串长 ≤8，开销可忽略）。
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        cur[j + 1] = math.min(
            math.min(cur[j] + 1, prev[j + 1] + 1), prev[j] + cost);
      }
      // 纯指针交换：cur 下一轮所有位置写入先于读取
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }

  /// bigram Jaccard 重合度（单字串退化为包含判定）。
  static double _bigramOverlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a.length < 2 || b.length < 2) {
      return b.contains(a) || a.contains(b) ? 1.0 : 0.0;
    }
    final bgA = _bigrams(a);
    final bgB = _bigrams(b);
    final inter = bgA.intersection(bgB).length;
    final union = bgA.union(bgB).length;
    return union == 0 ? 0 : inter / union;
  }

  static Set<String> _bigrams(String s) {
    final out = <String>{};
    for (var i = 0; i < s.length - 1; i++) {
      out.add(s.substring(i, i + 2));
    }
    return out;
  }

  /// 查询字符覆盖率：|q ∩ term| / |q|——衡量「查询有多大比例被该词条
  /// 解释」。乱序词组（提醒测量→测量提醒）为 1.0，短关键词弱包含
  /// （测量→测量题醒）只有 0.5。
  static double _charCoverage(String q, String term) {
    final qs = q.runes.toSet();
    if (qs.isEmpty) return 0;
    final ts = term.runes.toSet();
    return qs.intersection(ts).length / qs.length;
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
